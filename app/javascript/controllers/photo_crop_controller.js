import { Controller } from "@hotwired/stimulus"

// Ajuste da foto no Editar perfil (users/_photo_crop_modal.html.erb).
// Escolheu foto (principal ou do álbum) → o modal abre com ela; nada é enviado antes de
// "Confirmar". Quadro 3:4: arrastar, pinça, roda do mouse, barra de zoom (afasta até caber
// a foto inteira — o resto do quadro vira a própria foto desfocada) e girar 90°.
// Confirmar desenha exatamente o que está no quadro num canvas 1080×1440 (JPEG 88%):
//   - foto principal → POST apply_crop (anexa como avatar) e recarrega a página;
//   - fotos do álbum (pode escolher várias: ajusta uma de cada vez) → troca os arquivos do
//     campo pelos recortados e envia o formulário, como antes.
// Cancelar descarta a foto da vez (e segue para a próxima, se houver).
const OUT_W = 1080
const OUT_H = 1440
const QUALITY = 0.88
const MAX_ZOOM = 4 // além do "preencher o quadro"

export default class extends Controller {
  static targets = ["modal", "wrap", "photo", "box", "zoom", "title", "confirm", "avatarInput", "albumInput"]
  static values = { avatarUrl: String, freeSlots: Number }

  connect() {
    this.pointers = new Map()
    this.queue = []
    this.done = []
    this._onResize = () => { if (!this.modalTarget.hidden) { this.fit(); this.apply() } }
    window.addEventListener("resize", this._onResize)
    this.wrapTarget.addEventListener("pointerdown", (e) => this.down(e))
    this.wrapTarget.addEventListener("pointermove", (e) => this.move(e))
    ;["pointerup", "pointercancel", "pointerleave"].forEach((type) => this.wrapTarget.addEventListener(type, (e) => this.up(e)))
    this.wrapTarget.addEventListener("wheel", (e) => this.wheel(e), { passive: false })
  }

  disconnect() {
    window.removeEventListener("resize", this._onResize)
    document.body.classList.remove("gm-crop-open")
    this.revoke()
  }

  // ---------- Escolha dos arquivos ----------
  pickAvatar(event) {
    const file = event.target.files?.[0]
    event.target.value = ""
    if (file) this.start("avatar", [ file ])
  }

  pickAlbum(event) {
    const files = Array.from(event.target.files || []).filter((f) => f.type.startsWith("image/") || !f.type)
    this.albumFiles = files
    if (!files.length) return
    const slots = this.hasFreeSlotsValue ? Math.max(0, this.freeSlotsValue) : files.length
    this.start("album", files.slice(0, slots || files.length))
  }

  start(mode, files) {
    this.mode = mode
    this.queue = files
    this.done = []
    this.total = files.length
    this.open()
    this.next()
  }

  next() {
    const file = this.queue.shift()
    if (!file) return this.finish()

    const index = this.total - this.queue.length
    this.titleTarget.textContent = this.total > 1 ? `Ajustar foto ${index} de ${this.total}` : "Ajustar foto"
    this.current = file
    this.revoke()
    this.url = URL.createObjectURL(file)
    const img = this.photoTarget
    img.onload = () => this.loaded()
    img.onerror = () => { this.done.push(file); this.next() } // formato que o navegador não abre: vai como está
    img.src = this.url
  }

  loaded() {
    const img = this.photoTarget
    this.state = { nw: img.naturalWidth, nh: img.naturalHeight, x: 0, y: 0, rotation: 0, scale: 1 }
    img.style.width = `${this.state.nw}px`
    img.style.height = `${this.state.nh}px`
    this.fit(true)
    this.apply()
  }

