# EmbeddingModel の DI 配線（ADR A-4 §決定 2）。
#
# Rails.application.config.embedding_model でアプリケーション全体から
# 同一の埋め込みモデル実装を参照できるようにする。テスト時はこの値を
# 差し替えてモデルロードを回避する。
#
# 現在の具体実装は ADR A-2 で確定（Embeddings::InformersMultilingualE5Base）。
# autoload された定数を参照するため、to_prepare ブロックで遅延配線する。

Rails.application.config.to_prepare do
  Rails.application.config.embedding_model =
    Embeddings::InformersMultilingualE5Base.instance
end
