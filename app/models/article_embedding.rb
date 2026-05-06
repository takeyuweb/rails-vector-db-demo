class ArticleEmbedding < ApplicationRecord
  # ADR A-5 §実装方針 2: E5 出力は L2 正規化済みのため neighbor 側での
  # 再正規化は不要。dimensions は ADR A-2 で確定した 768 に揃える。
  has_neighbors :embedding, dimensions: 768, normalize: false

  belongs_to :article

  validates :embedding, presence: true
  validates :model_identifier, presence: true
end
