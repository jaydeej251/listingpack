import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "card", "accent", "ink", "logo", "headshot" ]

  connect() {
    this.updateColors()
  }

  updateColors() {
    if (!this.hasCardTarget) return

    if (this.hasAccentTarget) this.cardTarget.style.setProperty("--preview-accent", this.accentTarget.value)
    if (this.hasInkTarget) this.cardTarget.style.setProperty("--preview-ink", this.inkTarget.value)
  }

  previewLogo(event) {
    this.previewFile(event, this.hasLogoTarget ? this.logoTarget : null)
  }

  previewHeadshot(event) {
    this.previewFile(event, this.hasHeadshotTarget ? this.headshotTarget : null)
  }

  previewFile(event, img) {
    const file = event.target.files?.[0]
    if (!file || !img || !file.type.startsWith("image/")) return

    img.src = URL.createObjectURL(file)
    img.classList.remove("hidden")
  }
}
