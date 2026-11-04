module FavoritesHelper
  # Fundo do card de quem ainda não tem foto (fica sempre a mesma cor para a pessoa)
  FAVORITE_PLACEHOLDER_COLORS = %w[#7c585b #a69580 #6d7466 #5f6878 #8a6c52 #76607a].freeze

  # "Nenhum perfil salvo" / "1 perfil salvo" / "2 perfis salvos"
  def favorites_count_label(count)
    case count
    when 0 then "Nenhum perfil salvo"
    when 1 then "1 perfil salvo"
    else "#{count} perfis salvos"
    end
  end

  def favorite_placeholder_color(user)
    FAVORITE_PLACEHOLDER_COLORS[user.id.to_i % FAVORITE_PLACEHOLDER_COLORS.size]
  end
end
