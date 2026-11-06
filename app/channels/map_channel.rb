class MapChannel < ApplicationCable::Channel
  # Atualizações de posição chegam só a quem está a até 300 m de quem se moveu
  # (UsersController#broadcast_map_presence) — cada pessoa tem o seu stream.
  # O stream geral "map_updates" fica só para os avisos de saída ("leave").
  def self.user_stream(user_id)
    "map_updates:user_#{user_id}"
  end

  def subscribed
    stream_from "map_updates"
    stream_from self.class.user_stream(current_user.id)
  end

  def unsubscribed
    # Intencionalmente vazio.
    #
    # A visibilidade no mapa é PERSISTENTE — uma desconexão de WebSocket
    # (tela bloqueada, app em segundo plano, queda de rede) NÃO remove o
    # usuário do mapa de outros. Ele continua aparecendo na sua última
    # localização conhecida enquanto tiver coordenadas válidas no banco.
    #
    # O broadcast "leave" é disparado em logout explícito
    # (Users::SessionsController#destroy) e ao ligar o modo oculto ou desligar a
    # localização (UsersController).
  end
end
