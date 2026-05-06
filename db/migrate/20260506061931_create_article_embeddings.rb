class CreateArticleEmbeddings < ActiveRecord::Migration[8.1]
  def change
    create_table :article_embeddings do |t|
      t.references :article,
                   null: false,
                   foreign_key: { on_delete: :cascade },
                   index: { unique: true }
      t.vector :embedding, limit: 768, null: false
      t.string :model_identifier, null: false

      t.timestamps
    end
  end
end
