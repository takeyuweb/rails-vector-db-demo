# 機能設計書 §7「自動更新（埋め込みベクトル生成）機能」に基づく実装。
#
# Article の after_commit からエンキューされ、対象記事の埋め込みベクトルを
# 非同期に生成・保存する。失敗時は ActiveJob の retry_on により再試行する
# （要件定義書 §2.3）。
class ArticleEmbeddingJob < ApplicationJob
  queue_as :default

  # ジョブ失敗時のリトライ方針（要件定義書 §2.3 / 機能設計書 §7.4）。
  # 一時的なネットワーク・I/O 失敗を想定し、3回まで指数バックオフで再試行する。
  # 最終失敗時は当該記事の埋め込みベクトルが未生成のまま残り、検索結果から
  # 自然に除外される（機能設計書 §4.2.3）。
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(article_id)
    article = Article.find_by(id: article_id)
    # 機能設計書 §7.3 ステップ 2: 既に削除されている記事は何もせず終了
    return if article.nil?

    text = "#{article.title}\n#{article.body}"
    vector, model_identifier = Rails.application.config.embedding_model.embed_passage(text)

    # 機能設計書 §7.5: 同一 article_id への並行実行は upsert で最終勝者を採用
    embedding = ArticleEmbedding.find_or_initialize_by(article_id: article.id)
    embedding.update!(embedding: vector, model_identifier: model_identifier)
  end
end
