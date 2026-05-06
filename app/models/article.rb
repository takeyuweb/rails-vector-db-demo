class Article < ApplicationRecord
  has_one :article_embedding, dependent: :destroy

  validates :title, presence: true
  validates :body, presence: true
end
