import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "source", "button" ]

  async copy() {
    const text = this.sourceTarget.value || this.sourceTarget.innerText
    await navigator.clipboard.writeText(text)
    const original = this.buttonTarget.textContent
    this.buttonTarget.textContent = "Copied"
    setTimeout(() => { this.buttonTarget.textContent = original }, 1500)
  }
}
