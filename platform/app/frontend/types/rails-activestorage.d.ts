declare module '@rails/activestorage' {
  // Whatever the upload URL returns; ours is UploadsController#create.
  export interface Blob {
    filename: string
    finish_url: string
  }
  export class DirectUpload {
    constructor(file: File, url: string, delegate?: unknown)
    create(callback: (error: Error | null, blob: Blob) => void): void
  }
}
