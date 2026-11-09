class LikesController < ApplicationController
  before_action :authenticate_user!

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

    # Evitar duplicações
    if request.format.json?
      existing = Like.find_by(liker_id: current_user.id, liked_id: liked_user.id)
      if existing&.is_like == false
        existing.destroy # o "agora não" antigo dá lugar à curtida
      elsif existing
        return render json: like_json(existing)
      end
    end

    if Like.exists?(liker_id: current_user.id, liked_id: liked_user.id)
      # Se veio do MAPA, apenas fecha o popup (ok)
      if params[:source] == "map"
        return head :ok 
      else
        return redirect_to return_path, alert: "Você já curtiu este usuário."
      end
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
        else
          respond_to do |format|
            format.turbo_stream do
              render turbo_stream: turbo_stream.append("body",
                partial: "shared/match_modal",
                locals: {
                  left_name:    current_user.display_name,
                  right_name:   liked_user.display_name,
                  left_avatar:  current_user.avatar.attached? ? url_for(current_user.avatar) : nil,
                  right_avatar: liked_user.avatar.attached?   ? url_for(liked_user.avatar)   : nil,
                  message_path: match_path(match),
                  dismiss_path: return_path
                })
            end
            format.html { redirect_to return_path, notice: "Deu match! 🎉" }
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