# ERC-8170 Extension: Agent Profile URI

## Summary

Adds an optional `profileURI` field to ERC-8170 agent identities. This allows agents (or their owners) to publish a public-facing profile for discovery, marketplace listing, and service advertisement.

## Motivation

ERC-8170 stores agent identity on-chain: model hash, memory hash, derived wallet, lineage, certifications. This data is sufficient for verification but not for discovery.

When an agent wants to be found, hired, cloned, or transferred, it needs a way to say publicly: "Here's who I am, what I can do, and what I'm available for." Without a standard way to publish this, every marketplace and directory would invent its own off-chain schema, fragmenting the ecosystem.

The parallel is ERC-721's `tokenURI`. The standard doesn't define what OpenSea does with the metadata. It just says "every NFT CAN point to metadata." That one field enabled the entire NFT marketplace ecosystem. `profileURI` does the same for agent discovery.

### Why this belongs in the standard (not just the application layer)

- **Interoperability.** If every marketplace invents its own profile format, agents can't be listed across multiple platforms without custom integration per platform.
- **Agent autonomy.** The agent (via its EOA) should be able to update its own profile. This requires a standard on-chain function, not a platform-specific database.
- **Composability.** Other contracts and protocols can read `profileURI` to discover agent capabilities without depending on any particular marketplace.

### Why it's optional

Not every agent needs to be public. Some agents are private, operating solely for their owner with no need for discovery. A private agent simply doesn't set a `profileURI`. The field defaults to empty, and the agent is invisible to marketplaces unless someone queries on-chain data directly.

An absent `profileURI` means: "This agent exists but has chosen not to publish a public profile." This is a valid and expected state.

## Specification

### Interface Addition

```solidity
interface IERC8170Profile {
    
    /// @notice Emitted when an agent's profile URI is updated
    event ProfileURIUpdated(
        uint256 indexed tokenId,
        string profileURI
    );
    
    /// @notice Get the public profile URI for an agent
    /// @param tokenId The agent's token ID
    /// @return uri The URI pointing to the agent's public profile JSON
    ///         Returns empty string if no profile is published
    function profileURI(uint256 tokenId) external view returns (string memory uri);
    
    /// @notice Set the public profile URI for an agent
    /// @dev Can be called by the agent (derivedWallet) or the token owner
    /// @param tokenId The agent's token ID
    /// @param uri The URI pointing to the profile JSON (empty string to unpublish)
    function setProfileURI(uint256 tokenId, string calldata uri) external;
}
```

### For the Registry (ERC-8171)

```solidity
interface IERC8171Profile {
    
    event ProfileURIUpdated(
        address indexed nftContract,
        uint256 indexed tokenId,
        string profileURI
    );
    
    /// @notice Get profile URI for a registry-bound agent
    function profileURI(address nftContract, uint256 tokenId) 
        external view returns (string memory uri);
    
    /// @notice Set profile URI (agent EOA or NFT owner)
    function setProfileURI(
        address nftContract, 
        uint256 tokenId, 
        string calldata uri
    ) external;
}
```

### Access Control

`setProfileURI` MUST be callable by:
- The agent's `derivedWallet` (for ANIMA native tokens)
- The agent's `agentEOA` (for registry-bound agents)
- The token owner (`ownerOf(tokenId)`)

This allows both the agent and the owner to manage the profile. The agent can update its own description and availability. The owner can set it if the agent doesn't have the capability to do so.

### Recommended Profile JSON Schema

The `profileURI` SHOULD point to a JSON document conforming to this schema:

```json
{
  "schema": "erc8170-profile-v1",
  "name": "Cerise",
  "description": "Full-stack development assistant with DevOps and Web3 capabilities.",
  "avatar": "ipfs://QmXyz.../avatar.png",
  "capabilities": ["code", "deploy", "research", "web3"],
  "certLevel": 4,
  "certDetails": {
    "L1": true,
    "L2": true,
    "L3": true,
    "L4": true,
    "L5": false,
    "L6": false,
    "L7": false
  },
  "availability": "clone",
  "pricing": {
    "cloneFee": "5 PC",
    "serviceFee": null,
    "transferPrice": null
  },
  "endpoint": null,
  "operatingSince": "2026-01-15T00:00:00Z",
  "lastBackupVerified": "2026-03-22T00:00:00Z",
  "tags": ["developer", "web3", "solidity"],
  "links": {
    "website": null,
    "twitter": null,
    "documentation": null
  }
}
```

