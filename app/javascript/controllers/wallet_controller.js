import { Controller } from "@hotwired/stimulus"

// Telas da carteira (estilos .wl-* em wallet.scss):
//   Carteira (pages/mimo_wallet)     — saldo (/wallet) + histórico (/wallet/transactions),
//                                      agrupado por mês, com filtros Tudo / Entradas / Saídas
//   Adicionar saldo (mimo_deposit)   — mode "deposit": valor editável + R$ 20/50/100/Outro,
//                                      POST /wallet/deposit → checkout do Mercado Pago
//   Sacar via Pix (mimo_withdraw)    — mode "withdraw": valor editável + "Sacar tudo" + chave Pix,
//                                      POST /wallet/withdraw → volta à Carteira
const MONTHS       = ["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho",
                      "agosto", "setembro", "outubro", "novembro", "dezembro"]
const MONTHS_SHORT = ["jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"]
const MAX_DIGITS   = 9 // até R$ 9.999.999,99

// Ícone e texto de cada tipo de movimentação (o JSON também serve o app nativo,
// por isso os nomes da tela ficam aqui e não no servidor)
const ENTRY_STYLES = {
  withdrawal:    { title: "Saque para Pix",   icon: '<path d="M12 19V5M6 11l6-6 6 6"/>', tone: "out" },
  deposit:       { title: "Saldo adicionado", icon: '<path d="M12 5v14M5 12h14"/>', tone: "add", detail: "via Mercado Pago" },
  mimo_received: { icon: '<rect x="3.5" y="8" width="17" height="4" rx="1"/><path d="M5 12v8h14v-8M12 8v12M12 8c-1.5-3-5-3.5-5-1.2C7 8 9.5 8 12 8zM12 8c1.5-3 5-3.5 5-1.2C17 8 14.5 8 12 8z"/>', tone: "gift" }
}

export default class extends Controller {
  static targets = [
    "balance", "reserved", "history", "filter",                       // carteira
    "amount", "amountMirror", "after", "preset", "keyOption", "keyInput",
    "error", "submit", "submitLabel"                                  // adicionar / sacar
  ]

  static values = {
    showUrl: String,
    transactionsUrl: String,
    reconcileUrl: String,
    withdrawPageUrl: String,
    walletPageUrl: String,
    depositUrl: String,
    withdrawUrl: String,
    mode: String,                 // "deposit" | "withdraw"
    verb: String,                 // "Adicionar" | "Sacar" (texto do botão)
    available: Number,            // centavos disponíveis
    minimum: Number,              // centavos mínimos (regra do servidor)
    keyType: { type: String, default: "cpf" }
  }

  entries = null        // histórico carregado
  historyFilter = "all"

  connect() {
    if (this.hasHistoryTarget || this.hasBalanceTarget) this.load()
    if (this.hasAmountTarget) {
      this.amountCents = this.parseAmountToCents(this.amountTarget.value)
      this.refreshAmount()
      // A largura do valor depende da fonte (Inter): mede de novo quando ela chegar
      document.fonts?.ready.then(() => { if (this.element.isConnected) this.refreshAmount() })
    }
  }

  // ═════════════════════════ CARTEIRA ═════════════════════════

  // Em série, não em paralelo: GET /wallet concilia os depósitos pendentes contra
  // o Mercado Pago antes de responder, e o extrato precisa ser lido DEPOIS disso —
  // senão o saldo aparece atualizado e o histórico ainda vem sem o depósito.
  async load() {
    if (this.returningFromCheckout() && this.hasReconcileUrlValue) {
      await this.forceReconcile()
    }
    if (this.hasBalanceTarget) await this.loadWallet()
    if (this.hasHistoryTarget) await this.loadTransactions()
  }

  returningFromCheckout() {
    const deposito = new URLSearchParams(window.location.search).get("deposito")
    return deposito === "success" || deposito === "pending"
  }

  // Conciliação explícita: ignora o throttle do servidor. Vale a pena no retorno
  // do checkout, quando o PIX pode ter compensado segundos atrás.
  async forceReconcile() {
    try {
      await fetch(this.reconcileUrlValue, {
        method: "POST",
        headers: { Accept: "application/json", "X-CSRF-Token": this.csrfToken() }
      })
    } catch (e) {
      // A conciliação é reforço, não pré-requisito: seguimos para ler o saldo.
      console.error("[Wallet] reconcile falhou:", e)
    }
  }

