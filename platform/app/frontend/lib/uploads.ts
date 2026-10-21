import { DirectUpload, type Blob } from '@rails/activestorage'
import { csrfToken } from '@/lib/csrf'

export interface UploadedImage {
  id: string
  url: string
  filename: string
}

export const IMAGE_TYPES = ['image/png', 'image/jpeg', 'image/gif', 'image/webp']
export const MAX_IMAGE_BYTES = 10 * 1024 * 1024

// DirectUpload reads the token from the <meta> tag, which Inertia never re-renders.
function refreshCsrfMeta() {
  const meta = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')
  if (meta) meta.content = csrfToken()
}

function directUpload(file: File, uploadUrl: string): Promise<Blob> {
  return new Promise((resolve, reject) => {
    new DirectUpload(file, uploadUrl).create((error, blob) => (error ? reject(error) : resolve(blob)))
  })
}

// PUTs the file straight to storage, then asks UploadsController to check its bytes, which is what hands out the
// blob's signed id. The URL is Active Storage's own redirect route, not one of ours.
export async function uploadImage(file: File, uploadUrl: string): Promise<UploadedImage> {
  if (!IMAGE_TYPES.includes(file.type)) throw new Error(`${file.name} is not a PNG, JPEG, GIF or WebP`)
  if (file.size > MAX_IMAGE_BYTES) throw new Error(`${file.name} is over 10 MB`)

  refreshCsrfMeta()
  const { finish_url } = await directUpload(file, uploadUrl).catch(() => {
    throw new Error(`Couldn't upload ${file.name}`)
  })
  const response = await fetch(finish_url, {
    method: 'PATCH',
    headers: { 'X-CSRF-Token': csrfToken(), Accept: 'application/json' },
    credentials: 'same-origin',
  })
  const data = await response.json().catch(() => ({}))
  if (!response.ok) throw new Error(data.error ?? `Couldn't upload ${file.name} (${response.status})`)

  return {
    id: data.signed_id,
    url: `/rails/active_storage/blobs/redirect/${data.signed_id}/${encodeURIComponent(data.filename)}`,
    filename: data.filename,
  }
}
