import { Editor, Extension } from '@tiptap/core'
import Heading from '@tiptap/extension-heading'
import Image from '@tiptap/extension-image'
import { Placeholder } from '@tiptap/extensions'
import { Plugin, PluginKey, TextSelection } from '@tiptap/pm/state'
import { Decoration, DecorationSet } from '@tiptap/pm/view'
import { Markdown } from '@tiptap/markdown'
import StarterKit from '@tiptap/starter-kit'

// Older journals and Slack edits can hold headings. They keep rendering, but nothing here makes new ones.
const QuietHeading = Heading.extend({
  addInputRules: () => [],
  addKeyboardShortcuts: () => ({}),
})

type PhotoAction = { add: { id: object; at: number; dom: HTMLElement } } | { remove: object }

const photos = new PluginKey<DecorationSet>('uploadingPhotos')

// A photo on its way up shows where it will land without being in the writing yet, so a half-uploaded photo never
// reaches the Markdown, a draft or the server. The spot moves with any typing around it.
const UploadingPhotos = Extension.create({
  name: 'uploadingPhotos',
  addProseMirrorPlugins: () => [
    new Plugin<DecorationSet>({
      key: photos,
      state: {
        init: () => DecorationSet.empty,
        apply(tr, set) {
          set = set.map(tr.mapping, tr.doc)
          const action: PhotoAction | undefined = tr.getMeta(photos)
          if (action && 'add' in action) {
            const { id, at, dom } = action.add
            set = set.add(tr.doc, [Decoration.widget(at, dom, { id, side: 1 })])
          } else if (action) {
            set = set.remove(set.find(undefined, undefined, (spec) => spec.id === action.remove))
          }
          return set
        },
      },
      props: { decorations: (state) => photos.getState(state) },
    }),
  ],
})

export interface PhotoSlot {
  progress: (fraction: number) => void
  // False when the writing around the spot was deleted while it uploaded.
  place: (src: string, alt: string) => boolean
  cancel: () => void
}

// Shows the photo dimmed at `at` with how far its upload has got, until it is placed or cancelled.
export function reservePhoto(editor: Editor, file: File, at = editor.state.selection.from): PhotoSlot {
  const id = {}
  const preview = URL.createObjectURL(file)
  const dom = document.createElement('span')
  dom.className = 'journal-upload'
  dom.contentEditable = 'false'
  dom.innerHTML =
    '<img alt=""><span class="journal-upload-status"><span class="journal-upload-label">Uploading</span>' +
    '<span class="journal-upload-bar"><span></span></span></span>'
  dom.querySelector('img')!.src = preview
  const label = dom.querySelector<HTMLElement>('.journal-upload-label')!
  const fill = dom.querySelector<HTMLElement>('.journal-upload-bar > span')!
  editor.view.dispatch(editor.state.tr.setMeta(photos, { add: { id, at, dom } }))

  const release = () => {
    URL.revokeObjectURL(preview)
    if (!editor.isDestroyed) editor.view.dispatch(editor.state.tr.setMeta(photos, { remove: id }))
  }

  return {
    progress(fraction) {
      fill.style.width = `${Math.round(fraction * 100)}%`
      label.textContent = fraction < 1 ? `Uploading ${Math.round(fraction * 100)}%` : 'Almost done'
    },
    place(src, alt) {
      if (editor.isDestroyed) return false
      const spot = photos.getState(editor.state)?.find(undefined, undefined, (spec) => spec.id === id)[0]
      release()
      if (!spot) return false
      editor
        .chain()
        .insertContentAt(spot.from, { type: 'image', attrs: { src, alt } }, { updateSelection: false })
        .run()
      return true
    },
    cancel: release,
  }
}

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
  onFiles: (files: File[], at?: number) => void
}): Editor {
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
      UploadingPhotos,
      Placeholder.configure({ placeholder }),
      Markdown.configure({ markedOptions: { gfm: true, breaks: true } }),
    ],
    content: markdown,
    contentType: 'markdown',
    editorProps: {
      attributes: { class: 'journal-editor', 'aria-multiline': 'true', role: 'textbox' },
      handlePaste: (_view, event) => {
        const files = Array.from(event.clipboardData?.files ?? []).filter((file) =>
          file.type.startsWith('image/'),
        )
        if (files.length === 0) return false
        onFiles(files)
        return true
      },
      // Every dropped file is taken, so one that isn't a photo gets an error instead of the browser opening it.
      handleDrop: (view, event, _slice, moved) => {
        const files = Array.from(event.dataTransfer?.files ?? [])
        if (moved || files.length === 0) return false
        const at = view.posAtCoords({ left: event.clientX, top: event.clientY })
        if (!at) return false
        const near = TextSelection.near(view.state.doc.resolve(at.pos))
        view.dispatch(view.state.tr.setSelection(near))
        onFiles(files, near.from)
        return true
      },
    },
    onUpdate: ({ editor }) => onChange(editor.getMarkdown()),
    onTransaction: onRedraw,
  })
}
