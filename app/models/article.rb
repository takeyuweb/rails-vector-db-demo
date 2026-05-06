class Article < ApplicationRecord
  has_one :article_embedding, dependent: :destroy

  validates :title, presence: true
  validates :body, presence: true

  # 機能設計書 §1.3.1 / §6.1: 作成・更新コミット直後に埋め込み生成を非同期で起動。
  # 削除時は has_one ... dependent: :destroy + DB 側 ON DELETE CASCADE で
  # 自動削除されるため、destroy 用のフックは設けない（機能設計書 §4.2.2）。
  after_commit :enqueue_embedding_job, on: %i[ create update ]

  private

  def enqueue_embedding_job
    ArticleEmbeddingJob.perform_later(id)
  end
end