  // ---------- Medidas ----------
  fit(reset = false) {
    const box = this.boxTarget.getBoundingClientRect()
    const s = this.state
    if (!s) return
    s.boxW = box.width
    s.boxH = box.height
    const rotated = s.rotation % 180 !== 0
    s.ew = rotated ? s.nh : s.nw
    s.eh = rotated ? s.nw : s.nh
    s.contain = Math.min(s.boxW / s.ew, s.boxH / s.eh) // foto inteira no quadro
    s.cover = Math.max(s.boxW / s.ew, s.boxH / s.eh)   // quadro todo preenchido
    s.min = s.contain
    s.max = s.cover * MAX_ZOOM
    if (reset) { s.scale = s.cover; s.x = 0; s.y = 0 }
    s.scale = Math.min(s.max, Math.max(s.min, s.scale))
    this.clamp()
    this.syncSlider()
  }

  // A foto não sai do quadro (maior que ele) nem do meio dele (menor que ele)
  clamp() {
    const s = this.state
    const limX = Math.abs(s.ew * s.scale - s.boxW) / 2
    const limY = Math.abs(s.eh * s.scale - s.boxH) / 2
    s.x = Math.min(limX, Math.max(-limX, s.x))
    s.y = Math.min(limY, Math.max(-limY, s.y))
  }

  apply() {
    const s = this.state
    if (!s) return
    this.photoTarget.style.transform =
      `translate(-50%, -50%) translate(${s.x}px, ${s.y}px) rotate(${s.rotation}deg) scale(${s.scale})`
  }

  setScale(scale) {
    const s = this.state
    if (!s) return
    s.scale = Math.min(s.max, Math.max(s.min, scale))
    this.clamp()
    this.apply()
    this.syncSlider()
  }

  // Barra em escala logarítmica entre "foto inteira" e 4× o "preencher"
  syncSlider() {
    const s = this.state
    if (!s || !this.hasZoomTarget) return
    const t = Math.log(s.scale / s.min) / Math.log(s.max / s.min || 2)
    this.zoomTarget.value = String(Math.round(Math.max(0, Math.min(1, t)) * 1000))
  }

  slide() {
    const s = this.state
    if (!s) return
    const t = Number(this.zoomTarget.value) / 1000
    this.setScale(s.min * Math.pow(s.max / s.min, t))
  }

  zoomIn() { if (this.state) this.setScale(this.state.scale * 1.15) }
  zoomOut() { if (this.state) this.setScale(this.state.scale / 1.15) }

  rotate() {
    if (!this.state) return
    const s = this.state
    const ratio = s.scale / s.cover // mantém o "quanto de zoom" ao girar
    s.rotation = (s.rotation + 90) % 360
    this.fit()
    s.scale = Math.min(s.max, Math.max(s.min, s.cover * ratio))
    this.clamp()
    this.apply()
    this.syncSlider()
  }

  // ---------- Gestos ----------
  down(e) {
    if (!this.state) return
    this.wrapTarget.setPointerCapture?.(e.pointerId)
    this.pointers.set(e.pointerId, { x: e.clientX, y: e.clientY })
    if (this.pointers.size === 1) {
      this.drag = { x: e.clientX, y: e.clientY, ox: this.state.x, oy: this.state.y }
      this.wrapTarget.dataset.dragging = "true"
    } else if (this.pointers.size === 2) {
      const [a, b] = [ ...this.pointers.values() ]
      this.pinch = { dist: Math.hypot(b.x - a.x, b.y - a.y), scale: this.state.scale }
      this.drag = null
    }
  }

  move(e) {
    if (!this.pointers.has(e.pointerId) || !this.state) return
    this.pointers.set(e.pointerId, { x: e.clientX, y: e.clientY })
    if (this.pinch && this.pointers.size >= 2) {
      const [a, b] = [ ...this.pointers.values() ]
      this.setScale(this.pinch.scale * (Math.hypot(b.x - a.x, b.y - a.y) / this.pinch.dist))
    } else if (this.drag) {
      this.state.x = this.drag.ox + (e.clientX - this.drag.x)
      this.state.y = this.drag.oy + (e.clientY - this.drag.y)
      this.clamp()
      this.apply()
    }
  }

  up(e) {
    this.pointers.delete(e.pointerId)
    if (this.pointers.size < 2) this.pinch = null
    if (this.pointers.size === 0) { this.drag = null; delete this.wrapTarget.dataset.dragging }
  }

