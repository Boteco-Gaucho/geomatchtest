# frozen_string_literal: true

class AddSaasFieldsToPlans < ActiveRecord::Migration[7.2]
  def change
    # Adicionar campos para gestão SaaS (apenas se não existirem)
    add_column :plans, :duration_months, :integer, default: 1, null: false unless column_exists?(:plans, :duration_months)
    add_column :plans, :max_likes_per_day, :integer, default: 50, null: false unless column_exists?(:plans, :max_likes_per_day)
    add_column :plans, :has_boost, :boolean, default: false, null: false unless column_exists?(:plans, :has_boost)
    add_column :plans, :has_incognito, :boolean, default: false, null: false unless column_exists?(:plans, :has_incognito)
    add_column :plans, :active, :boolean, default: true, null: false unless column_exists?(:plans, :active)
    add_column :plans, :description, :text unless column_exists?(:plans, :description)

    # Índice para filtrar apenas planos ativos (apenas se não existir)
    add_index :plans, :active unless index_exists?(:plans, :active)
  end
end

