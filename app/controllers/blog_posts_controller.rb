class BlogPostsController < ApplicationController
  skip_before_action :require_onboarding!, only: [:index, :show]

  def index
    @category = params[:category].present? ? BlogCategory.find_by(slug: params[:category]) : nil
    @blog_posts = BlogPost.published

    @blog_posts = @blog_posts.by_category(params[:category]) if params[:category].present?

    @seo_tags = {
      title: @category ? "#{@category.name} — Blog GeoMatch" : "Blog — GeoMatch",
      description: @category ? @category.description : "Dicas, novidades e artigos sobre conexões reais, segurança e relacionamentos. Leia o blog do GeoMatch.",
      url: request.url,
      og_title: @category ? "#{@category.name} — Blog" : "Blog GeoMatch",
      og_description: @category ? @category.description : "Blog do GeoMatch",
      og_type: "website",
      tw_card: "summary",
      tw_title: @category ? "#{@category.name} — Blog" : "Blog GeoMatch",
      tw_description: @category ? @category.description : "Blog do GeoMatch"
    }
  end

  def show
    @blog_post = BlogPost.published.find_by(slug: params[:slug])
    return render_not_found if @blog_post.blank?

    @seo_tags = {
      title: @blog_post.title,
      description: @blog_post.excerpt.present? ? @blog_post.excerpt : truncate(@blog_post.content, length: 160),
      image: @blog_post.featured_image.present? ? image_url(@blog_post.featured_image) : nil,
      url: blog_post_url(@blog_post),
      og_title: @blog_post.title,
      og_description: @blog_post.excerpt.present? ? @blog_post.excerpt : truncate(@blog_post.content, length: 160),
      og_image: @blog_post.featured_image.present? ? image_url(@blog_post.featured_image) : nil,
      og_type: "article",
      tw_card: "summary_large_image",
      tw_title: @blog_post.title,
      tw_description: @blog_post.excerpt.present? ? @blog_post.excerpt : truncate(@blog_post.content, length: 160),
      tw_image: @blog_post.featured_image.present? ? image_url(@blog_post.featured_image) : nil
    }
  end

  private

  def render_not_found
    render file: Rails.root.join("public/404.html"), status: :not_found, layout: false
  end
end
