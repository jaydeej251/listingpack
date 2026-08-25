import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "dialog", "copyButton" ]
  static values = { imageUrl: String }

  open() {
    if (!this.hasDialogTarget) return
    this.dialogTarget.showModal()
  }

  close() {
    if (this.hasDialogTarget) this.dialogTarget.close()
  }

  backdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }

  async copyImage() {
    if (!this.imageUrlValue || !this.hasCopyButtonTarget) return

    const original = this.copyButtonTarget.textContent
    try {
      const response = await fetch(this.imageUrlValue)
      const blob = await response.blob()
      const type = blob.type || "image/png"
      await navigator.clipboard.write([ new ClipboardItem({ [type]: blob }) ])
      this.copyButtonTarget.textContent = "Image copied"
    } catch (_error) {
      this.copyButtonTarget.textContent = "Download PNG instead"
    }
    setTimeout(() => { this.copyButtonTarget.textContent = original }, 2000)
  }
}
