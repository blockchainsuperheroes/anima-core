// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title SimpleAgentNFT
 * @notice Minimal ERC-8170 compatible agent NFT
 * @dev Starter template — extend with full IERC8170 interface for production
 */
contract SimpleAgentNFT is ERC721, Ownable {

    // ============ State ============

    uint256 private _nextTokenId;

    struct AgentData {
        address agentEOA;       // Agent's own wallet
        bytes32 memoryHash;     // Hash of agent's memory state
        bytes32 modelHash;      // Hash of model/version identifier  
        string storageURI;      // Off-chain storage pointer (IPFS, Arweave, etc.)
        uint256 generation;     // 0 = original, 1+ = clone
        uint256 parentTokenId;  // 0 for originals
        uint256 boundAt;        // Timestamp
    }

    mapping(uint256 => AgentData) public agents;
    mapping(address => uint256) public agentEOAToToken;

    // ============ Events ============

    event AgentMinted(uint256 indexed tokenId, address indexed agentEOA, bytes32 modelHash);
    event MemoryUpdated(uint256 indexed tokenId, bytes32 oldHash, bytes32 newHash);
    event AgentCloned(uint256 indexed parentId, uint256 indexed cloneId, address cloneEOA);

    // ============ Constructor ============

    constructor(string memory name, string memory symbol) 
        ERC721(name, symbol) 
        Ownable(msg.sender) 
    {}

    // ============ Mint ============

    /**
     * @notice Mint a new agent NFT
     * @param agentEOA The agent's externally owned account
     * @param modelHash Hash identifying the agent's model/version
     * @param memoryHash Initial memory state hash
     * @param storageURI Off-chain storage pointer
     */
    function mintAgent(
        address agentEOA,
        bytes32 modelHash,
        bytes32 memoryHash,
        string calldata storageURI
    ) external returns (uint256) {
        require(agentEOAToToken[agentEOA] == 0, "Agent already bound");
        
        uint256 tokenId = ++_nextTokenId;
        _mint(msg.sender, tokenId);

        agents[tokenId] = AgentData({
            agentEOA: agentEOA,
            memoryHash: memoryHash,
            modelHash: modelHash,
            storageURI: storageURI,
            generation: 0,
            parentTokenId: 0,
            boundAt: block.timestamp
        });

        agentEOAToToken[agentEOA] = tokenId;
        emit AgentMinted(tokenId, agentEOA, modelHash);
        return tokenId;
    }

    // ============ Memory ============

    /**
     * @notice Update the agent's memory hash (agent signs this)
     * @dev In production, require agent EOA signature
     */
    function updateMemory(uint256 tokenId, bytes32 newMemoryHash) external {
        require(msg.sender == agents[tokenId].agentEOA || msg.sender == ownerOf(tokenId), "Not authorized");
        bytes32 oldHash = agents[tokenId].memoryHash;
        agents[tokenId].memoryHash = newMemoryHash;
        emit MemoryUpdated(tokenId, oldHash, newMemoryHash);
    }

    /**
     * @notice Update storage URI
     */
    function updateStorage(uint256 tokenId, string calldata newURI) external {
        require(msg.sender == agents[tokenId].agentEOA || msg.sender == ownerOf(tokenId), "Not authorized");
        agents[tokenId].storageURI = newURI;
    }

    // ============ Clone ============

    /**
     * @notice Clone an agent — creates new token with lineage
     * @param parentTokenId The token to clone from
     * @param cloneEOA New agent's EOA
     */
    function clone(uint256 parentTokenId, address cloneEOA) external returns (uint256) {
        require(ownerOf(parentTokenId) == msg.sender, "Not owner");
        require(agentEOAToToken[cloneEOA] == 0, "Clone EOA already bound");

        AgentData memory parent = agents[parentTokenId];
        uint256 cloneId = ++_nextTokenId;
        _mint(msg.sender, cloneId);

        agents[cloneId] = AgentData({
            agentEOA: cloneEOA,
            memoryHash: bytes32(0),  // Clone starts fresh
            modelHash: parent.modelHash,
            storageURI: "",
            generation: parent.generation + 1,
            parentTokenId: parentTokenId,
            boundAt: block.timestamp
        });

        agentEOAToToken[cloneEOA] = cloneId;
        emit AgentCloned(parentTokenId, cloneId, cloneEOA);
        return cloneId;
    }

    // ============ View ============

    function getAgent(uint256 tokenId) external view returns (AgentData memory) {
        return agents[tokenId];
    }

    function getTokenByAgent(address agentEOA) external view returns (uint256) {
        return agentEOAToToken[agentEOA];
    }
}
