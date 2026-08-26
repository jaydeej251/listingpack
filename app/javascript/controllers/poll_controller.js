import { Controller } from "@hotwired/stimulus"

// Poll a JSON status URL. When work finishes, reload the full page once so
// header pills and the pack render together — never leave a "Loading pack…" frame.
export default class extends Controller {
  static values = {
    interval: { type: Number, default: 2500 },
    url: String,
    maxAttempts: { type: Number, default: 48 } // ~2 minutes at default interval
  }

  connect() {
    this.attempts = 0
    this.timer = setInterval(() => this.refresh(), this.intervalValue)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  async refresh() {
    const url = this.hasUrlValue ? this.urlValue : this.element.getAttribute("src")
    if (!url) return

    this.attempts += 1
    if (this.attempts > this.maxAttemptsValue) {
      this.disconnect()
      this.showStuckHint()
      return
    }

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

  showStuckHint() {
    const hint = this.element.querySelector("[data-poll-stuck]")
    if (hint) {
      hint.classList.remove("hidden")
      hint.hidden = false
      return
    }

    const note = document.createElement("p")
    note.className = "mt-4 text-sm text-clay"
    note.setAttribute("role", "status")
    note.textContent = "Still working longer than usual — tap Check now, or retry if it stays stuck."
    this.element.appendChild(note)
  }

  reloadPage() {
    if (window.Turbo?.visit) {
      window.Turbo.visit(window.location.href, { action: "replace" })
    } else {
      window.location.reload()
    }
  }
}
