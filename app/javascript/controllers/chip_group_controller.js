import { Controller } from "@hotwired/stimulus"

// Grupo de chips do Editar perfil (users/edit_sections). Com checkboxes:
//   - max: limite de escolhas (Lugares que eu curto: 5) — o chip que passaria do limite não marca
//   - exclusive: "Prefiro não informar" vale sozinho (marca ele = desmarca os outros, e vice-versa)
//   - count: mostra "N de max"
export default class extends Controller {
  static targets = ["count"]
  static values = { max: Number, exclusive: String }

  connect() {
    this.updateCount()
  }

  change(event) {
    const input = event.target
    if (input.type !== "checkbox") return

    const boxes = this.checkboxes()
    if (input.checked && this.hasExclusiveValue && this.exclusiveValue) {
      if (input.value === this.exclusiveValue) {
        boxes.forEach((box) => { if (box !== input) box.checked = false })
      } else {
        boxes.forEach((box) => { if (box.value === this.exclusiveValue) box.checked = false })
      }
    }

    if (input.checked && this.maxValue > 0 && input.value !== this.exclusiveValue) {
      const chosen = boxes.filter((box) => box.checked && box.value !== this.exclusiveValue)
      if (chosen.length > this.maxValue) {
        input.checked = false
        this.element.classList.remove("is-full")
        void this.element.offsetWidth
        this.element.classList.add("is-full") // pisca o "N de 5"
      }
    }
    this.updateCount()
  }

  checkboxes() {
    return Array.from(this.element.querySelectorAll("input[type=checkbox]"))
  }

  updateCount() {
    if (!this.hasCountTarget || !this.maxValue) return
    const chosen = this.checkboxes().filter((box) => box.checked && box.value !== this.exclusiveValue).length
    this.countTarget.textContent = `${chosen} de ${this.maxValue}`
  }
}
