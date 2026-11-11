xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.urlset xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9" do
  # Páginas estáticas
  @static_pages.each do |page|
    xml.url do
      xml.loc "https://geomatchbr.com#{page[:url]}"
      xml.lastmod Time.zone.now.strftime("%Y-%m-%d")
      xml.changefreq page[:changefreq]
      xml.priority page[:priority]
    end
  end

  # Posts do blog
  @blog_posts.each do |post|
    xml.url do
      xml.loc blog_post_url(post)
      xml.lastmod post.updated_at.strftime("%Y-%m-%d")
      xml.changefreq "monthly"
      xml.priority 0.8
    end
  end

  # Categorias do blog
  @blog_categories.each do |category|
    xml.url do
      xml.loc blog_category_url(category.slug)
      xml.lastmod category.updated_at.strftime("%Y-%m-%d")
      xml.changefreq "monthly"
      xml.priority 0.7
    end
  end
end
