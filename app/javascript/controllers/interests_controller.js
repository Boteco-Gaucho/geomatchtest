import { Controller } from "@hotwired/stimulus"

// Interesses de Editar Perfil: cada chip leva um input hidden user[hobbies_list][]
// (gravado no "Salvar"). Máximo de `max`; das sugestões aparecem as `shown`
// primeiras que ainda não foram escolhidas.
export default class extends Controller {
  static targets = ["list", "chip", "count", "addButton", "input", "suggestion", "template"]
  static values  = { max: Number, shown: Number }

  add({ params: { value } }) {
    this.append(String(value))
  }

  remove(event) {
    event.currentTarget.closest("[data-interests-target='chip']").remove()
    this.render()
  }

  open() {
    this.addButtonTarget.hidden = true
    this.inputTarget.hidden = false
    this.inputTarget.focus()
  }

  // Enter adiciona sem enviar o formulário e deixa o campo aberto para o próximo;
  // Esc desiste
  keydown(event) {
    if (event.key === "Enter") {
      event.preventDefault()
      this.append(this.inputTarget.value)
      this.inputTarget.value = ""
      if (this.isFull) this.inputTarget.blur()
    } else if (event.key === "Escape") {
      this.inputTarget.value = ""
      this.inputTarget.blur()
    }
  }

  // Ao sair do campo: adiciona o que foi digitado e volta o "+ Adicionar"
  commit() {
    const value = this.inputTarget.value
    this.inputTarget.value = ""
    this.inputTarget.hidden = true
    this.append(value)
  }

  append(raw) {
    // Vírgula separa os interesses no banco (User#hobbies_list)
    const value = raw.replace(/,/g, " ").replace(/\s+/g, " ").trim()

    if (value && !this.isFull && !this.chosen.includes(value.toLowerCase())) {
      const chip = this.templateTarget.content.firstElementChild.cloneNode(true)
      chip.querySelector(".pe-interest-name").textContent = value
      chip.querySelector("input").value = value
      chip.querySelector("button").setAttribute("aria-label", `Remover ${value}`)
      this.listTarget.insertBefore(chip, this.addButtonTarget)
    }
    this.render()
  }

  render() {
    const chosen = this.chosen
    this.countTarget.textContent = `${chosen.length} de ${this.maxValue}`
    this.addButtonTarget.hidden = this.isFull || !this.inputTarget.hidden

    let shown = 0
    this.suggestionTargets.forEach(button => {
      const visible = shown < this.shownValue &&
                      !chosen.includes(button.dataset.interestsValueParam.toLowerCase())
      button.hidden = !visible
      button.disabled = this.isFull
      if (visible) shown++
    })
  }

  get chosen() {
    return this.chipTargets.map(chip => chip.querySelector("input").value.toLowerCase())
  }

  get isFull() {
    return this.chipTargets.length >= this.maxValue
  }
}
