import { DirectUpload } from '@rails/activestorage'

export interface UploadedImage {
  id: string
  url: string
  filename: string
}

export const IMAGE_TYPES = ['image/png', 'image/jpeg', 'image/gif', 'image/webp']
export const MAX_IMAGE_BYTES = 10 * 1024 * 1024

// DirectUpload reads the token from the <meta> tag, which Inertia never re-renders, so it goes stale once
// sign-in resets the session. inertia_rails keeps the XSRF-TOKEN cookie current, so copy that over first.
function refreshCsrfMeta() {
  const token = document.cookie.match(/(?:^|; )XSRF-TOKEN=([^;]*)/)?.[1]
  const meta = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')
  if (token && meta) meta.content = decodeURIComponent(token)
}

// Uploads straight to storage through Active Storage's direct upload endpoint and returns the blob's
// signed id plus the redirect URL that serves it (ActiveStorage's own route, not one of ours).
export function uploadImage(file: File, directUploadUrl: string): Promise<UploadedImage> {
  return new Promise((resolve, reject) => {
    if (!IMAGE_TYPES.includes(file.type))
      return reject(new Error(`${file.name} is not a PNG, JPEG, GIF or WebP`))
    if (file.size > MAX_IMAGE_BYTES) return reject(new Error(`${file.name} is over 10 MB`))

    refreshCsrfMeta()
    new DirectUpload(file, directUploadUrl).create((error, blob) => {
      if (error) return reject(error)
      resolve({
        id: blob.signed_id,
        url: `/rails/active_storage/blobs/redirect/${blob.signed_id}/${encodeURIComponent(blob.filename)}`,
        filename: blob.filename,
      })
    })
  })
}
