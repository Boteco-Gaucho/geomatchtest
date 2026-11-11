# Analisador de sentimento léxico para português brasileiro.
# Classifica textos com base em um léxico ponderado (+2/+1/-1/-2).
# Uso: SentimentAnalyzer.distribution(array_of_strings) → { positive:%, negative:%, neutral:%, total: n }
class SentimentAnalyzer

  # ── Léxico PT-BR ───────────────────────────────────────────────────────────
  LEXICON = {
    # Muito positivo (+2)
    'excelente' => 2, 'ótimo' => 2, 'ótima' => 2, 'maravilhoso' => 2,
    'maravilhosa' => 2, 'incrível' => 2, 'fantástico' => 2, 'fantástica' => 2,
    'perfeito' => 2, 'perfeita' => 2, 'espetacular' => 2, 'brilhante' => 2,
    'conquista' => 2, 'vitória' => 2, 'avanço' => 2, 'progresso' => 2,
    'crescimento' => 2, 'sucesso' => 2, 'aprovado' => 2, 'aprovada' => 2,
    'transparência' => 2, 'honesto' => 2, 'honesta' => 2,
    # Positivo (+1)
    'bom' => 1, 'boa' => 1, 'bem' => 1, 'melhor' => 1, 'ótimos' => 1,
    'feliz' => 1, 'alegre' => 1, 'amor' => 1, 'esperança' => 1,
    'melhora' => 1, 'positivo' => 1, 'benefício' => 1, 'eficiente' => 1,
    'confiança' => 1, 'justo' => 1, 'justa' => 1, 'investimento' => 1,
    'desenvolvimento' => 1, 'emprego' => 1, 'seguro' => 1, 'paz' => 1,
    'qualidade' => 1, 'melhoria' => 1, 'direito' => 1, 'direitos' => 1,
    'solução' => 1, 'soluções' => 1, 'apoio' => 1, 'ajuda' => 1,
    'acesso' => 1, 'gratuito' => 1, 'gratuita' => 1, 'inclusão' => 1,
    # Negativo (-1)
    'ruim' => -1, 'mal' => -1, 'pior' => -1, 'triste' => -1,
    'medo' => -1, 'raiva' => -1, 'problema' => -1, 'problemas' => -1,
    'crise' => -1, 'falha' => -1, 'injusto' => -1, 'injusta' => -1,
    'crime' => -1, 'insegurança' => -1, 'pobreza' => -1, 'desemprego' => -1,
    'caro' => -1, 'cara' => -1, 'abandono' => -1, 'descaso' => -1,
    'negligência' => -1, 'precário' => -1, 'precária' => -1,
    'falta' => -1, 'carência' => -1, 'difícil' => -1,
    # Muito negativo (-2)
    'péssimo' => -2, 'péssima' => -2, 'horrível' => -2, 'terrível' => -2,
    'ódio' => -2, 'fracasso' => -2, 'corrupção' => -2, 'desonesto' => -2,
    'desonesta' => -2, 'violência' => -2, 'mentira' => -2, 'fraude' => -2,
    'escândalo' => -2, 'roubo' => -2, 'assalto' => -2, 'tráfico' => -2,
    'corruptos' => -2, 'bandido' => -2, 'ladrão' => -2, 'ladra' => -2,
    'morte' => -2, 'assassinato' => -2, 'tragédia' => -2,
  }.freeze

  # ── Tópicos com palavras-chave ─────────────────────────────────────────────
  TOPICS = {
    'Saúde'      => %w[saúde hospital médico médica remédio medicamento doença tratamento sus vacina
                       enfermagem farmácia plano convenio emergência ubs upa cirurgia],
    'Educação'   => %w[educação escola professor professora aluno ensino universidade faculdade
                       bolsa estudante aula aprender vestibular enem diploma creche],
    'Segurança'  => %w[segurança crime violência policia polícia roubo assalto tráfico perigoso
                       medo bandido arma morte homicídio delegacia militar assassinato],
    'Economia'   => %w[economia emprego salário imposto inflação preço dinheiro renda trabalho
                       custo desemprego pix benefício auxílio recessão dívida crescimento],
    'Impostos'   => %w[imposto taxa tributação cobrar tributo fiscal reforma tributária ir irpf
                       isento alíquota declaração receita federal sonegação isenção],
    'Política'   => %w[política candidato partido eleição governo presidente senador deputado
                       voto urna congresso câmara senado reforma pec lei aprovação],
    'Transporte' => %w[transporte ônibus metrô trem trânsito estrada ponte combustível
                       gasolina uber táxi bicicleta ciclovias aeroporto rodovia],
    'Habitação'  => %w[habitação moradia casa aluguel construção minha habitacional programa
                       sem-teto favela loteamento terreno condomínio],
    'Meio Ambiente' => %w[ambiente clima desmatamento queimada poluição rio água chuva enchente
                          aquecimento carbono reciclagem sustentável ecologia floresta],
  }.freeze

  # ── Tokenização ────────────────────────────────────────────────────────────
  def self.tokenize(text)
    text.to_s.downcase
        .unicode_normalize(:nfc)
        .gsub(/[^a-záéíóúàâêôãõüç\s]/i, ' ')
        .split
  end

  # ── Score de sentimento de um texto ───────────────────────────────────────
  def self.score(text)
    tokenize(text).sum { |t| LEXICON[t] || 0 }
  end

  # ── Classificação ─────────────────────────────────────────────────────────
  def self.classify(score_val)
    if    score_val > 0 then :positive
    elsif score_val < 0 then :negative
    else                     :neutral
    end
  end

  # ── Distribuição de sentimento de um conjunto de textos ───────────────────
  # Retorna { positive: Float%, negative: Float%, neutral: Float%, total: Int }
  def self.distribution(messages)
    counts = { positive: 0, negative: 0, neutral: 0 }
    messages.each { |m| counts[classify(score(m))] += 1 }
    total = counts.values.sum.to_f
    return { positive: 0.0, negative: 0.0, neutral: 0.0, total: 0 } if total.zero?
    {
      positive: ((counts[:positive] / total) * 100).round(1),
      negative: ((counts[:negative] / total) * 100).round(1),
      neutral:  ((counts[:neutral]  / total) * 100).round(1),
      total:    total.to_i
    }
  end

  # ── Score médio (float) para um conjunto de textos ────────────────────────
  def self.avg_score(messages)
    return 0.0 if messages.empty?
    (messages.sum { |m| score(m) } / messages.size.to_f).round(2)
  end

  # ── Tópicos de um texto (pode ser mais de um) ─────────────────────────────
  def self.topics_of(text)
    low = text.to_s.downcase
    TOPICS.each_with_object([]) do |(topic, kws), found|
      found << topic if kws.any? { |kw| low.include?(kw) }
    end
  end
end
