import { vitePreprocess } from '@sveltejs/vite-plugin-svelte'
import { mdsvex } from 'mdsvex'

// .mdx files are Markdown that can use Svelte components and imports (mdsvex), compiled at build time. The docs
// pages live in app/frontend/docs.
export default {
  extensions: ['.svelte', '.mdx'],
  preprocess: [vitePreprocess(), mdsvex({ extensions: ['.mdx'] })],
}
