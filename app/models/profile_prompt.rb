# Pergunta do perfil: a pessoa escolhe até MAX_PER_USER perguntas da lista pronta e
# escreve a resposta (Editar perfil). Aparece no perfil (users/_profile_prompts) e quem
# é Gold pode responder — a resposta chega como mensagem (PromptRepliesController).
class ProfilePrompt < ApplicationRecord
  MAX_PER_USER = 3
  ANSWER_MAX   = 150
  REPLY_MAX    = 300

  # %{city} vira a cidade de quem responde (sem cidade, a frase sem o lugar)
  QUESTIONS = {
    "perfect_date"    => "Um encontro perfeito em %{city} é…",
    "favorite_spot"   => "Meu lugar favorito em %{city} é…",
    "ideal_sunday"    => "Meu domingo ideal tem…",
    "wins_me_over"    => "Me conquista quem…",
    "simple_pleasure" => "Um pequeno prazer do meu dia é…",
    "on_repeat"       => "A música que não sai da minha playlist é…",
    "best_trip"       => "A viagem que mais me marcou foi…",
    "hot_take"        => "Uma opinião polêmica minha é…",
    "any_plan_but"    => "Topo qualquer rolê, menos…"
  }.freeze

  NO_CITY = {
    "perfect_date"  => "Um encontro perfeito é…",
    "favorite_spot" => "Meu lugar favorito na cidade é…"
  }.freeze

  belongs_to :user

  validates :question_key, inclusion: { in: QUESTIONS.keys }, uniqueness: { scope: :user_id }
  validates :answer, presence: true, length: { maximum: ANSWER_MAX }

  default_scope { order(:position, :id) }

  # Até a migration rodar no banco, o recurso fica escondido (como Message.chat_controls?)
  def self.available?
    table_exists? && Message.column_names.include?("prompt_key")
  rescue ActiveRecord::ActiveRecordError
    false
  end

  def self.question_text(key, city = nil)
    template = QUESTIONS[key.to_s]
    return nil unless template
    return NO_CITY.fetch(key.to_s, template) if template.include?("%{city}") && city.blank?

    format(template, city: city)
  end

  # Opções do select do Editar perfil, com a cidade de quem edita
  def self.options_for(user)
    QUESTIONS.keys.map { |key| [ question_text(key, user.city), key ] }
  end

  # Salva as perguntas vindas do Editar perfil: [{ key:, answer: }, …] — ignora vazias,
  # perguntas repetidas e o que passar do limite; troca todas de uma vez.
  def self.sync!(user, rows)
    clean = Array(rows).filter_map do |row|
      row = row.to_h.with_indifferent_access
      key = row[:key].to_s
      answer = row[:answer].to_s.squish
      next if QUESTIONS.exclude?(key) || answer.blank?

      { key: key, answer: answer.first(ANSWER_MAX) }
    end
    clean = clean.uniq { |row| row[:key] }.first(MAX_PER_USER)

    transaction do
      where(user_id: user.id).delete_all
      clean.each_with_index do |row, index|
        create!(user: user, question_key: row[:key], answer: row[:answer], position: index)
      end
    end
  end

  def question
    self.class.question_text(question_key, user&.city)
  end
end
