class Admin::BlogPostsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin!
  before_action :set_blog_post, only: [:edit, :update, :destroy]

  def index
    @blog_posts = BlogPost.order(published_at: :desc).page(params[:page]).per(10)
  end

  def new
    @blog_post = BlogPost.new
    @categories = BlogCategory.all
  end

  def create
    @blog_post = current_user.blog_posts.build(blog_post_params)

    if @blog_post.save
      redirect_to admin_blog_posts_path, notice: "Post criado com sucesso!"
    else
      @categories = BlogCategory.all
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @categories = BlogCategory.all
  end

  def update
    if @blog_post.update(blog_post_params)
      redirect_to admin_blog_posts_path, notice: "Post atualizado com sucesso!"
    else
      @categories = BlogCategory.all
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @blog_post.destroy
    redirect_to admin_blog_posts_path, notice: "Post deletado com sucesso!"
  end

  private

  def set_blog_post
    @blog_post = BlogPost.find_by(slug: params[:id]) || BlogPost.find(params[:id])
  end

  def authorize_admin!
    redirect_to root_path, alert: "Acesso negado" unless current_user.admin?
  end

  def blog_post_params
    params.require(:blog_post).permit(:title, :slug, :excerpt, :content, :featured_image, :blog_category_id, :published_at)
  end
end
