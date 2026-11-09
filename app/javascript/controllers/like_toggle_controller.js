import { Controller } from "@hotwired/stimulus"
import { openUpgradeModal } from "../upgrade_modal"
import { showMapToast } from "../map_toast"

// Coração do mapa (prévia do pin e perfil completo — shared/_like_toggle.html.erb).
//   vazio      → toque curte (POST /likes, JSON)
//   desfazível → cheio, com o anel do tempo; toque descurte (DELETE /likes/:id)
//   valendo    → cheio e travado: passou a janela (Like::UNDO_WINDOW) ou já era curtido
// O ícone muda na hora do toque; se o servidor recusar, volta ao estado anterior.
// Deu match: vai direto para a conversa (match não se desfaz).
// A prévia do pin troca de pessoa mandando "like-toggle:load" (map_3d.js); cada mudança
// avisa com "like-toggle:changed" para o mapa lembrar o estado daquela pessoa.
export default class extends Controller {
  static values = { userId: Number, likeId: Number, liked: Boolean, undoSeconds: Number }

  connect() {
    this.apply(this.likedValue, this.likeIdValue, this.undoSecondsValue)
  }

  disconnect() {
    clearTimeout(this.lockTimer)
  }

  // map_3d.js: a prévia abriu para outra pessoa
  load(event) {
    const { userId, liked, likeId, undoSeconds } = event.detail
    this.userIdValue = userId
    this.busy = false
    this.apply(!!liked, likeId || 0, undoSeconds || 0)
  }

  async toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    if (this.busy || this.state === "locked") return
    if (this.state === "undoable") return this.unlike()
    return this.like()
  }

  async like() {
    this.busy = true
    this.render("pending") // cheio na hora
    try {
      const response = await this.request("/likes", "POST", { user_id: this.userIdValue, source: "map" })
      const data = await response.json().catch(() => ({}))

      if (response.status === 403 && data.upgrade_required) {
        this.apply(false, 0, 0)
        await openUpgradeModal("likes")
        return
      }
      if (!response.ok) throw new Error(data.error || `HTTP ${response.status}`)

      if (data.status === "match") {
        this.render("locked")
        const go = () => (window.Turbo ? window.Turbo.visit(data.match_path) : (window.location.href = data.match_path))
        go()
        return
      }

      this.apply(true, data.like_id, data.undo_seconds)
      if (data.undo_seconds > 0) {
        showMapToast({ icon: "heart", tone: "green", title: "Curtida enviada",
                       text: `Toque no coração de novo em até ${data.undo_seconds}s para desfazer.`, duration: 3000 })
      }
    } catch (error) {
      console.error("[GeoMatch] Curtir:", error)
      this.apply(false, 0, 0)
      showMapToast({ icon: "heart", tone: "sand", title: "Não deu para curtir agora", text: "Verifique a conexão e tente de novo." })
    } finally {
      this.busy = false
    }
  }

  async unlike() {
    this.busy = true
    const previous = { likeId: this.likeIdValue, until: this.undoUntil }
    clearTimeout(this.lockTimer)
    this.render("idle") // vazio na hora
    try {
      const response = await this.request(`/likes/${previous.likeId}`, "DELETE")
      const data = await response.json().catch(() => ({}))

      if (response.status === 422) {
        // A janela fechou no caminho: a curtida já vale
        this.apply(true, data.like_id || previous.likeId, 0)
        showMapToast({ icon: "heart", tone: "sand", title: "A curtida já está valendo", text: "O tempo para desfazer acabou." })
        return
      }
      if (!response.ok && response.status !== 404) throw new Error(`HTTP ${response.status}`)

      this.apply(false, 0, 0)
      showMapToast({ icon: "heartOff", tone: "sand", title: "Curtida desfeita", text: "Ninguém foi avisado.", duration: 2500 })
    } catch (error) {
      console.error("[GeoMatch] Descurtir:", error)
      const left = Math.max(0, Math.ceil((previous.until - Date.now()) / 1000))
      this.apply(true, previous.likeId, left)
    } finally {
      this.busy = false
    }
  }

  // Estado a partir dos dados (e o relógio da janela)
  apply(liked, likeId, undoSeconds) {
    clearTimeout(this.lockTimer)
    this.likeIdValue = likeId || 0
    this.likedValue = liked

    if (!liked) return this.render("idle")
    if (undoSeconds > 0 && likeId) {
      this.undoUntil = Date.now() + undoSeconds * 1000
      this.element.style.setProperty("--like-undo-ms", `${undoSeconds * 1000}ms`)
      this.render("undoable")
      this.lockTimer = setTimeout(() => this.render("locked"), undoSeconds * 1000)
    } else {
      this.render("locked")
    }
  }

  render(state) {
    this.state = state
    const el = this.element
    const filled = state !== "idle"
    el.classList.toggle("is-liked", filled)
    el.classList.toggle("is-undoable", state === "undoable")
    el.classList.toggle("is-locked", state === "locked")
    el.disabled = state === "locked"
    el.setAttribute("aria-pressed", String(filled))
    const label = { idle: "Curtir", pending: "Curtindo…", undoable: "Desfazer curtida", locked: "Você já curtiu" }[state]
    el.setAttribute("aria-label", label)
    el.title = label

    // Reinicia o anel do tempo
    el.classList.remove("is-counting")
    if (state === "undoable") { void el.offsetWidth; el.classList.add("is-counting") }

    if (state !== "pending") {
      el.dispatchEvent(new CustomEvent("like-toggle:changed", {
        bubbles: true,
        detail: { userId: this.userIdValue, liked: filled, likeId: this.likeIdValue,
                  undoUntil: state === "undoable" ? this.undoUntil : 0 }
      }))
    }
  }

  request(url, method, body = null) {
    return fetch(url, {
      method,
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
      },
      body: body ? JSON.stringify(body) : null
    })
  }
}
