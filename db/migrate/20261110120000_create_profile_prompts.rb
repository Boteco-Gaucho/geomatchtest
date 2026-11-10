# Perguntas do perfil ("Um encontro perfeito em Salvador é…"): cada pessoa escolhe até 3
# de uma lista pronta (ProfilePrompt::QUESTIONS) e escreve a resposta. Quem é Gold pode
# responder a pergunta de alguém — a resposta vira mensagem, citando a pergunta (colunas
# prompt_* em messages, com uma cópia do texto: editar a pergunta depois não muda a conversa).
class CreateProfilePrompts < ActiveRecord::Migration[8.1]
  def change
    create_table :profile_prompts do |t|
      t.references :user, null: false, foreign_key: true
      t.string  :question_key, null: false
      t.string  :answer,       null: false
      t.integer :position,     null: false, default: 0
      t.timestamps
    end
    add_index :profile_prompts, [ :user_id, :question_key ], unique: true

    add_column :messages, :prompt_key,      :string
    add_column :messages, :prompt_question, :string
    add_column :messages, :prompt_answer,   :text
    add_index  :messages, [ :sender_id, :prompt_key ], where: "prompt_key IS NOT NULL"
  end
end
