import { Editor } from '@tiptap/core'
import Heading from '@tiptap/extension-heading'
import Image from '@tiptap/extension-image'
import { Placeholder } from '@tiptap/extensions'
import { TextSelection } from '@tiptap/pm/state'
import { Markdown } from '@tiptap/markdown'
import StarterKit from '@tiptap/starter-kit'

// Older journals and Slack edits can hold headings. They keep rendering, but nothing here makes new ones.
const QuietHeading = Heading.extend({
  addInputRules: () => [],
  addKeyboardShortcuts: () => ({}),
})

export function createJournalEditor({
  element,
  markdown,
  placeholder,
  onChange,
  onRedraw,
  onFiles,
}: {
  element: HTMLElement
  markdown: string
  placeholder: string
  onChange: (markdown: string) => void
  onRedraw: () => void
  onFiles: (files: File[]) => void
}): Editor {
  const images = (list: FileList | undefined | null) =>
    Array.from(list ?? []).filter((file) => file.type.startsWith('image/'))

  return new Editor({
    element,
    extensions: [
      StarterKit.configure({
        heading: false,
        underline: false,
        link: { openOnClick: false, autolink: true, defaultProtocol: 'https' },
      }),
      QuietHeading,
      Image,
      Placeholder.configure({ placeholder }),
      Markdown.configure({ markedOptions: { gfm: true, breaks: true } }),
    ],
    content: markdown,
    contentType: 'markdown',
    editorProps: {
      attributes: { class: 'journal-editor', 'aria-multiline': 'true', role: 'textbox' },
      handlePaste: (_view, event) => {
        const files = images(event.clipboardData?.files)
        if (files.length === 0) return false
        onFiles(files)
        return true
      },
      handleDrop: (view, event, _slice, moved) => {
        const files = images(event.dataTransfer?.files)
        if (moved || files.length === 0) return false
        const at = view.posAtCoords({ left: event.clientX, top: event.clientY })
        if (at) view.dispatch(view.state.tr.setSelection(TextSelection.near(view.state.doc.resolve(at.pos))))
        onFiles(files)
        return true
      },
    },
    onUpdate: ({ editor }) => onChange(editor.getMarkdown()),
    onTransaction: onRedraw,
  })
}
