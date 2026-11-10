# app/controllers/notifications_controller.rb
class NotificationsController < ApplicationController
  before_action :authenticate_user!

  def index
    photo_includes = { avatar_attachment: :blob, album_photos_attachments: :blob }

    # 1. Quem te curtiu — só curtidas e matches (Mimo não é curtida) e sem quem
    #    está bloqueado nos dois sentidos: bloquear apaga likes e matches, mas não
    #    as notificações, então elas precisam ser filtradas aqui. Contas banidas
    #    também ficam de fora. Uma entrada por pessoa (a mais recente).
    #    Só quem ainda espera resposta: quem você descartou (X — Like is_like: false) ou
    #    já curtiu de volta (virou match: está em Mensagens > Novas conexões) sai da lista.
    @notifications = current_user.notifications
      .where(notifiable_type: %w[Like Match])
      .where.not(actor_id: current_user.excluded_user_ids)
      .where.not(actor_id: Like.where(liker_id: current_user.id).select(:liked_id))
      .joins(:actor).merge(User.where(banned_at: nil))
      .includes(actor: photo_includes)
      .order(created_at: :desc)
      .to_a
      .uniq(&:actor_id)

    # 2. Quem VOCÊ curtiu (o X — is_like: false — não é curtida)
    @my_likes = Like.positive.where(liker_id: current_user.id)
      .includes(liked: photo_includes)
      .order(created_at: :desc)

    # Estado do coração "curtir de volta" de cada card: quem você já curtiu e,
    # se já deu match, a conversa para onde o coração leva.
    actor_ids = @notifications.map(&:actor_id)
    # (só curtida de verdade: o X — is_like: false — não é "já curtiu")
    @liked_back_ids = Like.positive.where(liker_id: current_user.id, liked_id: actor_ids).pluck(:liked_id).to_set
    @matches_by_user = Match.for_user(current_user.id)
                            .where("user_id IN (:ids) OR matched_user_id IN (:ids)", ids: actor_ids)
                            .index_by { |match| match.user_id == current_user.id ? match.matched_user_id : match.user_id }

    # Painel de upgrade de quem não pode ver quem curtiu (mockup: Gold). Nome e
    # preço vêm do plano no banco — o painel nunca mostra um preço diferente do
    # que o checkout cobra.
    @upsell_plan = Plan.active.find_by(code: "gold") unless current_user.can_see_who_liked_me?

    # Marca todas como lidas ao visitar a página
    current_user.notifications.unread.update_all(read_at: Time.current)
  end
end
