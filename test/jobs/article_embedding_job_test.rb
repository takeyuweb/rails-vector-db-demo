require "test_helper"

class ArticleEmbeddingJobTest < ActiveJob::TestCase
  setup do
    @article = articles(:rails_intro)
    @vector = Array.new(768) { 0.0 }
    @model_identifier = "test/fake@v1"
    @fake_model = Object.new
    @fake_model.define_singleton_method(:embed_passage) do |_text|
      [ Array.new(768) { 0.0 }, "test/fake@v1" ]
    end
    @original_model = Rails.application.config.embedding_model
    Rails.application.config.embedding_model = @fake_model
  end

  teardown do
    Rails.application.config.embedding_model = @original_model
  end

  test "creates ArticleEmbedding when none exists" do
    assert_difference("ArticleEmbedding.count", 1) do
      ArticleEmbeddingJob.perform_now(@article.id)
    end
    embedding = @article.reload.article_embedding
    assert_equal @model_identifier, embedding.model_identifier
  end

  test "updates existing ArticleEmbedding" do
    existing = ArticleEmbedding.create!(
      article: @article,
      embedding: Array.new(768) { 1.0 },
      model_identifier: "old/model@v0"
    )
    assert_no_difference("ArticleEmbedding.count") do
      ArticleEmbeddingJob.perform_now(@article.id)
    end
    existing.reload
    assert_equal @model_identifier, existing.model_identifier
  end

  test "does nothing when article is already deleted" do
    deleted_id = @article.id
    @article.destroy
    assert_nothing_raised do
      ArticleEmbeddingJob.perform_now(deleted_id)
    end
    assert_equal 0, ArticleEmbedding.where(article_id: deleted_id).count
  end
end
