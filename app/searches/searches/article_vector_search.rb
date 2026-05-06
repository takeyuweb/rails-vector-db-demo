# ADR A-3（pgvector）/ A-4（neighbor）/ A-5（コサイン類似度）で確定した
# 構成の VectorSearch 具体実装。
#
# ArticleEmbedding.nearest_neighbors を経由してコサイン類似度で並べ替えた
# 上位 K 件を返す。除外対象が指定された場合は WHERE NOT IN で除外する
# （機能設計書 §4.3.2 の自記事除外）。
#
# ANN（HNSW）インデックスは ADR A-3 §決定に従い初期実装では未作成のため、
# 内部的には pgvector の線形走査で動作する。HNSW 追加は Zenn 記事の別章で
# 解説する。
module Searches
  class ArticleVectorSearch
    include VectorSearch

    def search(query_vector:, k:, exclude_article_ids: [])
      scope = ArticleEmbedding
        .nearest_neighbors(:embedding, query_vector, distance: "cosine")
        .includes(:article)
        .limit(k)

      scope = scope.where.not(article_id: exclude_article_ids) if exclude_article_ids.any?

      scope.map(&:article)
    end
  end
end
