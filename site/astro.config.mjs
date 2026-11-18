import { defineConfig } from 'astro/config';
import react from '@astrojs/react';
import tailwindcss from '@tailwindcss/vite';

const repositorySlug = process.env.GITHUB_REPOSITORY ?? 'itsnazzym/Downloader';
const [owner, repository] = repositorySlug.split('/');
const isUserOrOrgSite = repository === `${owner}.github.io`;
const base = isUserOrOrgSite ? '/' : `/${repository}`;

export default defineConfig({
  site: `https://${owner}.github.io`,
  base,
  trailingSlash: 'always',
  devToolbar: { enabled: false },
  integrations: [react()],
  vite: { plugins: [tailwindcss()] },
});
