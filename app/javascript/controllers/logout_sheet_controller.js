import BottomSheetController from "./bottom_sheet_controller"
import { showToast } from "../show_toast"

// "Sair da sua conta?" — folha inferior de Meu Perfil (base: bottom_sheet_controller.js).
// "Sair" faz DELETE da sessão (Users::SessionsController#destroy responde JSON) e
// recarrega: sem login, a página manda para a entrada.
export default class extends BottomSheetController {
  static targets = ["leave"] // + backdrop, sheet, stay (herdados)
  static values = { url: String }

  async logout() {
    if (this.busy) return
    this.busy = true
    this.leaveTarget.disabled = true
    this.leaveTarget.textContent = "Saindo..."

    try {
      const response = await fetch(this.urlValue, {
        method: "DELETE",
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
        }
      })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      window.location.reload()
    } catch (error) {
      console.error("[GeoMatch] Erro ao sair:", error)
      this.busy = false
      this.leaveTarget.disabled = false
      this.leaveTarget.textContent = "Sair"
      showToast("Não deu para sair agora. Verifique a conexão e tente de novo.", true)
    }
  }
}
