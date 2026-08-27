import { Controller } from "@hotwired/stimulus"

// Two phases:
// - pack_ready: leave the "Building…" screen as soon as captions exist (listing ready/failed)
// - posters: stay on the pack view and reload when a poster card changes / all finish
export default class extends Controller {
  static values = {
    interval: { type: Number, default: 2500 },
    url: String,
    maxAttempts: { type: Number, default: 120 },
    until: { type: String, default: "pack_ready" } // pack_ready | posters
  }

  connect() {
    this.attempts = 0
    this.lastPosters = null
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

      if (this.untilValue === "pack_ready") {
        // Still writing captions — keep the Building… screen.
        if (data.status === "generating" || data.status === "pending") return
        // Captions ready (or failed) — go to pack view even if posters are still queueing.
        this.disconnect()
        this.reloadPage()
        return
      }

      // Poster phase: refresh when any card state changes; stop when all done.
      const snapshot = JSON.stringify(data.posters || {})
      if (this.lastPosters === null) {
        this.lastPosters = snapshot
      } else if (snapshot !== this.lastPosters) {
        this.lastPosters = snapshot
        this.disconnect()
        this.reloadPage()
        return
      }

      if (data.posters_complete === false) return

      this.disconnect()
    } catch (_error) {
      return
    }
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
