class ArticlesController < ApplicationController
  before_action :set_article, only: %i[ show edit update destroy ]

  # GET /articles
  def index
    @articles = Article.order(created_at: :desc)
  end

  # GET /articles/1
  def show
  end

  # GET /articles/new
  def new
    @article = Article.new
  end

  # GET /articles/1/edit
  def edit
  end

  # POST /articles
  def create
    @article = Article.new(article_params)

    if @article.save
      redirect_to @article, notice: "記事を作成しました。"
    else
      render :new, status: :unprocessable_content
    end
  end

  # PATCH/PUT /articles/1
  def update
    if @article.update(article_params)
      redirect_to @article, notice: "記事を更新しました。", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /articles/1
  def destroy
    @article.destroy!
    redirect_to articles_path, notice: "記事を削除しました。", status: :see_other
  end

  private
    def set_article
      @article = Article.find(params.expect(:id))
    end

    def article_params
      params.expect(article: [ :title, :body ])
    end
end
