declare module '@rails/activestorage' {
  export interface Blob {
    signed_id: string
    filename: string
    content_type: string
    byte_size: number
  }
  export class DirectUpload {
    constructor(file: File, url: string, delegate?: unknown)
    create(callback: (error: Error | null, blob: Blob) => void): void
  }
}
