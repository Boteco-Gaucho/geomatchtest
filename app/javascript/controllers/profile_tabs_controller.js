import { Controller } from "@hotwired/stimulus"

// Abas Editar / Pré-visualizar de Editar Perfil (no <form>). A troca acontece na
// mesma página, então o que foi editado continua no formulário. A prévia mostra os
// dados salvos e avisa quando há alterações ainda não salvas; o "Salvar" volta para
// a aba em que a pessoa estava (return_tab).
export default class extends Controller {
  static targets = ["tab", "panel", "returnTab", "unsaved"]

  connect() {
    this.saved = this.snapshot()
  }

  show(event) {
    event.preventDefault()
    const { tab, anchor } = event.params

    this.tabTargets.forEach(link => {
      const active = link.dataset.profileTabsTabParam === tab
      link.classList.toggle("is-active", active)
      if (active) link.setAttribute("aria-current", "page")
      else link.removeAttribute("aria-current")
    })
    this.panelTargets.forEach(panel => { panel.hidden = panel.dataset.tab !== tab })
    this.returnTabTarget.value = tab
    if (tab === "preview") this.unsavedTarget.hidden = this.snapshot() === this.saved

    // "Editar" de uma dica da prévia leva direto ao campo
    const field = anchor && document.getElementById(anchor)
    if (field) field.scrollIntoView({ block: "start" })
    else window.scrollTo(0, 0)
  }

  // Campos do formulário (sem arquivos e sem o token) para saber se algo mudou
  snapshot() {
    return [...new FormData(this.element)]
      .filter(([name, value]) => typeof value === "string" && !["authenticity_token", "return_tab"].includes(name))
      .map(([name, value]) => `${name}=${value}`)
      .join("&")
  }
}
