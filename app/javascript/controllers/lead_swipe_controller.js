import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card", "like", "nope", "profileModal",
                    "btnLike", "btnReject", "btnRewind"]

  // ============================================================
  // LIFECYCLE
  // ============================================================
  connect() {
    this._thrown  = false
    this.isDragging = false
    this.pointerId  = null
    this.startX = this.startY = this.currentX = this.currentY = 0

    this._onMove = this.handleMove.bind(this)
    this._onUp   = this.handleEnd.bind(this)

    window.addEventListener('pointermove',   this._onMove)
    window.addEventListener('pointerup',     this._onUp)
    window.addEventListener('pointercancel', this._onUp)
  }

  disconnect() {
    window.removeEventListener('pointermove',   this._onMove)
    window.removeEventListener('pointerup',     this._onUp)
    window.removeEventListener('pointercancel', this._onUp)
  }

  // ============================================================
  // TARGET CALLBACKS — reconectam automaticamente após Turbo Stream
  // ============================================================
  cardTargetConnected(el) {
    this._thrown = false
    this.isDragging = false
    el.style.cursor     = 'grab'
    el.style.touchAction = 'none'
    el._leadSwipeDown = this.handleStart.bind(this)
    el.addEventListener('pointerdown', el._leadSwipeDown)
    el.addEventListener('dragstart', e => e.preventDefault())
  }

  cardTargetDisconnected(el) {
    if (el._leadSwipeDown) el.removeEventListener('pointerdown', el._leadSwipeDown)
  }

  btnLikeTargetConnected(el) {
    el._leadSwipeClick = (e) => { e.preventDefault(); this._throwCard('like') }
    el.addEventListener('click', el._leadSwipeClick)
  }

  btnLikeTargetDisconnected(el) {
    if (el._leadSwipeClick) el.removeEventListener('click', el._leadSwipeClick)
  }

  btnRejectTargetConnected(el) {
    el._leadSwipeClick = (e) => { e.preventDefault(); this._throwCard('reject') }
    el.addEventListener('click', el._leadSwipeClick)
  }

  btnRejectTargetDisconnected(el) {
    if (el._leadSwipeClick) el.removeEventListener('click', el._leadSwipeClick)
  }

  // Botão rewind não precisa de lógica especial — submete o form normalmente via Turbo
  // O Turbo Stream response atualiza #swipe-area e cardTargetConnected reinicializa tudo

  // ============================================================
  // MODAL DE PERFIL COMPLETO
  // ============================================================
  openProfile(event) {
    if (event) { event.preventDefault(); event.stopPropagation() }
    if (this.hasProfileModalTarget) {
      this.profileModalTarget.classList.add("open")
      document.body.style.overflow = "hidden"
    }
  }

  closeProfile(event) {
    if (event) { event.preventDefault(); event.stopPropagation() }
    if (this.hasProfileModalTarget) {
      this.profileModalTarget.classList.remove("open")
      document.body.style.overflow = ""
    }
  }

  // ============================================================
  // POINTER EVENTS — DRAG
  // ============================================================
  handleStart(event) {
    if (this.hasProfileModalTarget && this.profileModalTarget.classList.contains("open")) return
    if (event.target.closest('button') || event.target.closest('.clickable-info')) return
    if (this.isDragging) return

    this.isDragging = true
    this.pointerId  = event.pointerId
    this.startX     = event.clientX
    this.startY     = event.clientY
    this.currentX   = event.clientX
    this.currentY   = event.clientY

    if (this.hasCardTarget) {
      this.cardTarget.style.transition = 'none'
      this.cardTarget.style.cursor     = 'grabbing'
    }
  }

  handleMove(event) {
    if (!this.isDragging || event.pointerId !== this.pointerId) return

    const deltaX = event.clientX - this.startX
    const deltaY = event.clientY - this.startY

    if (Math.abs(deltaX) > Math.abs(deltaY) && Math.abs(deltaX) > 5) {
      event.preventDefault()
    }

    this.currentX = event.clientX
    this.currentY = event.clientY

    this._updateVisuals(deltaX, deltaY)
  }

  handleEnd(event) {
    if (!this.isDragging || event.pointerId !== this.pointerId) return

    this.isDragging = false
    this.pointerId  = null

    if (this.hasCardTarget) this.cardTarget.style.cursor = 'grab'

    const deltaX    = this.currentX - this.startX
    const THRESHOLD = 120

    if (Math.abs(deltaX) > THRESHOLD) {
      this._throwCard(deltaX > 0 ? 'like' : 'reject')
    } else {
      this._resetCard()
    }
  }

  // ============================================================
  // VISUAIS — ARRASTO
  // ============================================================
  _updateVisuals(deltaX, deltaY) {
    if (!this.hasCardTarget) return

    const rotation = deltaX / 18
    const lift     = deltaY * 0.25
    this.cardTarget.style.transform = `translateX(${deltaX}px) translateY(${lift}px) rotate(${rotation}deg)`

    const progress = Math.min(1, Math.abs(deltaX) / 100)

    if (deltaX > 0) {
      if (this.hasLikeTarget)      this.likeTarget.style.opacity = progress
      if (this.hasNopeTarget)      this.nopeTarget.style.opacity = 0
      if (this.hasBtnLikeTarget)   this.btnLikeTarget.classList.toggle('btn-highlight', progress > 0.3)
      if (this.hasBtnRejectTarget) this.btnRejectTarget.classList.remove('btn-highlight')
    } else if (deltaX < 0) {
      if (this.hasNopeTarget)      this.nopeTarget.style.opacity = progress
      if (this.hasLikeTarget)      this.likeTarget.style.opacity = 0
      if (this.hasBtnRejectTarget) this.btnRejectTarget.classList.toggle('btn-highlight', progress > 0.3)
      if (this.hasBtnLikeTarget)   this.btnLikeTarget.classList.remove('btn-highlight')
    } else {
      if (this.hasLikeTarget)      this.likeTarget.style.opacity = 0
      if (this.hasNopeTarget)      this.nopeTarget.style.opacity = 0
      if (this.hasBtnLikeTarget)   this.btnLikeTarget.classList.remove('btn-highlight')
      if (this.hasBtnRejectTarget) this.btnRejectTarget.classList.remove('btn-highlight')
    }
  }

  _resetCard() {
    if (!this.hasCardTarget) return
    this.cardTarget.style.transition = 'transform 0.4s cubic-bezier(0.2, 0.8, 0.2, 1)'
    this.cardTarget.style.transform  = 'translateX(0) translateY(0) rotate(0deg)'
    if (this.hasLikeTarget)      this.likeTarget.style.opacity = 0
    if (this.hasNopeTarget)      this.nopeTarget.style.opacity = 0
    if (this.hasBtnLikeTarget)   this.btnLikeTarget.classList.remove('btn-highlight')
    if (this.hasBtnRejectTarget) this.btnRejectTarget.classList.remove('btn-highlight')
  }

  // ============================================================
  // AÇÃO — VOAR PARA FORA + SUBMETER
  // ============================================================
  _throwCard(type) {
    if (!this.hasCardTarget) return
    if (this._thrown) return
    this._thrown = true

    const isLike = type === 'like'
    const endX   = isLike ? window.innerWidth * 1.6 : -window.innerWidth * 1.6

    if (isLike  && this.hasLikeTarget) this.likeTarget.style.opacity = 1
    if (!isLike && this.hasNopeTarget) this.nopeTarget.style.opacity = 1

    this.cardTarget.style.transition = 'transform 0.45s ease-in, opacity 0.4s ease-in'
    this.cardTarget.style.transform  = `translateX(${endX}px) rotate(${isLike ? 35 : -35}deg)`
    this.cardTarget.style.opacity    = '0'

    const target = isLike ? this.btnLikeTarget : this.btnRejectTarget
    const form   = target ? target.closest('form') : null
    if (form) {
      setTimeout(() => form.requestSubmit(target), 250)
    } else {
      setTimeout(() => location.reload(), 600)
    }
  }

}
