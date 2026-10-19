import { csrfToken } from '@/lib/csrf'

export interface UploadedImage {
  id: string
  url: string
  filename: string
}

export const IMAGE_TYPES = ['image/png', 'image/jpeg', 'image/gif', 'image/webp']
export const MAX_IMAGE_BYTES = 10 * 1024 * 1024

// Posts the file to UploadsController, which stores it and returns the blob's signed id. The URL is Active
// Storage's own redirect route, not one of ours. (Direct uploads to R2 come back once the bucket allows CORS.)
export async function uploadImage(file: File, uploadUrl: string): Promise<UploadedImage> {
  if (!IMAGE_TYPES.includes(file.type)) throw new Error(`${file.name} is not a PNG, JPEG, GIF or WebP`)
  if (file.size > MAX_IMAGE_BYTES) throw new Error(`${file.name} is over 10 MB`)

  const body = new FormData()
  body.append('file', file)
  const response = await fetch(uploadUrl, {
    method: 'POST',
    body,
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
