require "test_helper"

class SearchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @fake_model = Object.new
    @fake_model.define_singleton_method(:embed_query) do |_text|
      [ Array.new(768) { 0.1 }, "test/fake@v1" ]
    end
    @fake_search = Object.new
    @fake_search.define_singleton_method(:search) do |query_vector:, k:, exclude_article_ids: []|
      []
    end

    @original_model = Rails.application.config.embedding_model
    @original_search = Rails.application.config.vector_search
    Rails.application.config.embedding_model = @fake_model
    Rails.application.config.vector_search = @fake_search
  end

  teardown do
    Rails.application.config.embedding_model = @original_model
    Rails.application.config.vector_search = @original_search
  end

  test "shows form when no query" do
    get search_path
    assert_response :success
    assert_select "form input[type=search]"
  end

  test "shows hint when query is blank" do
    get search_path, params: { q: "" }
    assert_response :success
    assert_select "p", text: /クエリ文を入力してください/
  end

  test "shows no results message when results empty" do
    get search_path, params: { q: "Rails" }
    assert_response :success
    assert_select "p", text: /該当する記事がありません/
  end

  test "renders results list when matches exist" do
    article = articles(:rails_intro)
    @fake_search.define_singleton_method(:search) do |query_vector:, k:, exclude_article_ids: []|
      [ article ]
    end
    get search_path, params: { q: "Rails" }
    assert_response :success
    assert_select "ul li a", text: article.title
  end
end
