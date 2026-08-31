import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "feedback", "nativeButton" ]
  static values = { url: String, title: String, text: String }

  connect() {
    if (this.hasNativeButtonTarget && navigator.share) {
      this.nativeButtonTarget.classList.remove("hidden")
    }
  }

  async copyLink() {
    try {
      await navigator.clipboard.writeText(this.urlValue)
      this.showFeedback("Link copied to clipboard.")
    } catch {
      this.showFeedback("Could not copy the link. Copy it from the address bar of the listing page.")
    }
  }

  async nativeShare() {
    if (!navigator.share) return

    try {
      await navigator.share({
        title: this.titleValue,
        text: this.textValue,
        url: this.urlValue
      })
    } catch (error) {
      if (error.name !== "AbortError") {
        this.showFeedback("Sharing is not available on this device.")
      }
    }
  }

  showFeedback(message) {
    if (!this.hasFeedbackTarget) return

    this.feedbackTarget.textContent = message
    this.feedbackTarget.classList.remove("hidden")

    clearTimeout(this.feedbackTimeout)
    this.feedbackTimeout = setTimeout(() => {
      this.feedbackTarget.classList.add("hidden")
    }, 3000)
  }
}
