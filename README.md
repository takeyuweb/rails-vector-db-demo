# Rails Vector Search Demo

Rails アプリケーションにブログ記事の類似検索機能をベクター検索で統合する方法を解説するための、動作するリファレンス実装です。Zenn 技術記事の題材として、読者がリポジトリをクローンして手元で同じ環境を再構築できることを最優先に設計しています。

## 採用技術

| 領域 | 採用技術 | 出所 |
|------|---------|------|
| Web フレームワーク | Rails 8.1.3 | ADR A-1 |
| Ruby | 3.4.9 | ADR A-1 |
| ベクターDB | pgvector（PostgreSQL 17 系） | ADR A-3 |
| Rails 統合 gem | neighbor (~> 1.0) | ADR A-4 |
| 埋め込みモデル | Xenova/multilingual-e5-base（768次元） | ADR A-2 |
| 埋め込み実行基盤 | informers (~> 1.3) gem（同一プロセス） | ADR A-2 |
| 類似度指標 | コサイン類似度 | ADR A-5 |
| 非同期ジョブ | ActiveJob + Solid Queue | Rails 8 標準 |
| フロントエンド | Hotwire（Turbo + Stimulus） | Rails 8 標準 |

詳細な設計判断は `docs/adr/` の各 ADR と `docs/functional-design/functional-design.md` を参照してください。

## 前提

- Docker Desktop（または Docker Engine + Docker Compose v2）
- 起動時にインターネット接続（初回起動時に embedding モデル ONNX を HuggingFace Hub から取得）

ローカルに Ruby / PostgreSQL を直接インストールする必要はありません。すべて Docker Compose で完結します。

## セットアップ

### 1. リポジトリをクローン

```sh
git clone <repository-url>
cd rails-vector-db-demo
```

### 2. （任意）モデルリビジョンを固定

ADR A-2 §決定 4 に従い、HuggingFace Hub 上の埋め込みモデルのコミット SHA を固定することで、Hub 側のサイレントな差し替えを防げます。固定する場合は環境変数 `EMBEDDING_MODEL_REVISION` を設定してください。

```sh
export EMBEDDING_MODEL_REVISION=<commit-sha>
```

未設定の場合は `main` ブランチが使用されます。デモ用途であれば未設定のまま進めて構いません。

### 3. コンテナをビルド・起動

```sh
docker compose build
docker compose up -d db
```

### 4. データベースを初期化

```sh
docker compose run --rm web bin/rails db:prepare
docker compose run --rm web bin/rails db:seed
```

`db:prepare` は db:create / db:migrate / db:seed を必要なものだけ実行します。
`db:seed` は 6 テーマ × 4 件 = 24 件のブログ記事を投入し、`Article#after_commit` から `ArticleEmbeddingJob` をエンキューします。

### 5. アプリケーションとジョブワーカーを起動

```sh
docker compose up web jobs
```

- `web`: <http://localhost:3000>
- `jobs`: バックグラウンドで `ArticleEmbeddingJob` を処理し、24 件の埋め込みベクトルを順次生成します

初回起動時、`jobs` プロセスが最初の埋め込み生成を行うタイミングで `Xenova/multilingual-e5-base` の ONNX モデル（約 270MB）を HuggingFace Hub から取得します。所要時間は回線速度に依存しますが、ダウンロード後は名前付きボリューム `informers_cache` にキャッシュされ、以降の起動では再ダウンロードしません。

すべての埋め込みが生成されると、検索画面（<http://localhost:3000/search>）と記事詳細の「類似記事」セクションが機能します。

## 使い方

- 記事の閲覧・作成・編集・削除: <http://localhost:3000/articles>
- 類似記事検索: <http://localhost:3000/search>
- 記事詳細画面の下部に当該記事の類似記事 5 件が表示されます

## テストの実行

```sh
docker compose run --rm web bin/rails test
```

## ディレクトリ構造の要点

- `app/models/article.rb` … 記事モデル。`after_commit` で埋め込み生成ジョブをエンキュー
- `app/models/article_embedding.rb` … 埋め込みベクトルモデル。`has_neighbors :embedding`
- `app/jobs/article_embedding_job.rb` … 非同期埋め込み生成。`retry_on` で一時的失敗を吸収
- `app/embeddings/embedding_model.rb` … 抽象インターフェース（機能設計書 §6.2.1）
- `app/embeddings/embeddings/informers_multilingual_e5_base.rb` … informers + e5-base 実装（ADR A-2）
- `app/searches/vector_search.rb` … 抽象インターフェース（機能設計書 §6.2.2）
- `app/searches/searches/article_vector_search.rb` … neighbor + pgvector 実装（ADR A-3 / A-4 / A-5）
- `app/controllers/articles_controller.rb` … 記事 CRUD と類似記事 Turbo Frame
- `app/controllers/searches_controller.rb` … クエリ文ベースの類似検索
- `db/migrate/*_enable_vector_extension.rb` … pgvector 拡張の有効化
- `db/seeds.rb` … 6 テーマ × 4 件の seed データ

## 関連ドキュメント

- 要件定義書: `docs/requirements/requirements.md`
- 機能設計書: `docs/functional-design/functional-design.md`
- ADR 一覧: `docs/adr/`
- 用語集: `docs/glossary/glossary.md`
- 調査報告書: `docs/reports/`

## ライセンス

未設定。OSS 公開時に追記してください。
