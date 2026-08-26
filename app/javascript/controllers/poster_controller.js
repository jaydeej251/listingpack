import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "dialog", "copyButton", "closeButton" ]
  static values = { imageUrl: String }

  open(event) {
    if (!this.hasDialogTarget) return
    this.opener = event?.currentTarget || document.activeElement
    this.dialogTarget.showModal()
    if (this.hasCloseButtonTarget) {
      this.closeButtonTarget.focus()
    }
  }

  close() {
    if (!this.hasDialogTarget) return
    this.dialogTarget.close()
    this.restoreFocus()
  }

  backdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }

  restoreFocus() {
    if (this.opener && typeof this.opener.focus === "function") {
      this.opener.focus()
    }
  }

  connect() {
    if (!this.hasDialogTarget) return
    this.boundOnClose = () => this.restoreFocus()
    this.dialogTarget.addEventListener("close", this.boundOnClose)
  }

  disconnect() {
    if (this.hasDialogTarget && this.boundOnClose) {
      this.dialogTarget.removeEventListener("close", this.boundOnClose)
    }
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
