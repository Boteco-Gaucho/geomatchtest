import { Controller } from "@hotwired/stimulus"

// "Perguntas para puxar assunto" no Editar perfil (users/edit_sections/_prompts):
// cartão (pergunta + resposta + lápis) ↔ edição (lista + resposta). "+ Escolher outra
// pergunta" abre o próximo espaço vazio; "Remover" limpa e esconde. Uma pergunta escolhida
// num espaço fica indisponível nos outros. Tudo vai junto no Salvar do formulário.
export default class extends Controller {
  static targets = ["slot", "add", "count", "picker"]

  connect() {
    this.sync()
  }

  edit(event) {
    const slot = event.currentTarget.closest(".pe-pq")
    this.view(slot).hidden = true
    this.form(slot).hidden = false
    this.answer(slot).focus()
  }

  // ---------- "Selecione uma pergunta" (tela cheia) ----------
  openPicker(event) {
    this.pickingSlot = event.currentTarget.closest(".pe-pq")
    const mine = this.key(this.pickingSlot).value
    const used = this.slotTargets.filter((s) => s !== this.pickingSlot).map((s) => this.key(s).value).filter(Boolean)
    this.pickerTarget.querySelectorAll(".pe-picker-item").forEach((item) => {
      const key = item.dataset.key
      item.classList.toggle("is-selected", key === mine)
      item.setAttribute("aria-pressed", String(key === mine))
      item.disabled = used.includes(key) // já está em outro espaço
    })
    this.pickerTarget.hidden = false
    document.body.classList.add("pe-picker-open")
    const selected = this.pickerTarget.querySelector(".is-selected")
    const list = this.pickerTarget.querySelector(".pe-picker-list")
    list.scrollTop = selected ? selected.offsetTop - 120 : 0
    this.pickerTarget.querySelector(".pe-picker-close").focus({ preventScroll: true })
  }

  pick(event) {
    const slot = this.pickingSlot
    if (!slot) return
    const select = this.key(slot)
    select.value = event.currentTarget.dataset.key
    select.dispatchEvent(new Event("change", { bubbles: true }))
    this.closePicker()
    this.answer(slot).focus()
  }

  closePicker() {
    if (!this.hasPickerTarget || this.pickerTarget.hidden) return
    this.pickerTarget.hidden = true
    document.body.classList.remove("pe-picker-open")
    const button = this.pickingSlot?.querySelector(".pe-pq-pick")
    this.pickingSlot = null
    button?.focus({ preventScroll: true })
  }

  done(event) {
    const slot = event.currentTarget.closest(".pe-pq")
    const key = this.key(slot)
    const answer = this.answer(slot)
    if (!key.value) { slot.querySelector(".pe-pq-pick")?.click(); return }
    if (!answer.value.trim()) { answer.focus(); return }

    slot.querySelector('[data-role="question"]').textContent = key.selectedOptions[0].textContent
    slot.querySelector('[data-role="answer"]').textContent = answer.value.trim()
    this.form(slot).hidden = true
    this.view(slot).hidden = false
    this.sync()
  }

  disconnect() {
    document.body.classList.remove("pe-picker-open")
  }

  remove(event) {
    const slot = event.currentTarget.closest(".pe-pq")
    this.key(slot).value = ""
    this.answer(slot).value = ""
    slot.hidden = true
    this.sync()
  }

  add() {
    const slot = this.slotTargets.find((s) => s.hidden)
    if (!slot) return
    slot.hidden = false
    this.view(slot).hidden = true
    this.form(slot).hidden = false
    this.sync()
    slot.querySelector(".pe-pq-pick")?.click() // já abre a lista
  }

  // Contagem, botão de adicionar e perguntas já usadas em outros espaços
  sync() {
    const visible = this.slotTargets.filter((s) => !s.hidden)
    const filled = this.slotTargets.filter((s) => this.key(s).value && this.answer(s).value.trim())
    if (this.hasCountTarget) this.countTarget.textContent = `${filled.length} de ${this.slotTargets.length}`
    if (this.hasAddTarget) this.addTarget.hidden = visible.length >= this.slotTargets.length

    // O botão de cada espaço mostra a pergunta escolhida
    this.slotTargets.forEach((slot) => {
      const label = slot.querySelector('[data-role="pick-label"]')
      const key = this.key(slot)
      if (label) label.textContent = key.value ? key.selectedOptions[0].textContent : "Escolha uma pergunta"
      slot.querySelector(".pe-pq-pick")?.classList.toggle("is-empty", !key.value)
    })

    const used = this.slotTargets.map((s) => this.key(s).value).filter(Boolean)
    this.slotTargets.forEach((slot) => {
      const mine = this.key(slot).value
      Array.from(this.key(slot).options).forEach((option) => {
        option.disabled = !!option.value && option.value !== mine && used.includes(option.value)
      })
    })
  }

  view(slot) { return slot.querySelector(".pe-pq-view") }
  form(slot) { return slot.querySelector(".pe-pq-form") }
  key(slot) { return slot.querySelector('[data-role="key"]') }
  answer(slot) { return slot.querySelector('[data-role="answer-input"]') }
}
