# 機能設計書 §6.2.1 で定義される抽象インターフェース。
#
# テキストを受け取り、埋め込みベクトルとモデル識別子を返す責務を持つ。
# 具体実装は ADR A-2 で確定（Embeddings::InformersMultilingualE5Base）。
#
# ADR A-2 §実装方針 3 に従い、検索対象テキストとクエリ文では
# プレフィックス付与の規約が異なるため、メソッドを2つに分ける。
# 呼び出し側はプレフィックスを意識しない。
module EmbeddingModel
  # 検索対象テキスト（記事）の埋め込みベクトル化
  #
  # @param text [String] 結合済みテキスト（タイトル + 改行 + 本文）
  # @return [Array(Array<Float>, String)] [埋め込みベクトル, モデル識別子]
  def embed_passage(text)
    raise NotImplementedError
  end

  # クエリ文の埋め込みベクトル化
  #
  # @param text [String] 利用者が入力したクエリ文
  # @return [Array(Array<Float>, String)] [埋め込みベクトル, モデル識別子]
  def embed_query(text)
    raise NotImplementedError
  end
end
