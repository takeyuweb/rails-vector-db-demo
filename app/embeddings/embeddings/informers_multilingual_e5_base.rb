# ADR A-2 で確定した EmbeddingModel の具体実装。
#
# Xenova/multilingual-e5-base（ONNX 配布版）を informers gem 経由で
# 同一プロセスで実行する。出力次元 768、L2 正規化済みベクトルを返す。
#
# REVISION（コミット SHA）の固定は ADR A-2 §決定 4 に従う。環境変数
# EMBEDDING_MODEL_REVISION で固定 SHA を指定する運用とし、固定が必要な
# 理由（HuggingFace 側のサイレントな差し替えへの対策）は README に記載。
module Embeddings
  class InformersMultilingualE5Base
    include EmbeddingModel

    REPOSITORY = "Xenova/multilingual-e5-base".freeze
    DIMENSIONS = 768
    PASSAGE_PREFIX = "passage: ".freeze
    QUERY_PREFIX = "query: ".freeze

    class << self
      def instance
        @instance ||= new
      end

      def revision
        ENV.fetch("EMBEDDING_MODEL_REVISION", "main")
      end
    end

    def embed_passage(text)
      embed(PASSAGE_PREFIX + text)
    end

    def embed_query(text)
      embed(QUERY_PREFIX + text)
    end

    def model_identifier
      "#{REPOSITORY}@#{self.class.revision}"
    end

    private

    def embed(prefixed_text)
      vector = pipeline.(prefixed_text, pooling: "mean", normalize: true)
      [ vector, model_identifier ]
    end

    def pipeline
      @pipeline ||= Informers.pipeline(
        "embedding",
        REPOSITORY,
        revision: self.class.revision
      )
    end
  end
end
