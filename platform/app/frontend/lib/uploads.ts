import { DirectUpload } from '@rails/activestorage'

export interface UploadedImage {
  id: string
  url: string
  filename: string
}

export const IMAGE_TYPES = ['image/png', 'image/jpeg', 'image/gif', 'image/webp']
export const MAX_IMAGE_BYTES = 10 * 1024 * 1024

// Uploads straight to storage through Active Storage's direct upload endpoint and returns the blob's
// signed id plus the redirect URL that serves it (ActiveStorage's own route, not one of ours).
export function uploadImage(file: File, directUploadUrl: string): Promise<UploadedImage> {
  return new Promise((resolve, reject) => {
    if (!IMAGE_TYPES.includes(file.type))
      return reject(new Error(`${file.name} is not a PNG, JPEG, GIF or WebP`))
    if (file.size > MAX_IMAGE_BYTES) return reject(new Error(`${file.name} is over 10 MB`))

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
