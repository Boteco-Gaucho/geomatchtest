import { Controller } from "@hotwired/stimulus"
import { openUpgradeModal } from "../upgrade_modal"

// Olho de "Explorar cidades": some (ou volta) só da busca por cidades.
// O mapa tem o seu próprio modo oculto — um não mexe no outro.
//   POST url → { hidden: bool } | 403 { upgrade_required } (Gold) | 503 (coluna ainda não criada)
const ICONS = {
  globe: '<circle cx="12" cy="12" r="10"/><path d="M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20"/><path d="M2 12h20"/>',
  globeOff: '<path d="M8.6 3.1A10 10 0 0 1 21 15.4M5 5a10 10 0 0 0 14 14"/><path d="M12 2a14.5 14.5 0 0 1 3.6 9.5M12 22a14.5 14.5 0 0 1-3.9-12.4"/><path d="M2 12h10m5 0h5"/><path d="M2 2l20 20"/>',
  ghost: '<path d="M9 10h.01M15 10h.01"/><path d="M12 2a8 8 0 0 0-8 8v12l3-3 2.5 2.5L12 19l2.5 2.5L17 19l3 3V10a8 8 0 0 0-8-8z"/>'
}

const MESSAGES = {
  hidden: { icon: "globeOff", tone: "red", title: "Você está oculto na busca por cidades",
            text: "Quem procura pessoas de outras cidades não vai encontrar seu perfil. No mapa, tudo continua igual: quem está perto ainda te vê." },
  shown:  { icon: "globe", tone: "green", title: "Você voltou a aparecer na busca por cidades",
            text: "Pessoas de outras cidades já podem encontrar seu perfil e te mandar mensagem. No mapa, nada muda." },
  gold:   { icon: "ghost", tone: "dark", title: "Modo oculto é do Gold",
            text: "Suma da busca por cidades sem sair do mapa." },
  error:  { icon: "globe", tone: "sand", title: "Não deu para mudar agora", text: "Verifique a conexão e tente de novo." }
}

const TOAST_MS = 5000

export default class extends Controller {
  static values = { url: String, hidden: Boolean }

  async toggle() {
    if (this._busy) return
    this._busy = true

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: { "Accept": "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content }
      })

      if (response.status === 403) {
        this._toast(MESSAGES.gold, { label: "Ver Gold", onClick: () => openUpgradeModal("invisible") })
        return
      }
      if (!response.ok) throw new Error(`HTTP ${response.status}`)

      const data = await response.json()
      this.hiddenValue = data.hidden
      this._toast(data.hidden ? MESSAGES.hidden : MESSAGES.shown)
    } catch (error) {
      console.error("[GeoMatch] Olho de Explorar cidades:", error)
      this._toast(MESSAGES.error)
    } finally {
      this._busy = false
    }
  }

  hiddenValueChanged() {
    this.element.classList.toggle("is-hidden", this.hiddenValue)
    this.element.setAttribute("aria-pressed", String(this.hiddenValue))
  }

  disconnect() {
    clearTimeout(this._timer)
  }

  // Aviso embaixo do topo + halo no botão enquanto ele estiver na tela
  _toast({ icon, tone, title, text }, action = null) {
    const toast = document.getElementById("ce-toast")
    if (!toast) return

    const iconEl = toast.querySelector(".ce-toast__icon")
    iconEl.innerHTML = `<svg viewBox="0 0 24 24" aria-hidden="true">${ICONS[icon]}</svg>`
    iconEl.dataset.tone = tone
    toast.querySelector(".ce-toast__title").textContent = title
    toast.querySelector(".ce-toast__body").textContent = text

    const button = toast.querySelector(".ce-toast__action")
    button.hidden = !action
    button.textContent = action ? action.label : ""
    button.onclick = action ? (event) => { event.stopPropagation(); this._hideToast(); action.onClick() } : null
    toast.onclick = () => this._hideToast()

    toast.hidden = false
    toast.classList.remove("is-visible")
    void toast.offsetWidth
    toast.classList.add("is-visible")
    this.element.classList.add("is-pinged")

    clearTimeout(this._timer)
    this._timer = setTimeout(() => this._hideToast(), TOAST_MS)
  }

  _hideToast() {
    const toast = document.getElementById("ce-toast")
    clearTimeout(this._timer)
    this.element.classList.remove("is-pinged")
    if (!toast || toast.hidden) return
    toast.classList.remove("is-visible")
    this._timer = setTimeout(() => { toast.hidden = true }, 200)
  }
}
