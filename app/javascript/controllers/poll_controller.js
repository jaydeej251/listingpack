import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { interval: { type: Number, default: 2500 } }

  connect() {
    this.timer = setInterval(() => this.refresh(), this.intervalValue)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  refresh() {
    if (typeof this.element.reload === "function") {
      this.element.reload()
    } else {
      window.location.reload()
    }
  }
}
