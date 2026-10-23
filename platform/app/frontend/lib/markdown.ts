import DOMPurify from 'dompurify'
import { marked } from 'marked'

marked.use({ gfm: true, breaks: true })

// Only what Markdown itself makes, with no styles, so nothing can pull in a picture from elsewhere.
const ALLOWED_TAGS =
  'p br strong em del code pre blockquote ul ol li a img hr h1 h2 h3 h4 h5 h6 table thead tbody tr th td input'.split(
    ' ',
  )
const ALLOWED_ATTR = 'href target rel title src alt start type checked disabled align'.split(' ')
const PHOTO_PATH = /^\/rails\/active_storage\/blobs\/redirect\/([^/]+)\//

// Journal bodies are Markdown written by the author; the HTML is sanitised before it touches the DOM. The only
// pictures shown are the journal's own uploads (`photos`, their signed ids): anything else, even another journal's
// photo, is dropped.
export function renderMarkdown(markdown: string, photos: string[]): string {
  const html = marked.parse(markdown, { async: false }) as string
  const fragment = DOMPurify.sanitize(html, { ALLOWED_TAGS, ALLOWED_ATTR, RETURN_DOM_FRAGMENT: true })
  for (const img of fragment.querySelectorAll('img')) {
    const id = img.getAttribute('src')?.match(PHOTO_PATH)?.[1]
    if (!id || !photos.includes(decodeURIComponent(id))) img.remove()
    // The proxy URL is the same photo, cached by Cloudflare; the redirect one asks the app every time.
    else img.setAttribute('src', img.getAttribute('src')!.replace('/blobs/redirect/', '/blobs/proxy/'))
  }
  const container = document.createElement('div')
  container.append(fragment)
  return container.innerHTML
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
