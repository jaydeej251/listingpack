import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "preview" ]

  preview(event) {
    if (!this.hasPreviewTarget) return

    this.previewTarget.innerHTML = ""
    Array.from(event.target.files || []).forEach((file) => {
      if (!file.type.startsWith("image/")) return

      const img = document.createElement("img")
      img.src = URL.createObjectURL(file)
      img.alt = file.name
      img.className = "h-24 w-24 rounded-xl object-cover"
      this.previewTarget.appendChild(img)
    })
  }
}
