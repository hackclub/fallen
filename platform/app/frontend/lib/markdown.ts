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

// The least writing a journal needs, and how much more each hour logged asks for (Journal.body_length_needed).
export const MIN_JOURNAL_LENGTH = 100
export const JOURNAL_LENGTH_PER_HOUR = 100

export function journalLengthNeeded(minutes: number): number {
  return Math.max(MIN_JOURNAL_LENGTH, Math.ceil((Math.round(minutes) * JOURNAL_LENGTH_PER_HOUR) / 60))
}

// A photo for every this many minutes logged (Journal::MINUTES_PER_IMAGE).
export const MINUTES_PER_PHOTO = 120

export function countWords(markdown: string): number {
  const text = markdown
    .replace(/!\[[^\]]*\]\([^)]*\)/g, ' ')
    .replace(/\[([^\]]*)\]\([^)]*\)/g, '$1')
    .replace(/[#*_`>~-]/g, ' ')
  return text.split(/\s+/).filter(Boolean).length
}
