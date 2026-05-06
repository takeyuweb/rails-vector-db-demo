require "test_helper"

class ArticlesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @article = articles(:rails_intro)
  end

  test "should get index" do
    get articles_url
    assert_response :success
  end

  test "should get new" do
    get new_article_url
    assert_response :success
  end

  test "should create article" do
    assert_difference("Article.count") do
      post articles_url, params: { article: { title: "新規記事", body: "本文" } }
    end

    assert_redirected_to article_url(Article.last)
  end

  test "should not create article without title" do
    assert_no_difference("Article.count") do
      post articles_url, params: { article: { title: "", body: "本文" } }
    end
  end

  test "should show article" do
    get article_url(@article)
    assert_response :success
  end

  test "should get edit" do
    get edit_article_url(@article)
    assert_response :success
  end

  test "should update article" do
    patch article_url(@article), params: { article: { body: @article.body, title: "更新後タイトル" } }
    assert_redirected_to article_url(@article)
  end

  test "should destroy article" do
    assert_difference("Article.count", -1) do
      delete article_url(@article)
    end

    assert_redirected_to articles_url
  end

  test "similar action shows 準備中 when embedding not generated" do
    get similar_article_url(@article)
    assert_response :success
    assert_select "p", text: /準備中/
  end

  test "similar action returns related articles when embedding exists" do
    other = articles(:ruby_blocks)
    ArticleEmbedding.create!(
      article: @article,
      embedding: Array.new(768) { 0.0 }.tap { |a| a[0] = 1.0 },
      model_identifier: "test/fake@v1"
    )
    fake_search = Object.new
    fake_search.define_singleton_method(:search) do |query_vector:, k:, exclude_article_ids: []|
      [ other ]
    end
    original = Rails.application.config.vector_search
    Rails.application.config.vector_search = fake_search
    begin
      get similar_article_url(@article)
      assert_response :success
      assert_select "ul li a", text: other.title
    ensure
      Rails.application.config.vector_search = original
    end
  end
end
