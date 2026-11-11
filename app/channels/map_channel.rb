class MapChannel < ApplicationCable::Channel
  def subscribed
    stream_from "map_updates"
  end

  def unsubscribed
    # Intencionalmente vazio.
    #
    # A visibilidade no mapa é PERSISTENTE — uma desconexão de WebSocket
    # (tela bloqueada, app em segundo plano, queda de rede) NÃO remove o
    # usuário do mapa de outros. Ele continua aparecendo na sua última
    # localização conhecida enquanto tiver coordenadas válidas no banco.
    #
    # O broadcast "leave" só é disparado em logout explícito,
    # via Users::SessionsController#destroy.
  end
end
