require "test_helper"

class ArticleTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "valid with title and body" do
    article = Article.new(title: "Rails 入門", body: "Rails の基本を学ぶ")
    assert article.valid?
  end

  test "enqueues ArticleEmbeddingJob after create" do
    assert_enqueued_with(job: ArticleEmbeddingJob) do
      Article.create!(title: "新規記事", body: "本文")
    end
  end

  test "enqueues ArticleEmbeddingJob after update" do
    article = articles(:rails_intro)
    assert_enqueued_with(job: ArticleEmbeddingJob, args: [ article.id ]) do
      article.update!(title: "更新後タイトル")
    end
  end

  test "invalid without title" do
    article = Article.new(body: "本文のみ")
    assert_not article.valid?
    assert article.errors[:title].any?
  end

  test "invalid without body" do
    article = Article.new(title: "タイトルのみ")
    assert_not article.valid?
    assert article.errors[:body].any?
  end

  test "invalid with empty title" do
    article = Article.new(title: "", body: "本文")
    assert_not article.valid?
  end

  test "invalid with empty body" do
    article = Article.new(title: "タイトル", body: "")
    assert_not article.valid?
  end
end
