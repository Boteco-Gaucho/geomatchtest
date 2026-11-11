class PagesController < ApplicationController

  def landing
    redirect_to discover_3d_path if user_signed_in?
    @hide_layout_footer = true
  end

  def terms
  end

  def privacy
  end

  def suporte
  end

  # Guia de instalação do app iOS via TestFlight (beta)
  def testflight_guide
    @hide_layout_footer = true
    @seo_tags[:title]       = "Como instalar o GeoMatch no iPhone — TestFlight"
    @seo_tags[:description] = "Passo a passo para instalar a versão beta do GeoMatch no iPhone usando o TestFlight, o app oficial de betas da Apple."
  end
end