import { Controller } from "@hotwired/stimulus"

// Poll a JSON status URL. When work finishes, reload the full page once so
// header pills and the pack render together — never leave a "Loading pack…" frame.
export default class extends Controller {
  static values = {
    interval: { type: Number, default: 2500 },
    url: String
  }

  connect() {
    this.timer = setInterval(() => this.refresh(), this.intervalValue)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  async refresh() {
    const url = this.hasUrlValue ? this.urlValue : this.element.getAttribute("src")
    if (!url) return

    try {
      const response = await fetch(url, {
        headers: { Accept: "application/json" },
        credentials: "same-origin"
      })
      if (!response.ok) return

      const data = await response.json()
      if (data.status === "generating" || data.status === "pending") return
    } catch (_error) {
      return
    }

    this.disconnect()
    this.reloadPage()
  }

  reloadPage() {
    if (window.Turbo?.visit) {
      window.Turbo.visit(window.location.href, { action: "replace" })
    } else {
      window.location.reload()
    }
  }
}
