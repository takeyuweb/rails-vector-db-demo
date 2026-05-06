class ArticlesController < ApplicationController
  SIMILAR_TOP_K = 5

  before_action :set_article, only: %i[ show edit update destroy similar ]

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

  # GET /articles/1/similar
  # 機能設計書 §1.3.3 / §5.1.4 / §5.2: Turbo Frame で類似記事セクションを
  # 遅延ロードする。当該記事の埋め込みベクトルが未生成の場合は「準備中」を返す。
  def similar
    embedding = @article.article_embedding
    if embedding.nil?
      @embedding_ready = false
      @similar_articles = []
    else
      @embedding_ready = true
      @similar_articles = Rails.application.config.vector_search.search(
        query_vector: embedding.embedding,
        k: SIMILAR_TOP_K,
        exclude_article_ids: [ @article.id ]
      )
    end
  end

  private
    def set_article
      @article = Article.find(params.expect(:id))
    end

    def article_params
      params.expect(article: [ :title, :body ])
    end
end
