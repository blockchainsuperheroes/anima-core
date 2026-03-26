import { defineConfig } from 'astro/config';
import mdx from '@astrojs/mdx';
import tailwind from '@astrojs/tailwind';

export default defineConfig({
  site: 'https://erc8170.org',
  integrations: [mdx(), tailwind()],
  output: 'static',
  outDir: 'dist',
});
