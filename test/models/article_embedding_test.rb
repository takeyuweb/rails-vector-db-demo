require "test_helper"

class ArticleEmbeddingTest < ActiveSupport::TestCase
  setup do
    @article = articles(:rails_intro)
    @vector = Array.new(768) { 0.0 }
  end

  test "valid with all required fields" do
    embedding = ArticleEmbedding.new(
      article: @article,
      embedding: @vector,
      model_identifier: "Xenova/multilingual-e5-base@dummy-sha"
    )
    assert embedding.valid?
  end

  test "invalid without article" do
    embedding = ArticleEmbedding.new(
      embedding: @vector,
      model_identifier: "Xenova/multilingual-e5-base@dummy-sha"
    )
    assert_not embedding.valid?
  end

  test "invalid without model_identifier" do
    embedding = ArticleEmbedding.new(
      article: @article,
      embedding: @vector
    )
    assert_not embedding.valid?
  end

  test "destroyed when article is destroyed" do
    embedding = ArticleEmbedding.create!(
      article: @article,
      embedding: @vector,
      model_identifier: "Xenova/multilingual-e5-base@dummy-sha"
    )
    @article.destroy
    assert_not ArticleEmbedding.exists?(embedding.id)
  end
end
