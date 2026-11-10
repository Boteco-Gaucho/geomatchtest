// Banner "Você já curtiu {nome}" (shared/_already_liked_toast) a partir do navegador, sem
// ir ao servidor: copia o <template id="already-liked-template"> do layout e põe o nome.
// Usado pelo coração do mapa e da prévia do pin (like_toggle_controller) e por qualquer
// botão com data-already-liked-show="Nome" (ex.: o coração do perfil no /lead).
export function showAlreadyLiked(name) {
  const template = document.getElementById("already-liked-template")
  if (!template) return

  document.querySelectorAll(".tt-toast--liked").forEach((el) => el.remove()) // um por vez
  const fragment = template.content.cloneNode(true)
  const slot = fragment.querySelector("[data-already-liked-name]")
  if (slot) slot.textContent = (name || "").trim().split(/\s+/)[0] || "essa pessoa"
  document.body.appendChild(fragment)
}

if (!window.__gmAlreadyLikedWired) {
  window.__gmAlreadyLikedWired = true
  document.addEventListener("click", (event) => {
    const trigger = event.target.closest("[data-already-liked-show]")
    if (!trigger) return
    event.preventDefault()
    showAlreadyLiked(trigger.dataset.alreadyLikedShow)
  })
}
