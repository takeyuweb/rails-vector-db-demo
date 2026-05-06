# 機能設計書 §6.2.2 で定義される抽象インターフェース。
#
# 比較元ベクトルから上位 K 件の類似記事を返す責務を持つ。具体実装は
# ADR A-3（pgvector）と ADR A-4（neighbor gem）の決定に従い、
# Searches::ArticleVectorSearch が担当する。
#
# 出力には類似度スコアを含めない（機能設計書 §3.3）。除外対象が指定された
# 場合は結果から除外する（§4.3.2 の自記事除外用途）。
module VectorSearch
  # @param query_vector [Array<Float>] 比較元の埋め込みベクトル（L2正規化済み）
  # @param k [Integer] 取得する記事数の上限
  # @param exclude_article_ids [Array<Integer>] 結果から除外する記事ID
  # @return [Array<Article>] 類似度順に並んだ記事配列（最大 K 件）
  def search(query_vector:, k:, exclude_article_ids: [])
    raise NotImplementedError
  end
end
