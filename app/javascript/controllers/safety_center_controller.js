import { Controller } from "@hotwired/stimulus"
import { showToast } from "../show_toast"

// Central de Segurança: "Compartilhar local" e "Modo Pânico".
// O GPS só responde depois do toque, e alguns navegadores (Safari/iOS) só abrem a
// folha de compartilhamento logo após o toque — quando ela não abre (ou não existe),
// aparece um painel com WhatsApp / Copiar, que funcionam com um toque novo.
const GEO_OPTIONS = { enableHighAccuracy: true, timeout: 10000, maximumAge: 15000 }

const LOCATION_ERRORS = {
  1: "Permita o acesso à localização para compartilhar onde você está.",
  2: "Não conseguimos sua localização agora. Verifique o GPS e tente de novo.",
  3: "A localização demorou para responder. Tente de novo."
}

export default class extends Controller {
  static targets = ["shareStatus", "panicStatus", "sheet", "sheetTitle", "sheetMessage", "whatsapp", "moreOptions"]
  static values = { name: String }

  connect() {
    this._statusTexts = new Map() // botões buscando o GPS → texto original
    this._pending = null          // mensagem esperando o painel
  }

  shareLocation() {
    this._locate(this.shareStatusTarget, "Obtendo localização...", (mapUrl, error) => {
      if (!mapUrl) {
        showToast(LOCATION_ERRORS[error?.code] || "Seu navegador não suporta geolocalização.", true)
        return
      }

      this._share("Localização pronta", {
        title: "Minha localização",
        text: "Estou aqui! Segue minha localização atual:",
        url: mapUrl
      })
    })
  }

  // Sem GPS o alerta sai do mesmo jeito, só sem o link do mapa
  panic() {
    this._locate(this.panicStatusTarget, "Preparando alerta...", (mapUrl) => {
      if (!mapUrl) showToast("Não conseguimos sua localização. O alerta vai sem o mapa.", true)

      const name = this.nameValue || "Um usuário do GeoMatch"
      const contact = mapUrl
        ? `entre em contato o mais breve possível e veja a localização atual aqui: ${mapUrl}`
        : "entre em contato o mais breve possível."

      this._share("Alerta pronto", {
        title: "ALERTA DE SEGURANÇA - GeoMatch",
        text: `Olá! Esta é uma mensagem de alerta 🚨 do GeoMatch. ${name} ativou o modo de segurança e pode precisar da sua ajuda ou atenção. Por favor, ${contact} Sua atenção é muito importante neste momento.`
      })
    })
  }

  closeSheet() {
    if (this.hasSheetTarget) this.sheetTarget.hidden = true
    this._pending = null
  }

  // Antes do Turbo guardar a página no cache: painel fechado e textos originais
  reset() {
    this.closeSheet()
    this._statusTexts.forEach((text, element) => { element.textContent = text })
    this._statusTexts.clear()
  }

  async moreOptions() {
    if (!this._pending) return

    try {
      await navigator.share(this._pending.data)
      this.closeSheet()
    } catch (error) {
      if (error.name !== "AbortError") showToast("Não foi possível abrir as opções de compartilhamento.", true)
    }
  }

  copy() {
    if (!this._pending) return

    const text = this._pending.text
    const done = () => {
      this.closeSheet()
      showToast("Mensagem copiada. Cole na conversa com quem você confia.")
    }
    const fallback = () => {
      const area = document.createElement("textarea")
      area.value = text
      area.setAttribute("readonly", "")
      area.style.cssText = "position:fixed;top:0;left:0;opacity:0"
      document.body.appendChild(area)
      area.select()
      let copied = false
      try { copied = document.execCommand("copy") } catch (_) { copied = false }
      area.remove()
      copied ? done() : showToast("Não foi possível copiar.", true)
    }

    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(done, fallback)
    } else {
      fallback()
    }
  }

  // Busca o GPS mostrando `loadingText` no botão; ignora toques repetidos
  _locate(status, loadingText, done) {
    if (this._statusTexts.has(status)) return
    if (!navigator.geolocation) {
      done(null, null)
      return
    }

    this._statusTexts.set(status, status.textContent)
    status.textContent = loadingText

    const finish = (mapUrl, error) => {
      if (!this._statusTexts.has(status)) return // a pessoa já saiu da tela

      status.textContent = this._statusTexts.get(status)
      this._statusTexts.delete(status)
      done(mapUrl, error)
    }

    navigator.geolocation.getCurrentPosition(
      ({ coords }) => finish(`https://www.google.com/maps?q=${coords.latitude},${coords.longitude}`),
      (error) => finish(null, error),
      GEO_OPTIONS
    )
  }

  // Folha nativa primeiro; se o navegador recusar (fora do toque) ou não tiver, o painel
  async _share(title, data) {
    if (navigator.share) {
      try {
        await navigator.share(data)
        return
      } catch (error) {
        if (error.name === "AbortError") return // a pessoa fechou a folha
      }
    }

    this._openSheet(title, data)
  }

  _openSheet(title, data) {
    const text = data.url ? `${data.text} ${data.url}` : data.text
    this._pending = { text, data }

    this.sheetTitleTarget.textContent = title
    this.sheetMessageTarget.textContent = text
    this.whatsappTarget.href = `https://wa.me/?text=${encodeURIComponent(text)}`
    this.moreOptionsTarget.hidden = !navigator.share
    this.sheetTarget.hidden = false
  }
}
