# POST /users/:user_id/prompt_replies — Gold responde uma pergunta do perfil de alguém.
# A resposta vira mensagem (citando a pergunta) na conversa entre os dois, criada se ainda
# não existir — mesmo sem match. Responde com Turbo Stream: o cartão da pergunta passa a
# "Respondida" e desce o aviso "Resposta enviada" (shared/_prompt_reply_toast).
# Quem não é Gold recebe o aviso do Gold (o botão já abre esse aviso antes, no navegador).
class PromptRepliesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_prompt

  def create
    return gold_required unless current_user.can_reply_prompts?

    content = params[:content].to_s.strip
    if content.blank? || content.length > ProfilePrompt::REPLY_MAX
      return fail_with("Escreva sua resposta (até #{ProfilePrompt::REPLY_MAX} caracteres).")
    end

    # Já respondeu esta pergunta: mostra o estado "Respondida" (sem uma segunda mensagem)
    @reply = existing_reply || Message.transaction do
      match = Match.where(user: current_user, matched_user: @owner)
                   .or(Match.where(user: @owner, matched_user: current_user)).first ||
              Match.create!(user: current_user, matched_user: @owner)
      match.messages.create!(sender: current_user, content: content,
                             prompt_key: @prompt.question_key,
                             prompt_question: @prompt.question,
                             prompt_answer: @prompt.answer)
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(view_context.dom_id(@prompt),
                               partial: "users/profile_prompt",
                               locals: { prompt: @prompt, owner: @owner, reply: @reply }),
          turbo_stream.append("body", partial: "shared/prompt_reply_toast",
                                      locals: { first_name: first_name(@owner) })
        ]
      end
      format.html { redirect_to user_path(@owner), notice: "Resposta enviada! #{first_name(@owner)} recebe como mensagem." }
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "[PromptReplies] user=#{current_user.id} owner=#{@owner&.id}: #{e.message}"
    fail_with("Não foi possível enviar sua resposta agora.")
  end

  private

  def set_prompt
    return head(:not_found) unless ProfilePrompt.available?

    @owner = User.find_by(id: params[:user_id])
    unavailable = @owner.nil? || @owner == current_user ||
                  current_user.excluded_user_ids.include?(@owner.id) ||
                  @owner.invisible? || @owner.account_frozen? || @owner.banned?
    return fail_with("Perfil indisponível.", status: :not_found) if unavailable

    @prompt = @owner.profile_prompts.find_by(question_key: params[:prompt_key].to_s)
    fail_with("Essa pergunta não está mais no perfil.", status: :not_found) unless @prompt
  end

  def existing_reply
    Message.joins(:match)
           .where(sender_id: current_user.id, prompt_key: @prompt.question_key)
           .where("matches.user_id = :id OR matches.matched_user_id = :id", id: @owner.id)
           .order(created_at: :desc).first
  end

  def gold_required
    respond_to do |format|
      format.turbo_stream { render turbo_stream: toast("Responder perguntas é do plano Gold.", "alert"), status: :forbidden }
      format.html { redirect_to plans_path, alert: "Responder perguntas é do plano Gold." }
    end
  end

  def fail_with(message, status: :unprocessable_entity)
    respond_to do |format|
      format.turbo_stream { render turbo_stream: toast(message, "alert"), status: status }
      format.html { redirect_back fallback_location: (@owner ? user_path(@owner) : root_path), alert: message }
    end
  end

  def toast(message, type)
    turbo_stream.prepend("toast-container", partial: "shared/toast", locals: { message: message, type: type })
  end

  def first_name(user)
    user.display_name.to_s.split.first.presence || "A pessoa"
  end
end