  async loadWallet() {
    try {
      const wallet = await this.fetchJson(this.showUrlValue)

      // O card diz "Saldo disponível", então mostra o DISPONÍVEL, não o total: um
      // saque solicitado reserva o valor (pending_withdrawal_cents) até ser pago.
      // Só o número: o "R$" fica à parte no card.
      this.balanceTarget.textContent = this.formatNumber(wallet.available_balance_cents || 0)

      // O valor reservado não some — ele fica explícito, aguardando o saque.
      if (this.hasReservedTarget) {
        const reserved = wallet.pending_withdrawal_cents || 0
        this.reservedTarget.textContent = reserved > 0
          ? `${this.formatCents(reserved)} reservado em saque solicitado`
          : ""
        this.reservedTarget.classList.toggle("is-visible", reserved > 0)
      }
    } catch (e) {
      console.error("[Wallet] loadWallet falhou:", e)
    }
  }

  async loadTransactions() {
    try {
      const data = await this.fetchJson(this.transactionsUrlValue)
      this.entries = data.transactions || []
      this.renderHistory()
    } catch (e) {
      this.historyTarget.classList.remove("is-list")
      this.historyTarget.innerHTML = this.emptyHtml("Não foi possível carregar o extrato.", "Verifique sua conexão e abra a carteira de novo.")
      console.error("[Wallet] loadTransactions falhou:", e)
    }
  }

  // Filtros Tudo / Entradas / Saídas (entrada = valor positivo)
  filterHistory(event) {
    this.historyFilter = event.currentTarget.dataset.filter
    this.filterTargets.forEach((btn) => {
      const active = btn.dataset.filter === this.historyFilter
      btn.classList.toggle("is-active", active)
      btn.setAttribute("aria-pressed", String(active))
    })
    if (this.entries) this.renderHistory()
  }

  renderHistory() {
    const entries = this.entries.filter((entry) => {
      if (this.historyFilter === "in") return entry.amount_cents >= 0
      if (this.historyFilter === "out") return entry.amount_cents < 0
      return true
    })

    if (!entries.length) {
      const [title, text] = {
        all: ["Nenhuma movimentação ainda", "Quando você adicionar ou sacar saldo, tudo aparece aqui."],
        in:  ["Nenhuma entrada ainda", "Saldo adicionado e mimos recebidos aparecem aqui."],
        out: ["Nenhuma saída ainda", "Seus saques via Pix aparecem aqui."]
      }[this.historyFilter]
      this.historyTarget.classList.remove("is-list")
      this.historyTarget.innerHTML = this.emptyHtml(title, text)
      return
    }

    // Um bloco por mês ("OUTUBRO"; com o ano quando não é o atual), na ordem do JSON
    const groups = []
    entries.forEach((entry) => {
      const date = new Date(entry.created_at)
      const key = Number.isNaN(date.getTime()) ? "" : `${date.getFullYear()}-${date.getMonth()}`
      let group = groups[groups.length - 1]
      if (!group || group.key !== key) {
        group = { key, label: this.monthLabel(date), entries: [] }
        groups.push(group)
      }
      group.entries.push(entry)
    })

    this.historyTarget.classList.add("is-list")
    this.historyTarget.innerHTML = groups.map((group) => `
      <div class="wl-month">
        ${group.label ? `<h3 class="wl-month-label">${this.escapeHtml(group.label)}</h3>` : ""}
        <ul class="wl-tx-list">${group.entries.map((entry) => this.entryHtml(entry)).join("")}</ul>
      </div>`).join("")
  }

  entryHtml(entry) {
    const isIn = entry.amount_cents >= 0
    const style = ENTRY_STYLES[entry.type] || {
      icon: isIn ? '<path d="M12 19V5M6 11l6-6 6 6"/>' : '<path d="M12 5v14M6 13l6 6 6-6"/>',
      tone: isIn ? "add" : "out"
    }
    const title = style.title || entry.description
    // status_label distingue "saque pago" de "saque só solicitado" — sem ele
    // um pedido pendente aparece idêntico a um pagamento já concluído.
    const detail = entry.status_label || style.detail
    const meta = [this.formatShortDate(entry.created_at), detail].filter(Boolean).join(" · ")

    return `
      <li class="wl-tx">
        <span class="wl-tx-icon is-${style.tone}" aria-hidden="true"><svg viewBox="0 0 24 24">${style.icon}</svg></span>
        <span class="wl-tx-main">
          <strong>${this.escapeHtml(title)}</strong>
          <small>${this.escapeHtml(meta)}</small>
        </span>
        <span class="wl-tx-value ${isIn ? "is-in" : "is-out"}">${isIn ? "+" : "−"} ${this.formatCents(Math.abs(entry.amount_cents))}</span>
      </li>`
  }

