import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "tab", "panel" ]
  static values = { active: { type: String, default: "post" } }

  connect() {
    this.show(this.activeValue)
  }

  select(event) {
    this.show(event.params.id)
  }

  show(id) {
    this.tabTargets.forEach((tab) => {
      const selected = tab.dataset.tabsIdParam === id
      tab.setAttribute("aria-selected", selected)
      tab.classList.toggle("btn-primary", selected)
      tab.classList.toggle("btn-secondary", !selected)
    })
    this.panelTargets.forEach((panel) => {
      panel.classList.toggle("hidden", panel.dataset.tab !== id)
    })
  }
}
