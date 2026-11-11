class Block < ApplicationRecord
  # Aqui usamos class_name: 'User' para ensinar ao Rails que essas colunas
  # apontam para a tabela de usuários, e não para tabelas "Blockers" ou "Blockeds".
  
  belongs_to :blocker, class_name: 'User'
  belongs_to :blocked, class_name: 'User'

  # Validações opcionais para garantir integridade
  validates :blocker_id, presence: true
  validates :blocked_id, presence: true
  # Garante que não exista bloqueio duplicado
  validates :blocker_id, uniqueness: { scope: :blocked_id, message: "já bloqueou este usuário" }
end