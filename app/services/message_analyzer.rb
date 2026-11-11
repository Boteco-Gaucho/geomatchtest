# Serviço de análise de linguagem natural para mensagens
# Usado pelo endpoint GET /api/v1/admin/word_cloud
class MessageAnalyzer
  STOP_WORDS = %w[
    a ao aos aqui as assim até bem boa bom
    com como da das de do dos e é ela elas
    ele eles em então essa esse isso isto
    já mais mas me mesmo na não nas nem no
    nos nossa nossas nosso nossos o os ou para
    pela pelas pelo pelos pois por porque que
    quem se sem ser sim só sua suas também te
    ter tu tua tuas tudo um uma uns umas você
    vocês vou foi foram ser estar ter muito pouco
    boa bom sim não né ok olá oi ótimo tudo bem
  ].freeze

  BLACKLIST = %w[
    idiota imbecil burro lixo odeio matar morte
    estupido stupido vagabundo vadia prostituta
    cretino inutil inútil feio feia gordo gorda
    macaco escrava escrave racista racismo nazi
    fascista fascismo merda bosta puta puto
  ].freeze

  BLACKLIST_THRESHOLD = 10

  # region: string para filtrar pelo campo address (ILIKE %region%)
  def self.analyze(from: 30.days.ago, to: Time.current, region: nil)
    scope = Message.where(created_at: from..to)

    if region.present?
      user_ids  = User.where('address ILIKE ?', "%#{sanitize(region)}%").pluck(:id)
      match_ids = Match.where(user_id: user_ids)
                       .or(Match.where(matched_user_id: user_ids))
                       .pluck(:id)
      scope = scope.where(match_id: match_ids)
    end

    words = tokenize(scope.pluck(:content))
    freq  = words.tally

    top_words = freq.sort_by { |_, v| -v }
                    .first(10)
                    .map { |word, count| { word: word, count: count } }

    alerts = BLACKLIST.filter_map do |bad_word|
      count = freq[bad_word].to_i
      count >= BLACKLIST_THRESHOLD ? { word: bad_word, count: count } : nil
    end.sort_by { |a| -a[:count] }

    {
      top_words:       top_words,
      blacklist_alerts: alerts,
      total_messages:  scope.count,
      period_from:     from.to_date.to_s,
      period_to:       to.to_date.to_s
    }
  end

  private

  def self.tokenize(texts)
    combined = texts.join(' ').downcase
    # Mantém apenas palavras com 3+ letras, incluindo acentos portugueses
    words = combined.scan(/\b[a-záéíóúàâêôãõüç]{3,}\b/)
    words.reject { |w| STOP_WORDS.include?(w) }
  end

  def self.sanitize(str)
    str.to_s.gsub(/[%_]/, '\\\0')
  end
end
