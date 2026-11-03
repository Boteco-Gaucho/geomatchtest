// Aviso rápido no #toast-container, no mesmo formato do flash (shared/_flash)
export function showToast(text, isError = false) {
  const container = document.getElementById("toast-container")
  if (!container) return

  const toast = document.createElement("div")
  toast.className = `toast toast--${isError ? "alert" : "notice"}`
  toast.setAttribute("data-controller", "toast")
  toast.setAttribute("role", "alert")
  toast.setAttribute("aria-live", "polite")
  toast.innerHTML =
    `<span class="toast__message"></span>` +
    `<button class="toast__close" data-action="toast#close" aria-label="Fechar">✕</button>`
  toast.querySelector(".toast__message").textContent = text
  container.prepend(toast)
}