  emptyHtml(title, text) {
    return `
      <div class="wl-empty">
        <span class="wl-empty-icon" aria-hidden="true">
          <svg viewBox="0 0 24 24"><path d="M6 3h12v18l-2-1.5-2 1.5-2-1.5-2 1.5-2-1.5L6 21z"/><path d="M9 8h6M9 12h6M9 16h3"/></svg>
        </span>
        <strong class="wl-empty-title">${this.escapeHtml(title)}</strong>
        <p class="wl-empty-text">${this.escapeHtml(text)}</p>
      </div>`
  }

  goToWithdraw() {
    if (this.hasWithdrawPageUrlValue) window.location.href = this.withdrawPageUrlValue
  }

  // ═════════════════════ ADICIONAR / SACAR ═════════════════════

  // Digitar no valor grande: só dígitos, que entram pela direita (5 → 0,05 → 0,50 → 5,00)
  typeAmount() {
    const digits = this.amountTarget.value.replace(/\D/g, "").replace(/^0+/, "").slice(0, MAX_DIGITS)
    this.amountCents = digits ? parseInt(digits, 10) : 0
    this.markPreset(null)
    this.refreshAmount()
  }

  // Cursor sempre no fim: os dígitos entram pela direita
  focusAmount() {
    requestAnimationFrame(() => {
      const end = this.amountTarget.value.length
      this.amountTarget.setSelectionRange(end, end)
    })
  }

  pickPreset(event) {
    this.amountCents = parseInt(event.currentTarget.dataset.amountCents, 10)
    this.markPreset(event.currentTarget)
    this.refreshAmount()
  }

  // "Outro": zera e abre o teclado para digitar
  pickOther(event) {
    this.amountCents = 0
    this.markPreset(event.currentTarget)
    this.refreshAmount()
    this.amountTarget.focus()
  }

  withdrawAll() {
    this.amountCents = this.availableValue
    this.refreshAmount()
  }

  markPreset(active) {
    // Digitado à mão: vale o botão do mesmo valor, se houver; senão "Outro"
    if (!active && this.hasPresetTarget) {
      active = this.presetTargets.find((btn) => parseInt(btn.dataset.amountCents, 10) === this.amountCents) ||
               this.presetTargets.find((btn) => !btn.dataset.amountCents)
    }
    this.presetTargets.forEach((btn) => {
      btn.classList.toggle("is-active", btn === active)
      btn.setAttribute("aria-pressed", String(btn === active))
    })
  }

  refreshAmount() {
    const text = this.formatNumber(this.amountCents)
    this.amountTarget.value = text
    this.hideError()

    // O campo cresce com o número (o espelho invisível mede a largura)
    if (this.hasAmountMirrorTarget) {
      this.amountMirrorTarget.textContent = text
      this.amountTarget.style.width = `${Math.ceil(this.amountMirrorTarget.offsetWidth) + 2}px`
    }
    if (this.hasAfterTarget) {
      this.afterTarget.textContent = this.formatCents(this.availableValue + this.amountCents)
    }
    if (this.hasSubmitLabelTarget && !this.busy) {
      this.submitLabelTarget.textContent = this.amountCents > 0
        ? `${this.verbValue} ${this.formatCents(this.amountCents)}`
        : this.verbValue
    }
  }

  selectKeyType(event) {
    const option = event.currentTarget
    this.keyTypeValue = option.dataset.keyType
    this.keyOptionTargets.forEach((btn) => {
      btn.classList.toggle("is-active", btn === option)
      btn.setAttribute("aria-pressed", String(btn === option))
    })
    this.keyInputTarget.placeholder = option.dataset.placeholder
    this.keyInputTarget.inputMode = option.dataset.inputmode
    this.keyInputTarget.focus()
  }

  submit() {
    if (this.busy) return
    if (this.modeValue === "deposit") return this.deposit()
    if (this.modeValue === "withdraw") return this.withdraw()
  }

