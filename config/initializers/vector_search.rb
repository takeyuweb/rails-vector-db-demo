# VectorSearch の DI 配線（ADR A-4 §決定 2）。
#
# Rails.application.config.vector_search でアプリケーション全体から
# 同一の検索実装を参照できるようにする。テスト時はこの値を差し替える。
#
# 現在の具体実装は ADR A-3 / A-4 / A-5 で確定（Searches::ArticleVectorSearch）。

Rails.application.config.to_prepare do
  Rails.application.config.vector_search = Searches::ArticleVectorSearch.new
end
