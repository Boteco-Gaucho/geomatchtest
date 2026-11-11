module ApplicationHelper
  def turbo_native_app?
    request.user_agent.to_s.include?('Turbo Native')
  end

  def render_turbo_stream_flash_messages
    turbo_stream.prepend 'toast-container', partial: 'shared/flash'
  end

  # Estima tempo de leitura (palavra média = 5 caracteres, leitura = 200 palavras/minuto)
  def estimate_reading_time(text)
    return 1 if text.blank?
    word_count = text.split.length
    (word_count / 200.0).ceil
  end
end