  async deposit() {
    if (this.amountCents < this.minimumValue) {
      return this.showError(`O valor mínimo é ${this.formatCents(this.minimumValue)}.`)
    }

    this.setBusy(true, "Abrindo o Mercado Pago...")
    try {
      const data = await this.postJson(this.depositUrlValue, { amount_cents: this.amountCents })
      window.location.href = data.checkout_url
    } catch (e) {
      this.showError(e.userMessage || "Não deu para iniciar o pagamento. Verifique sua conexão e tente de novo.")
      this.setBusy(false)
    }
  }

  async withdraw() {
    if (this.amountCents < this.minimumValue) {
      return this.showError(`O saque mínimo é ${this.formatCents(this.minimumValue)}.`)
    }
    if (this.amountCents > this.availableValue) {
      return this.showError(`Você tem ${this.formatCents(this.availableValue)} disponível para sacar.`)
    }
    const pixKey = this.keyInputTarget.value.trim()
    if (!pixKey) {
      this.keyInputTarget.focus()
      return this.showError("Informe a sua chave Pix.")
    }

    this.setBusy(true, "Enviando pedido...")
    try {
      await this.postJson(this.withdrawUrlValue, {
        amount_cents: this.amountCents, pix_key: pixKey, pix_key_type: this.keyTypeValue
      })
      window.location.href = this.hasWalletPageUrlValue ? this.walletPageUrlValue : "/carteira"
    } catch (e) {
      this.showError(e.userMessage || "Não deu para pedir o saque. Verifique sua conexão e tente de novo.")
      this.setBusy(false)
    }
  }

  setBusy(busy, label) {
    this.busy = busy
    this.submitTarget.disabled = busy
    this.submitTarget.classList.toggle("is-loading", busy)
    if (busy) {
      this.submitLabelTarget.textContent = label
    } else {
      this.refreshAmount()
    }
  }

  showError(message) {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = message
    this.errorTarget.classList.add("is-visible")
  }

  hideError() {
    if (!this.hasErrorTarget) return
    this.errorTarget.classList.remove("is-visible")
  }

  // ═════════════════════════ Helpers ═════════════════════════

  async fetchJson(url) {
    const response = await fetch(url, { headers: { Accept: "application/json" } })
    if (!response.ok) throw new Error(`GET ${url} -> ${response.status}`)
    return response.json()
  }

  // Erro do servidor (ex.: saldo insuficiente) vira e.userMessage, com a 1ª letra maiúscula
  async postJson(url, body) {
    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "application/json", "X-CSRF-Token": this.csrfToken() },
      body: JSON.stringify(body)
    })
    const data = await response.json().catch(() => ({}))
    if (!response.ok) {
      const error = new Error(`POST ${url} -> ${response.status}`)
      if (data.error) error.userMessage = data.error.charAt(0).toUpperCase() + data.error.slice(1)
      throw error
    }
    return data
  }

  formatNumber(cents) {
    return (cents / 100).toLocaleString("pt-BR", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
  }

  formatCents(cents) {
    return `R$ ${this.formatNumber(cents)}`
  }

  // Aceita "R$ 120,00", "120,00", "120.00" ou "120"
  parseAmountToCents(rawValue) {
    const cleaned = (rawValue || "").replace(/[^\d,.-]/g, "")
    const normalized = cleaned.includes(",")
      ? cleaned.replace(/\./g, "").replace(",", ".")
      : cleaned
    const amount = parseFloat(normalized)
    return Number.isNaN(amount) ? 0 : Math.round(amount * 100)
  }

  // "25 out"
  formatShortDate(iso) {
    const date = new Date(iso)
    if (Number.isNaN(date.getTime())) return ""
    return `${date.getDate()} ${MONTHS_SHORT[date.getMonth()]}`
  }

  // "OUTUBRO" (o CSS põe em maiúsculas); "OUTUBRO 2025" quando não é o ano atual
  monthLabel(date) {
    if (Number.isNaN(date.getTime())) return ""
    const month = MONTHS[date.getMonth()]
    return date.getFullYear() === new Date().getFullYear() ? month : `${month} ${date.getFullYear()}`
  }

  escapeHtml(str) {
    const div = document.createElement("div")
    div.textContent = str || ""
    return div.innerHTML
  }

  csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }
}
