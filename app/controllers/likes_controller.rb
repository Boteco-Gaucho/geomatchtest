class LikesController < ApplicationController
  before_action :authenticate_user!

  # Retribuiu pela tela de Curtidas ou pelo perfil: depois do "É um match!" a conversa
  # abre sozinha (dá tempo de ver a animação; "Conversar agora" abre na hora)
  MATCH_AUTO_FORWARD_MS = 4500

  def create
    liked_user = User.find(params[:user_id])

    # 1. VERIFICAÇÃO DE LIMITE
    unless current_user.can_like?
      return render(json: { status: "limit", upgrade_required: true }, status: :forbidden) if request.format.json?

      respond_to do |format|
        # --- MUDANÇA AQUI: Usa 'update' no container específico ---
        format.turbo_stream { 
          render turbo_stream: turbo_stream.update("upgrade-modal-container", partial: "shared/upgrade_modal", locals: { type: 'likes' }) 
        }
        format.html { redirect_to return_path, alert: "Você atingiu seu limite de curtidas diárias." }
      end
      return
    end
    # =======================================================

    # Evitar duplicações. O "agora não" (X) antigo dá lugar à curtida em qualquer tela —
    # antes só no mapa (JSON); no perfil e em Curtidas dizia "Você já curtiu" e nada acontecia.
    existing = Like.find_by(liker_id: current_user.id, liked_id: liked_user.id)
    if existing&.is_like == false
      existing.destroy
      existing = nil
    end

    if existing
      return render json: like_json(existing) if request.format.json?
      # Se veio do MAPA, apenas fecha o popup (ok)
      return head :ok if params[:source] == "map"

      # Já curtiu e já é match: leva para a conversa em vez de só avisar
      if (match = match_with(liked_user))
        return redirect_to match_path(match), status: :see_other, notice: "Vocês já deram match. Que tal mandar uma mensagem?"
      end
      return redirect_to return_path, status: :see_other, alert: "Você já curtiu este usuário."
    end

    @like = Like.new(liker_id: current_user.id, liked_id: liked_user.id)

    if @like.save
      
      # =====================================================
      # 2. INCREMENTA O CONTADOR (NOVO)
      # =====================================================
      current_user.increment_likes!
      # =====================================================

      # Se o outro usuário já curtiu você → MATCH
      if Like.exists?(liker_id: liked_user.id, liked_id: current_user.id)

        existing_match = Match.where(
          "(user_id = ? AND matched_user_id = ?) OR (user_id = ? AND matched_user_id = ?)",
          current_user.id, liked_user.id,
          liked_user.id, current_user.id 
        ).first

        match = existing_match
        unless existing_match
          user_id = [current_user.id, liked_user.id].min
          matched_user_id = [current_user.id, liked_user.id].max
          match = Match.create!(user_id: user_id, matched_user_id: matched_user_id, status: "matched")
        end
        # Já conversavam (ex.: começaram pelo "Mensagem" do mapa): não é um match "novo"
        already_talking = existing_match.present? && match.messages.exists?

        # 🔔 Notificação de MATCH
        notification = Notification.create(
          recipient: liked_user,
          actor: current_user,
          action: "vocês deram match!",
          notifiable: match
        )

        NotificationBroadcastJob.perform_later(notification)

        # --- LÓGICA DE RETORNO DO MATCH ---
        # Match não se desfaz: o mapa leva direto para a conversa
        if request.format.json?
          render json: { status: "match", match_path: match_path(match) }
        elsif params[:source] == "map"
          redirect_to match_path(match)
        elsif already_talking
          # Sem modal de "match novo": a curtida vale e a pessoa vai para a conversa que já existe
          redirect_to match_path(match), status: :see_other, notice: "Curtida enviada! Vocês já estão conversando."
        else
          # Curtidas e perfil: "É um match!" e, sozinho em alguns segundos, a conversa.
          # O card de quem curtiu sai da grade na hora (virou conexão).
          from_likes = %w[likes profile].include?(params[:source])
          respond_to do |format|
            format.turbo_stream do
              streams = [ turbo_stream.append("body",
                partial: "shared/match_modal",
                locals: {
                  left_name:    current_user.display_name,
                  right_name:   liked_user.display_name,
                  left_avatar:  current_user.avatar.attached? ? url_for(current_user.avatar) : nil,
                  right_avatar: liked_user.avatar.attached?   ? url_for(liked_user.avatar)   : nil,
                  message_path: match_path(match),
                  dismiss_path: return_path,
                  dismiss_label: from_likes ? "Agora não" : "Continuar deslizando",
                  auto_forward_ms: from_likes ? MATCH_AUTO_FORWARD_MS : 0
                }) ]
              streams << turbo_stream.remove("like-card-#{liked_user.id}") if params[:source] == "likes"
              render turbo_stream: streams
            end
            format.html { redirect_to match_path(match), status: :see_other, notice: "Deu match! 🎉" }
          end
        end

      else
        # 🔔 Notificação de LIKE RECEBIDO
        notification = Notification.create(
          recipient: liked_user,
          actor: current_user,
          action: "curtiu seu perfil",
          notifiable: @like
        )

        # Só avisa depois da janela para desfazer: quem desfaz a curtida não notifica
        NotificationBroadcastJob.set(wait: Like::UNDO_WINDOW).perform_later(notification)

        # --- LÓGICA DE RETORNO DO LIKE SIMPLES ---
        if request.format.json?
          render json: like_json(@like), status: :created
        elsif params[:source] == "map"
          # Se veio do mapa, apenas diz OK (para o JS fechar o popup)
          head :ok
        else
          # Se veio do swipe, recarrega a página para o próximo card
          redirect_to return_path, notice: "Curtida enviada!"
        end
      end

    else
      # Erro ao salvar
      if request.format.json?
        render json: { error: "Não foi possível registrar a curtida." }, status: :unprocessable_entity
      elsif params[:source] == "map"
        head :unprocessable_entity
      else
        redirect_to return_path, alert: "Não foi possível registrar a curtida."
      end
    end

  rescue => e
    Rails.logger.error("Erro ao curtir: #{e.message}")
    if request.format.json?
      render json: { error: "Erro interno no servidor." }, status: :internal_server_error
    elsif params[:source] == "map"
      head :internal_server_error
    else
      redirect_to return_path, alert: "Erro interno no servidor."
    end
  end

  # DELETE /likes/:id — descurtir pelo mapa, só dentro da janela (Like::UNDO_WINDOW).
  # Apaga a curtida e a notificação (que ainda não foi enviada) e devolve a curtida ao
  # saldo do plano Free. Curtida que virou match não se desfaz.
  def destroy
    like = current_user.likes.positive.find_by(id: params[:id])
    return render(json: { error: "Curtida não encontrada." }, status: :not_found) unless like

    if !like.undoable? || match_between?(current_user.id, like.liked_id)
      return render json: like_json(like).merge(error: "Essa curtida já está valendo e não dá mais para desfazer."),
                    status: :unprocessable_entity
    end

    Like.transaction do
      Notification.where(notifiable: like).delete_all
      like.destroy!
      refund_like!(like)
    end

    render json: { status: "unliked", user_id: like.liked_id }
  end

  private

  def like_json(like)
    { status: "liked", like_id: like.id, user_id: like.liked_id, undo_seconds: like.undo_seconds_left }
  end

  def match_with(other)
    Match.where("(user_id = :a AND matched_user_id = :b) OR (user_id = :b AND matched_user_id = :a)",
                a: current_user.id, b: other.id).first
  end

  def match_between?(a, b)
    Match.where("(user_id = :a AND matched_user_id = :b) OR (user_id = :b AND matched_user_id = :a)", a: a, b: b).exists?
  end

  # A curtida desfeita não conta no limite do plano Free. (A janela é de segundos e o
  # contador zera a cada 5 h: ela sempre foi contada no período atual.)
  def refund_like!(_like)
    return if current_user.likes_count.to_i <= 0

    current_user.decrement!(:likes_count)
  end

  # "Curtir de volta" pela tela de Curtidas (source=likes) volta para ela —
  # inclusive ao fechar o modal de match. Curtir pelo perfil (source=profile)
  # fica no perfil. Os demais fluxos seguem para o Início.
  def return_path
    case params[:source]
    when "likes"   then notifications_path
    when "profile" then user_path(params[:user_id])
    else lead_path
    end
  end
end