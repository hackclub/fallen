declare module '@rails/activestorage' {
  // Whatever the upload URL returns; ours is UploadsController#create.
  export interface Blob {
    filename: string
    finish_url: string
  }
  export interface DirectUploadDelegate {
    directUploadWillStoreFileWithXHR?: (xhr: XMLHttpRequest) => void
  }
  export class DirectUpload {
    constructor(file: File, url: string, delegate?: DirectUploadDelegate)
    create(callback: (error: Error | null, blob: Blob) => void): void
  }
}
