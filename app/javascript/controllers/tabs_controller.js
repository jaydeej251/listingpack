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

  keydown(event) {
    const keys = [ "ArrowLeft", "ArrowRight", "Home", "End" ]
    if (!keys.includes(event.key)) return

    event.preventDefault()
    const tabs = this.tabTargets
    const index = tabs.indexOf(event.currentTarget)
    if (index < 0) return

    let next = index
    if (event.key === "ArrowRight") next = (index + 1) % tabs.length
    if (event.key === "ArrowLeft") next = (index - 1 + tabs.length) % tabs.length
    if (event.key === "Home") next = 0
    if (event.key === "End") next = tabs.length - 1

    const tab = tabs[next]
    this.show(tab.dataset.tabsIdParam)
    tab.focus()
  }

  show(id) {
    this.activeValue = id
    this.tabTargets.forEach((tab) => {
      const selected = tab.dataset.tabsIdParam === id
      tab.setAttribute("aria-selected", selected ? "true" : "false")
      tab.setAttribute("tabindex", selected ? "0" : "-1")
      tab.classList.toggle("btn-primary", selected)
      tab.classList.toggle("btn-secondary", !selected)
    })
    this.panelTargets.forEach((panel) => {
      const selected = panel.dataset.tab === id
      panel.classList.toggle("hidden", !selected)
      panel.hidden = !selected
    })
  }
}
