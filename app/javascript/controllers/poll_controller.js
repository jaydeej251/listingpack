import { Controller } from "@hotwired/stimulus"

// Two phases:
// - pack_ready: leave "Building…" with a full visit once captions exist
// - posters: refresh only the listing_posters Turbo Frame (no scroll jump)
export default class extends Controller {
  static values = {
    interval: { type: Number, default: 2500 },
    url: String,
    maxAttempts: { type: Number, default: 120 },
    until: { type: String, default: "pack_ready" }, // pack_ready | posters
    frame: { type: String, default: "listing_posters" },
    frameUrl: String
  }

  connect() {
    this.attempts = 0
    this.lastPosters = null
    this.timer = setInterval(() => this.refresh(), this.intervalValue)
    // Don't wait a full interval when the HTML may already be behind the worker.
    if (this.untilValue === "posters") this.refresh()
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
        if (data.status === "generating" || data.status === "pending") return
        this.disconnect()
        this.reloadPage()
        return
      }

      const snapshot = JSON.stringify(data.posters || {})
      const isFirstPoll = this.lastPosters === null
      const changed = this.lastPosters !== snapshot
      this.lastPosters = snapshot

      // First poll must refresh: page HTML is often stale (e.g. 0/6) while JSON
      // already shows posters ready after the pack_ready reload.
      if (isFirstPoll || changed) {
        await this.refreshPostersFrame()
      }

      if (data.posters_complete === false) return

      this.disconnect()
      await this.refreshPostersFrame()
    } catch (_error) {
      return
    }
  }

  posterFrameUrl() {
    if (this.hasFrameUrlValue) return this.frameUrlValue
    if (this.hasUrlValue) return this.urlValue.replace(/status\.json$/, "posters")
    return window.location.href
  }

  async refreshPostersFrame() {
    const frame = document.getElementById(this.frameValue)
    const url = this.posterFrameUrl()

    if (frame && window.Turbo?.visit) {
      await window.Turbo.visit(url, { frame: this.frameValue, action: "replace" })
      return
    }

    if (frame && typeof frame.reload === "function") {
      frame.src = url
      frame.reload()
      return
    }

    // Last resort — full reload (may jump scroll).
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
