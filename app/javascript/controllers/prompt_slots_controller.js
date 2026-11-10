import { Controller } from "@hotwired/stimulus"

// "Perguntas para puxar assunto" no Editar perfil (users/edit_sections/_prompts):
// cartão (pergunta + resposta + lápis) ↔ edição (lista + resposta). "+ Escolher outra
// pergunta" abre o próximo espaço vazio; "Remover" limpa e esconde. Uma pergunta escolhida
// num espaço fica indisponível nos outros. Tudo vai junto no Salvar do formulário.
export default class extends Controller {
  static targets = ["slot", "add", "count"]

  connect() {
    this.sync()
  }

  edit(event) {
    const slot = event.currentTarget.closest(".pe-pq")
    this.view(slot).hidden = true
    this.form(slot).hidden = false
    this.key(slot).focus()
  }

  done(event) {
    const slot = event.currentTarget.closest(".pe-pq")
    const key = this.key(slot)
    const answer = this.answer(slot)
    if (!key.value) { key.focus(); return }
    if (!answer.value.trim()) { answer.focus(); return }

    slot.querySelector('[data-role="question"]').textContent = key.selectedOptions[0].textContent
    slot.querySelector('[data-role="answer"]').textContent = answer.value.trim()
    this.form(slot).hidden = true
    this.view(slot).hidden = false
    this.sync()
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
    this.key(slot).focus()
    this.sync()
  }

  // Contagem, botão de adicionar e perguntas já usadas em outros espaços
  sync() {
    const visible = this.slotTargets.filter((s) => !s.hidden)
    const filled = this.slotTargets.filter((s) => this.key(s).value && this.answer(s).value.trim())
    if (this.hasCountTarget) this.countTarget.textContent = `${filled.length} de ${this.slotTargets.length}`
    if (this.hasAddTarget) this.addTarget.hidden = visible.length >= this.slotTargets.length

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
