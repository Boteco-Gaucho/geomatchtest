class MessagesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_match
  before_action :set_message, only: [ :update, :destroy, :react, :hide ]

  wrap_parameters format: []

  def index
    @messages = @match.messages.visible_to(current_user).order(created_at: :asc)

    render json: @messages.map { |m|
      {
        id: m.id,
        content: m.content,
        sender_id: m.sender_id,
        reply_to_id: m.reply_to_id,
        created_at: m.created_at.iso8601
      }
    }
  end

  def create
    unless @match.participant?(current_user)
      return head :forbidden
    end

    @message = @match.messages.build(message_params)
    @message.sender = current_user
    @message.reply_to = quoted_message

    if @message.save
      render json: @message.as_json(only: [:id, :content, :sender_id, :reply_to_id, :created_at])
    else
      render json: { errors: @message.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /matches/:match_id/messages/:id — "Editar" (só quem enviou, até 15 min)
  def update
    return head :forbidden unless @message.sender_id == current_user.id
    unless @message.editable_by?(current_user)
      return render json: { error: "Só dá para editar até 15 minutos depois de enviar." }, status: :unprocessable_entity
    end

    content = params.dig(:message, :content).to_s.strip
    return render json: { error: "A mensagem não pode ficar vazia." }, status: :unprocessable_entity if content.blank?

    @message.edit!(content) # broadcasts { edited_message: ... }
    render json: { id: @message.id, content: @message.content, edited_at: @message.edited_at.iso8601 }
  end

  # DELETE /matches/:match_id/messages/:id — "Apagar para todos": só quem enviou,
  # enquanto a outra pessoa não viu ou até 3 min depois de ver (como no WhatsApp)
  def destroy
    return head :forbidden unless @message.sender_id == current_user.id
    unless @message.deletable_for_everyone_by?(current_user)
      return render json: { error: "Só dá para apagar para todos antes de a mensagem ser vista ou até 3 minutos depois." },
                    status: :unprocessable_entity
    end

    @message.destroy # after_destroy_commit broadcasts { deleted_message_id: id }
    head :ok
  end

  # POST /matches/:match_id/messages/:id/hide — "Apagar para mim"
  def hide
    if @message.hide_for!(current_user)
      head :ok
    else
      render json: { error: "Recurso indisponível no momento." }, status: :service_unavailable
    end
  end

  # POST /matches/:match_id/messages/:id/react
  # Toggle/Replace a reação do usuário nessa mensagem
  def react
    emoji = params[:emoji].to_s.strip

    return head :unprocessable_entity if emoji.blank?

    existing = @message.reactions.find_by(user: current_user)

    if existing
      existing.emoji == emoji ? existing.destroy : existing.update!(emoji: emoji)
    else
      @message.reactions.create!(user: current_user, emoji: emoji)
    end

    counts = @message.reactions.group(:emoji).count
    MatchChannel.broadcast_to(@match, {
      reaction: { message_id: @message.id, counts: counts }
    })

    render json: { counts: counts }
  end

  private

  # Só conversas de quem está logado: antes qualquer usuário conseguia listar
  # mensagens e reagir em conversas de outras pessoas pelo id
  def set_match
    @match = current_user.matches.find(params[:match_id])
  end

  def set_message
    @message = @match.messages.visible_to(current_user).find(params[:id])
  end

  def message_params
    params.require(:message).permit(:content)
  end

  # Mensagem citada ao responder (arrastar para a direita no chat). A busca é
  # limitada a esta conversa: id de outra conversa, inexistente ou de uma
  # mensagem apagada enquanto a pessoa digitava não impede o envio — a
  # mensagem sai normalmente, só sem a citação.
  def quoted_message
    reply_to_id = params.dig(:message, :reply_to_id)
    return nil if reply_to_id.blank?

    @match.messages.find_by(id: reply_to_id)
  end
end
