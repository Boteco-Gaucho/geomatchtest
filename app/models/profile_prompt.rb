# Pergunta do perfil: a pessoa escolhe até MAX_PER_USER perguntas da lista pronta e
# escreve a resposta (Editar perfil). Aparece no perfil (users/_profile_prompt) e quem
# é Gold pode responder — a resposta chega como mensagem (PromptRepliesController).
class ProfilePrompt < ApplicationRecord
  MAX_PER_USER = 3
  ANSWER_MAX   = 150
  REPLY_MAX    = 300

  # Lista do "Selecione uma pergunta" (Editar perfil), na ordem em que aparece. A chave fica
  # gravada no banco: não renomear chaves que já existem (as respostas salvas dependem delas).
  # %{city} vira a cidade de quem responde (sem cidade, a frase de NO_CITY).
  QUESTIONS = {
    "book_my_life"        => "Um livro que reflete a minha vida…",
    "villain_origin"      => "A história do começo da minha vilania…",
    "friends_say"         => "Meus amigos diriam que eu sou…",
    "first_date_vibe"     => "A vibe que quero trazer para o nosso primeiro encontro é…",
    "get_excited"         => "Eu me empolgo quando…",
    "trust_me"            => "Pode confiar em mim…",
    "very_happy_when"     => "Fico muito feliz quando…",
    "agree_disagree"      => "Você concorda ou discorda que…",
    "friend_group_role"   => "No meu grupo de amigos, eu sou a pessoa que…",
    "lets_debate"         => "Vamos debater…",
    "karaoke_song"        => "A minha música preferida no karaokê é…",
    "hot_take"            => "A minha opinião mais polêmica é…",
    "hyperfocus"          => "Meu hiperfoco atual é…",
    "siblings_tease"      => "Meus irmãos me zoam porque…",
    "not_vacation_unless" => "Não tô de férias se não…",
    "most_romantic"       => "A coisa mais romântica que alguém pode fazer pra mim é…",
    "sense_of_humor"      => "Meu senso de humor é basicamente…",
    "weird_same_way"      => "Somos esquisitos do mesmo jeito se você…",
    "surprising_fact"     => "Uma coisa surpreendente sobre mim é…",
    "cancel_plans_for"    => "Vou cancelar meus planos para…",
    "biggest_green_flag"  => "Na minha opinião, a maior green flag é…",
    "same_energy"         => "Tenho a mesma energia que…",
    "best_first_date_city" => "O melhor primeiro encontro dessa cidade…",
    "guilty_pleasure"     => "Meu prazer secreto é…",
    "butterfly_effect"    => "Meu momento efeito borboleta…",
    "on_a_night_out"      => "Em um rolê, sou eu que…",
    "friends_call_me_when" => "Sou a pessoa pra quem os amigos ligam quando…",
    "beat_you_at"         => "Posso ganhar de você em um jogo de…",
    "relive_first_time"   => "Uma primeira vez que eu reviveria…",
    "cant_go_a_day"       => "Não consigo passar um dia sem…",
    "should_know"         => "Você deve saber que eu…",
    "tell_you_about"      => "Quando a gente se encontrar, vou te contar sobre aquela vez em que eu…",
    "last_scary_thing"    => "A última coisa que fiz que me assustou…",
    "feel_at_home"        => "Onde eu vou para me sentir à vontade…",
    "ideal_weekend"       => "Meu fim de semana ideal inclui…",
    "chaotic_habit"       => "Meu hábito diário mais caótico é…",
    "want_to_learn"       => "Quero aprender mais sobre…",
    "perks_dating_me"     => "Vantagens de sair comigo…",
    # As primeiras do GeoMatch (continuam valendo para quem já respondeu)
    "perfect_date"        => "Um encontro perfeito em %{city} é…",
    "favorite_spot"       => "Meu lugar favorito em %{city} é…",
    "any_plan_but"        => "Topo qualquer rolê, menos…",
    "ideal_sunday"        => "Meu domingo ideal tem…",
    "wins_me_over"        => "Me conquista quem…",
    "simple_pleasure"     => "Um pequeno prazer do meu dia é…",
    "on_repeat"           => "A música que não sai da minha playlist é…",
    "best_trip"           => "A viagem que mais me marcou foi…"
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
