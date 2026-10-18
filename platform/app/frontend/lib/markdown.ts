import DOMPurify from 'dompurify'
import { marked } from 'marked'

marked.use({ gfm: true, breaks: true })

// Journal bodies are Markdown written by the author; the HTML is sanitised before it touches the DOM.
export function renderMarkdown(markdown: string): string {
  const html = marked.parse(markdown, { async: false }) as string
  return DOMPurify.sanitize(html, { ADD_ATTR: ['target'], FORBID_TAGS: ['style', 'script'] })
}

// Characters of writing, leaving out embedded photos, as Journal.written_length counts them on the server.
export function writtenLength(markdown: string): number {
  return markdown.replace(/!\[[^\]]*\]\([^)]*\)/g, '').trim().length
}

// The least writing a journal needs (Journal::MIN_BODY_LENGTH).
export const MIN_JOURNAL_LENGTH = 100

export function countWords(markdown: string): number {
  const text = markdown
    .replace(/!\[[^\]]*\]\([^)]*\)/g, ' ')
    .replace(/\[([^\]]*)\]\([^)]*\)/g, '$1')
    .replace(/[#*_`>~-]/g, ' ')
  return text.split(/\s+/).filter(Boolean).length
}
