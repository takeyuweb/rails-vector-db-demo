class AddHnswToArticleEmbeddings < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :article_embeddings, :embedding,
              using: :hnsw,
              opclass: :vector_cosine_ops,
              algorithm: :concurrently
  end
end
