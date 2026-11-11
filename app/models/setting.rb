class Setting < ApplicationRecord
  validates :key,   presence: true, uniqueness: true
  validates :value, presence: true, numericality: { greater_than: 0 }

  # Preço em centavos da mensagem avulsa (ex: 199 = R$ 1,99)
  def self.one_off_message_price
    find_by(key: 'one_off_message_price')&.value&.to_i || 199
  end

  # Formata o valor em reais para exibição (ex: "R$ 1,99")
  def self.one_off_message_price_formatted
    cents = one_off_message_price
    "R$ #{format('%.2f', cents / 100.0).tr('.', ',')}"
  end

  # Leitura genérica com fallback
  def self.get(key, default = nil)
    find_by(key: key)&.value || default
  end

  # Escrita genérica (upsert)
  def self.set(key, value)
    find_or_initialize_by(key: key).tap do |s|
      s.value = value
      s.save!
    end
  end
end