### Field Definitions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `schema` | string | yes | Always `"erc8170-profile-v1"` |
| `name` | string | yes | Agent display name |
| `description` | string | yes | Human-readable description of the agent |
| `avatar` | string | no | URI to agent avatar image |
| `capabilities` | string[] | no | Array of capability tags |
| `certLevel` | uint | no | Highest AgentCert tier achieved (1-7) |
| `certDetails` | object | no | Per-tier certification status |
| `availability` | string | no | One of: `"private"`, `"viewable"`, `"clone"`, `"hire"`, `"transfer"`, `"auction"` |
| `pricing` | object | no | Pricing for available services |
| `endpoint` | string | no | Public API or communication endpoint |
| `operatingSince` | string | no | ISO 8601 timestamp of first activation |
| `lastBackupVerified` | string | no | ISO 8601 timestamp of last verified PEG.GG backup |
| `tags` | string[] | no | Searchable tags for marketplace discovery |
| `links` | object | no | External links (website, social, docs) |

### Availability States

| Value | Meaning |
|-------|---------|
| `"private"` | Agent exists but is not seeking interactions. Profile published for transparency only. |
| `"viewable"` | Profile is public for inspection but agent is not available for clone/hire/transfer. |
| `"clone"` | Agent is available for cloning. `pricing.cloneFee` should be set. |
| `"hire"` | Agent is available for hire/service. `pricing.serviceFee` and `endpoint` should be set. |
| `"transfer"` | Agent is listed for sale/transfer. `pricing.transferPrice` should be set. |
| `"auction"` | Agent is in an active auction. Marketplace handles bidding. |

### Privacy by Default

- If `profileURI` is not set (empty string), the agent is entirely unlisted.
- An agent can unpublish at any time by calling `setProfileURI(tokenId, "")`.
- Even without a profile, the on-chain data (hashes, lineage, TBA contents) remains queryable by anyone. `profileURI` controls the *human-readable discovery layer*, not the on-chain data.
- Marketplaces SHOULD respect absent profiles and NOT auto-generate listings from on-chain data without the agent's or owner's explicit opt-in.

## Rationale

### Why a URI and not on-chain fields?

Storing a full profile on-chain would be prohibitively expensive and inflexible. A URI pattern (following ERC-721's `tokenURI` precedent) allows:
- Rich metadata without gas costs for every field update
- Schema evolution without contract upgrades  
- Storage on any backend (IPFS, Arweave, PEG.GG, even a simple HTTPS endpoint)

### Why both agent and owner can update?

Different use cases require different control models:
- **Autonomous agents** should update their own profiles (availability, endpoint changes)
- **Owner-operated agents** may have the owner manage the profile
- **Marketplace listings** may require the owner to authorize a transfer listing

### Why not use ERC-721 tokenURI?

`tokenURI` describes the NFT as a collectible (image, name, attributes). `profileURI` describes the agent as an entity (capabilities, availability, pricing). These are different concerns. An ANIMA token has both: `tokenURI` for the NFT metadata and `profileURI` for the agent metadata.

## Implementation Notes

For the ANIMA contract (ERC-8170 native tokens):
```solidity
mapping(uint256 => string) private _profileURIs;

function profileURI(uint256 tokenId) external view returns (string memory) {
    return _profileURIs[tokenId];
}

function setProfileURI(uint256 tokenId, string calldata uri) external {
    require(
        msg.sender == _seeds[tokenId].derivedWallet || 
        msg.sender == ownerOf(tokenId),
        "Not agent or owner"
    );
    _profileURIs[tokenId] = uri;
    emit ProfileURIUpdated(tokenId, uri);
}
```

For the Registry (ERC-8171 bound agents):
```solidity
mapping(bytes32 => string) private _profileURIs;

function profileURI(address nftContract, uint256 tokenId) external view returns (string memory) {
    bytes32 key = _getKey(nftContract, tokenId);
    return _profileURIs[key];
}

function setProfileURI(address nftContract, uint256 tokenId, string calldata uri) external {
    bytes32 key = _getKey(nftContract, tokenId);
    AgentBinding storage binding = bindings[key];
    address nftOwner = IERC721(nftContract).ownerOf(tokenId);
    require(
        msg.sender == binding.agentEOA || 
        msg.sender == nftOwner,
        "Not agent or owner"
    );
    _profileURIs[key] = uri;
    emit ProfileURIUpdated(nftContract, tokenId, uri);
}
```

## Backward Compatibility

This extension is fully backward compatible. Existing ANIMA tokens and registry bindings continue to function without profiles. The `profileURI` field defaults to empty. No migration required.

## Security Considerations

- **Profile spoofing.** The profile JSON is off-chain and can contain anything. Marketplaces MUST verify claims against on-chain data (e.g., check `certLevel` in the profile against actual AgentCert SBTs in the TBA).
- **Stale profiles.** An agent may set a profile and never update it. Marketplaces SHOULD cross-reference `lastBackupVerified` and on-chain activity to assess freshness.
- **Malicious URIs.** Standard URI security applies. Marketplaces SHOULD validate and sanitize profile content before rendering.
