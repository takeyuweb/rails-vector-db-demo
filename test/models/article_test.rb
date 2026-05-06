require "test_helper"

class ArticleTest < ActiveSupport::TestCase
  test "valid with title and body" do
    article = Article.new(title: "Rails 入門", body: "Rails の基本を学ぶ")
    assert article.valid?
  end

  test "invalid without title" do
    article = Article.new(body: "本文のみ")
    assert_not article.valid?
    assert_includes article.errors[:title], "can't be blank"
  end

  test "invalid without body" do
    article = Article.new(title: "タイトルのみ")
    assert_not article.valid?
    assert_includes article.errors[:body], "can't be blank"
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
