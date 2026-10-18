// Docs pages (app/frontend/docs/*.mdx), compiled by mdsvex. `metadata` is the frontmatter.
declare module '*.mdx' {
  import type { Component } from 'svelte'

  export const metadata: { title: string; order: number }
  const component: Component
  export default component
}