  wheel(e) {
    if (!this.state) return
    e.preventDefault()
    this.setScale(this.state.scale * (1 - e.deltaY * 0.0015))
  }

  // ---------- Confirmar / Cancelar ----------
  async confirm() {
    if (!this.state || this.busy) return
    this.busy = true
    this.confirmTarget.disabled = true
    try {
      const blob = await this.render()
      this.done.push(new File([ blob ], `foto-${Date.now()}.jpg`, { type: "image/jpeg" }))
    } catch (error) {
      console.error("[GeoMatch] Recorte da foto:", error)
      this.done.push(this.current) // não conseguiu recortar: vai a original
    } finally {
      this.busy = false
      this.confirmTarget.disabled = false
    }
    this.next()
  }

  cancel() {
    if (this.modalTarget.hidden) return
    this.next() // descarta só a foto da vez
  }

  // Desenha no canvas exatamente o que está no quadro (mesmas contas do transform)
  render() {
    const s = this.state
    const img = this.photoTarget
    const canvas = document.createElement("canvas")
    canvas.width = OUT_W
    canvas.height = OUT_H
    const ctx = canvas.getContext("2d")
    const k = OUT_W / s.boxW
    const draw = (scale, x, y) => {
      ctx.save()
      ctx.translate(OUT_W / 2 + x * k, OUT_H / 2 + y * k)
      ctx.rotate((s.rotation * Math.PI) / 180)
      ctx.scale(scale * k, scale * k)
      ctx.drawImage(img, -s.nw / 2, -s.nh / 2)
      ctx.restore()
    }

    // Afastou além do quadro: o fundo é a própria foto, desfocada
    if (s.scale < s.cover - 0.0001) {
      ctx.fillStyle = "#1a1714"
      ctx.fillRect(0, 0, OUT_W, OUT_H)
      if ("filter" in ctx) {
        ctx.filter = "blur(28px) brightness(0.75)"
        draw(s.cover * 1.08, 0, 0)
        ctx.filter = "none"
      }
    }
    draw(s.scale, s.x, s.y)

    return new Promise((resolve, reject) => {
      canvas.toBlob((blob) => (blob ? resolve(blob) : reject(new Error("toBlob vazio"))), "image/jpeg", QUALITY)
    })
  }

  // ---------- Abrir / fechar / enviar ----------
  open() {
    this.modalTarget.hidden = false
    document.body.classList.add("gm-crop-open")
  }

  close() {
    this.modalTarget.hidden = true
    document.body.classList.remove("gm-crop-open")
    this.photoTarget.removeAttribute("src")
    this.state = null
    this.revoke()
  }

  finish() {
    const files = this.done
    const mode = this.mode
    this.close()
    if (!files.length) {
      if (mode === "album" && this.hasAlbumInputTarget) this.albumInputTarget.value = ""
      return
    }
    if (mode === "avatar") return this.uploadAvatar(files[0])
    return this.uploadAlbum(files)
  }

  async uploadAvatar(file) {
    const body = new FormData()
    body.append("avatar", file)
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    document.body.classList.add("gm-crop-saving")
    try {
      const response = await fetch(this.avatarUrlValue, {
        method: "POST", body, headers: { "X-CSRF-Token": token || "", Accept: "application/json" }
      })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
    } catch (error) {
      console.error("[GeoMatch] Enviar foto principal:", error)
    }
    if (window.Turbo) window.Turbo.visit(window.location.href, { action: "replace" })
    else window.location.reload()
  }

  uploadAlbum(files) {
    const input = this.albumInputTarget
    const transfer = new DataTransfer()
    files.forEach((file) => transfer.items.add(file))
    input.files = transfer.files
    document.body.classList.add("gm-crop-saving")
    input.form.submit() // como antes: o formulário do Editar perfil leva as fotos
  }

  revoke() {
    if (this.url) URL.revokeObjectURL(this.url)
    this.url = null
  }
}
