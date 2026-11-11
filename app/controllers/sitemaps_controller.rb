class SitemapsController < ApplicationController
  skip_before_action :require_onboarding!

  def index
    @static_pages = [
      { url: root_path, priority: 1.0, changefreq: "weekly" },
      { url: blog_path, priority: 0.9, changefreq: "daily" },
      { url: plans_path, priority: 0.8, changefreq: "monthly" },
      { url: safety_center_path, priority: 0.7, changefreq: "monthly" }
    ]

    @blog_posts = BlogPost.published.select(:slug, :updated_at)
    @blog_categories = BlogCategory.all.select(:slug, :updated_at)

    respond_to do |format|
      format.xml
    end
  end
end
