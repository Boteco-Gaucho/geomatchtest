import { Controller } from "@hotwired/stimulus"
import { showToast } from "../show_toast"

// Fazer uma denúncia (/report_incident): "Sobre quem?" (painel com as pessoas das
// conversas) e "Prints ou fotos" (até 3, com miniatura e botão de remover).
// As fotos ficam no próprio <input type=file>: cada escolha nova soma às anteriores.
const MAX_PHOTOS = 3

export default class extends Controller {
  static targets = ["picker", "personName", "personAvatar", "photoInput", "photoSlots"]

  connect() {
    this._files = []
    this._urls = []
  }

  disconnect() {
    this._revokeUrls()
  }

  // ---- Sobre quem? ----

  openPicker() {
    this.pickerTarget.hidden = false
  }

  closePicker() {
    if (this.hasPickerTarget) this.pickerTarget.hidden = true
  }

  pick(event) {
    const { name, avatar } = event.target.dataset
    const chosen = Boolean(event.target.value)

    this.personNameTarget.textContent = chosen ? name : "Escolher um perfil das suas conversas"
    this.personNameTarget.closest(".ri-person").classList.toggle("is-chosen", chosen)
    this.personAvatarTarget.replaceChildren()
    if (chosen) {
      const img = document.createElement("img")
      img.src = avatar
      img.alt = ""
      this.personAvatarTarget.append(img)
    } else {
      this.personAvatarTarget.append(this._personIcon())
    }
    this.closePicker()
  }

  // ---- Prints ou fotos ----

  addPhotos() {
    const picked = Array.from(this.photoInputTarget.files)
    const images = picked.filter((file) => file.type.startsWith("image/"))
    const room = MAX_PHOTOS - this._files.length

    if (images.length < picked.length) showToast("Só dá para anexar imagens.", true)
    if (images.length > room) showToast(`Até ${MAX_PHOTOS} fotos por denúncia.`, true)

    this._files = this._files.concat(images.slice(0, Math.max(room, 0)))
    this._syncInput()
    this._renderPhotos()
  }

  removePhoto(event) {
    this._files.splice(Number(event.currentTarget.dataset.index), 1)
    this._syncInput()
    this._renderPhotos()
  }

  // O input passa a conter todas as fotos escolhidas (é ele que vai no envio)
  _syncInput() {
    try {
      const transfer = new DataTransfer()
      this._files.forEach((file) => transfer.items.add(file))
      this.photoInputTarget.files = transfer.files
    } catch (_) {
      // Navegador sem DataTransfer: fica valendo só a última escolha
      this._files = Array.from(this.photoInputTarget.files).slice(0, MAX_PHOTOS)
    }
  }

  _renderPhotos() {
    this._revokeUrls()
    const slots = this._files.map((file, index) => {
      const url = URL.createObjectURL(file)
      this._urls.push(url)

      const slot = document.createElement("div")
      slot.className = "ri-photo ri-photo--filled"
      slot.innerHTML =
        `<img alt="">` +
        `<button type="button" class="ri-photo-remove" aria-label="Remover foto" ` +
        `data-action="report-form#removePhoto" data-index="${index}">✕</button>`
      slot.querySelector("img").src = url
      return slot
    })

    if (this._files.length < MAX_PHOTOS) slots.push(this._addSlot())
    while (slots.length < MAX_PHOTOS) {
      const empty = document.createElement("span")
      empty.className = "ri-photo ri-photo--empty"
      slots.push(empty)
    }
    this.photoSlotsTarget.replaceChildren(...slots)
  }

  _addSlot() {
    const label = document.createElement("label")
    label.className = "ri-photo ri-photo--add"
    label.htmlFor = this.photoInputTarget.id
    label.innerHTML =
      `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M14.5 4h-5L7 7H4a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2h-3l-2.5-3z"/><circle cx="12" cy="13" r="3"/></svg>` +
      `<span>Adicionar</span>`
    return label
  }

  _personIcon() {
    const template = document.createElement("template")
    template.innerHTML = `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>`
    return template.content.firstElementChild
  }

  _revokeUrls() {
    this._urls.forEach((url) => URL.revokeObjectURL(url))
    this._urls = []
  }
}
