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

// The writing a journal needs: this much up to an hour, then more per two hours, rounded up (Journal.body_length_needed).
export const MIN_JOURNAL_LENGTH = 100
export const JOURNAL_LENGTH_PER_TWO_HOURS = 200

export function journalLengthNeeded(minutes: number): number {
  const rounded = Math.round(minutes)
  return rounded <= 60 ? MIN_JOURNAL_LENGTH : Math.ceil(rounded / 120) * JOURNAL_LENGTH_PER_TWO_HOURS
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
