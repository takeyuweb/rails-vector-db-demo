# ADR A-4: Rails 統合方式（gem）の選定

## ステータス

提案中

## 日付

2026-05-06

## 信頼度

高

調査報告書 R-C にて、本デモが採用可能な選択肢（neighbor / pgvector gem 単独 / qdrant-ruby / weaviate-ruby / 直接 SQL）を一次ソース（GitHub README、CHANGELOG、RubyGems）から比較済みである。pgvector を採用する前提（A-3）と組み合わせると、Rails 統合 gem は事実上 `neighbor` で確定する（pgvector gem の README 自身が Rails 用途では neighbor を案内している[^6]）。バージョン要件の整合も A-1 の前提（Rails 最新安定版＝ Rails 8.x、Ruby 3.3+）と一致している。

## 再評価条件

以下の状況が発生した場合、本決定を再評価する。

- ベクターDB の選定（A-3）が pgvector 以外（Qdrant / Weaviate 等）に変更された場合 → neighbor は当該バックエンドを公式サポートしないため[^3]、qdrant-ruby / weaviate-ruby など別 gem への切り替えが必要
- A-1 で採用する Rails / Ruby バージョンが Rails < 7.2 もしくは Ruby < 3.3 に変更された場合 → neighbor 1.0.0 はこれらを最低要件として要求する[^1][^2]ため、neighbor 0.6.x 系へのダウングレードまたは別案検討が必要
- neighbor の保守が停止した場合（最終リリースから 1 年以上更新がない、リポジトリがアーカイブされた等）
- 本デモの記事スコープが拡大し、専用ベクターDB クライアント（Qdrant 等）の解説が主題になる場合

## コンテキスト

### 背景

機能設計書 §6.2 では `EmbeddingModel` と `VectorSearch` という 2 つの抽象インターフェースを定義し、コントローラ・ジョブ・ビュー層が具体実装に依存しない構造を採用している。`VectorSearch` の具体実装は ADR A-3 で採用が決定された pgvector に対して、Rails（ActiveRecord）から SQL クエリを発行する。このとき、

- 埋め込みベクトル値の Ruby ⇔ pgvector `vector` 型の相互変換
- 距離演算子（`<->`、`<=>`、`<#>`）の選択
- ANN インデックス（HNSW / IVFFlat）作成のマイグレーション DSL

を都度自前で扱うか、それらを抽象化した gem を介するかを選択する必要がある。

### 現状の問題点

- 抽象インターフェース `VectorSearch` の具体実装方式が未確定であり、実装着手の前に gem 選定を確定させる必要がある
- pgvector の値変換・距離演算子・ANN インデックス DSL を素の ActiveRecord で扱うとボイラープレートが各画面の実装に分散し、記事執筆時の解説対象が膨らむ
- gem 候補が複数あり（neighbor / pgvector gem 単独 / 直接 SQL）、技術記事の読者に説明する際の選定根拠を明示する必要がある

### 制約条件

- **完全ローカル動作必須**: 外部 API への通信を行わず、Docker Compose 内のみで動作すること（要件定義書 §3.2、機能設計書 §6.3）
- **Rails 最新安定版（Rails 8.x）採用**: ADR A-1 で決定。本 ADR 時点では Rails 8.x を前提とする
- **Ruby 3.3+**: A-1 で決定（Rails 8.x の前提）
- **pgvector を採用済み**: ADR A-3 で決定
- **記事執筆との整合性**: 本デモは Zenn 技術記事の題材であり、Rails 開発者が「自分のアプリにベクター検索を組み込む」際の参考になるコード量・規約適合性が望ましい
- **抽象化レイヤー（`EmbeddingModel` / `VectorSearch`）を破壊しないこと**: gem の具体 API はアプリケーション層の実装クラス内部に閉じ込め、コントローラ・ジョブ・ビューから直接参照させない

## 決定

以下を決定する。

1. **Rails ⇔ pgvector を接続する gem として `neighbor`（ankane/neighbor）を採用する**
2. **`EmbeddingModel` / `VectorSearch` の DI 配線方式は、Rails 標準の初期化子で具体実装クラスを定数（または `Rails.application.config` の属性）にバインドする最小構成とする**。専用 DI コンテナ gem（dry-container 等）は導入しない

### 実装方針

1. **gem 導入**:
   - `Gemfile` に `gem "neighbor"` を追加（バージョン制約は `~> 1.0`）
   - `pgvector` gem は neighbor の依存として自動的に解決されるため、明示的な追加はしない（ただし `bundle list` で実体を確認し、記事中で「neighbor の裏で pgvector gem が使われている」旨を補足できるようにする）

2. **マイグレーションでの pgvector 拡張・カラム・インデックス定義**:
   - `enable_extension "vector"` で pgvector 拡張を有効化
   - `ArticleEmbedding` テーブルに `t.vector :embedding, limit: <次元数>` を定義（次元数は採用する埋め込みモデルに従う。A-2 で決定）
   - ANN インデックスは neighbor のマイグレーション DSL（`add_index :article_embeddings, :embedding, using: :hnsw, opclass: :vector_cosine_ops` 相当）で作成。具体的な opclass・パラメータは A-5（類似度指標）の決定に従う

3. **`ArticleEmbedding` モデルでの宣言**:
   - `has_neighbors :embedding` をクラスマクロとして宣言

4. **`VectorSearch` 具体実装の構造**:
   - 具体実装クラス（例: `Neighbor::ArticleVectorSearch`）の内部で `ArticleEmbedding.nearest_neighbors(:embedding, query_vector, distance: "...")` を呼び出す
   - クラス名・配置パスは実装段階で確定する。本 ADR では「neighbor の API を抽象実装の内部に閉じ込める」点のみ規定

5. **DI 配線**:
   - `config/initializers/vector_search.rb` で `Rails.application.config.vector_search_implementation = Neighbor::ArticleVectorSearch.new(...)` 相当の設定を行う、または `VectorSearch` という定数を実装クラスにエイリアスする最小構成とする
   - コントローラ・ジョブからは `Rails.application.config.vector_search_implementation`（または定数）経由で参照する
   - DI コンテナ gem の導入はしない（本デモのスコープでは過剰）

## 結果

### ポジティブな影響

1. **コード量の最小化と Rails 規約への適合**
   - `has_neighbors` / `nearest_neighbors` という ActiveRecord 風 DSL により、`VectorSearch` 具体実装の中身が「ActiveRecord スコープを 1 行呼ぶ」程度に収まる[^3]
   - Rails 開発者にとって追加学習コストが小さく、記事のコードスニペットが「Rails らしさ」を保てる

2. **マイグレーション DSL による型安全な定義**
   - `t.vector` カラム宣言、`add_index ... using: :hnsw` インデックス宣言が neighbor 経由で利用可能[^3]。`execute "CREATE INDEX..."` のような生 SQL 散在を避けられる

3. **将来のバックエンド切替時の影響範囲が小さい**
   - neighbor は pgvector 以外にも sqlite-vec / MariaDB / MySQL（HeatWave）/ Redis（neighbor-redis）/ S3 Vectors（neighbor-s3）をサポートする[^3][^4]ため、A-3 を将来見直しても `has_neighbors` / `nearest_neighbors` のインターフェースは維持できる
   - 「pgvector 採用」という個別決定の発展余地として記事の続編が書きやすい

4. **メンテナンスの活発さ**
   - 1.0.0 が 2026-04-04 にリリースされ、Active Record 7.2+ への明示的対応が表明されている[^1][^2]
   - 同じく Andrew Kane 氏が pgvector gem 本体も保守しており[^5][^6]、依存関係の整合性が担保されている

5. **抽象化レイヤーとの整合**
   - 機能設計書 §6.3 で要求される「具体実装はアプリケーション層に閉じ込める」構造に neighbor の API は素直に収まる（`has_neighbors` をモデルに付与し、`nearest_neighbors` 呼び出しを `VectorSearch` 具体実装の内部に閉じる）

### ネガティブな影響・トレードオフ

1. **gem 依存の追加**
   - 詳細: 直接 SQL 案と比較すると、neighbor という外部 gem への依存が 1 つ増える
   - 対策: neighbor は MIT ライセンス[^2]・1,975 万ダウンロード[^2]・1.0.0 到達済みで、pgvector gem の README 自身が Rails 用途で推奨する立場[^6]にあるため、依存追加のリスクは小さい。記事中で「neighbor が裏で生成する SQL」を補足として示せば、gem に隠蔽された挙動を読者に開示できる

2. **Rails / Ruby バージョン要件の固定**
   - 詳細: neighbor 1.0.0 は Active Record >= 7.2 / Ruby >= 3.3 を要求する[^1][^2]。A-1 が将来 Rails 7.1 以前へダウングレードされる場合、neighbor 0.6.x 系への切替が必要
   - 対策: A-1 で Rails 最新安定版（Rails 8.x）が決定済みのため現状は問題ない。再評価条件に明記済み

3. **gem の API 変更追従コスト**
   - 詳細: neighbor のメジャーバージョンアップ（1.0.0 → 2.0.0 等）が将来発生した場合、`VectorSearch` 具体実装の内部修正が必要になる可能性がある
   - 対策: neighbor の利用箇所を `VectorSearch` 具体実装クラス内部に閉じ込める設計（機能設計書 §6.3 の方針）により、影響範囲を 1 ファイルに局所化する

4. **DI を最小構成にすることによる柔軟性の制限**
   - 詳細: `Rails.application.config` 経由または定数経由のバインディングは、リクエスト単位での実装切替や複雑なライフサイクル管理ができない
   - 対策: 本デモは単一実装を前提とし、テスト時のみ差し替えれば十分（RSpec の `allow(...)` / `stub_const` で対応可能）。要件が変化したら DI コンテナ導入を再検討する

## 代替案

### 案1: pgvector gem（pgvector/pgvector-ruby）単独利用

**概要**: neighbor を導入せず、`pgvector` gem を直接 ActiveRecord に接続して、距離演算子の SQL は自前で記述する方式

**メリット**:
- 依存関係が 1 段階浅くなる（neighbor を経由しない）
- pgvector の型変換のみを gem に任せ、検索 SQL は自前で完全制御できる

**デメリット**:
- pgvector gem 自身が「For Rails, check out Neighbor」と明示的に neighbor を推奨している[^6]ため、自前実装の合理性が薄い
- ActiveRecord 統合機能（`has_neighbors` 相当）は提供されないため、距離指標の選択・スコープ生成・ANN インデックス DSL を自作する必要がある
- 記事執筆時に「Rails らしさ」を犠牲にし、コードスニペットの量が増える

**却下理由**: pgvector gem の README が Rails 用途では neighbor を案内している以上、neighbor を選ばない積極的な理由がない。コード量とメンテナンス性の観点でも neighbor が優位。

### 案2: 直接 SQL（gem を使わず Arel / raw SQL）

**概要**: gem を導入せず、`ActiveRecord::Base.connection.execute` や `Model.find_by_sql` / `Arel.sql` を用いて pgvector の演算子を直接記述する方式

**メリット**:
- gem 依存ゼロ。pgvector に閉じれば Rails のバージョン互換性問題は実質発生しない
- 記事中で「ベクターDB の生のクエリ」を直接示せる

**デメリット**:
- INSERT/UPDATE 時のベクトル値の文字列化、距離演算子の選択、HNSW インデックスのマイグレーション SQL を毎回手書きする必要がある[^13][^14]
- 抽象化はできるが、neighbor が解消する範囲を完全に再実装する形になる
- 各画面の実装で SQL リテラルが分散すると、本デモのスコープでも実装行数が無視できないほど増える

**却下理由**: neighbor が肩代わりする責務（型変換・距離指標 DSL・ANN インデックス DSL）を再実装するコストが、本デモで得られる「gem 依存ゼロ」のメリットを上回らない。なお、技術記事の解説では「neighbor が裏で生成する SQL」を補足として併記する価値があるため、直接 SQL の知識自体は活用する。

### 案3: qdrant-ruby（patterns-ai-core/qdrant-ruby）

**概要**: pgvector ではなく Qdrant を採用し、qdrant-ruby HTTP クライアントを `VectorSearch` 具体実装に DI する方式

**メリット**:
- 専用ベクターDB を採用すれば、より高度な検索機能（フィルタ、ペイロード、量子化等）が利用可能
- Qdrant 自体は Docker Compose で完全ローカル動作可能[^8]

**デメリット**:
- ADR A-3 で pgvector が採用されているため、Qdrant への切替は A-3 の前提を覆す
- ActiveRecord 統合がなく[^8]、`ArticleEmbedding` を ActiveRecord モデルから切り離す必要がある（Qdrant 側のコレクションになる）
- 記事執筆において「Rails 標準構成にベクター検索を組み込む」というデモのコンセプトから外れる
- HTTP クライアントの低レベル API のみ提供されるため、各種クエリの構築コードが増える

**却下理由**: A-3 で pgvector が採用されている前提を覆す決定であり、本 ADR のスコープ外。将来 A-3 を見直す段階で再評価する。

### 案4: weaviate-ruby（patterns-ai-core/weaviate-ruby）

**概要**: Weaviate を採用し、weaviate-ruby HTTP クライアントを `VectorSearch` 具体実装に DI する方式

**メリット**:
- Weaviate は GraphQL ベースのリッチなクエリ機能を持つ
- ローカル動作可能[^11]

**デメリット**:
- 案3 と同じく A-3 の前提を覆す
- weaviate-ruby は最終リリースが 2024-10-01 で、本 ADR 時点（2026-05-06）から 1 年 7 ヶ月更新が止まっている[^10]。技術記事で読者に推奨するのはリスクが高い
- ActiveRecord 統合なし[^11]

**却下理由**: A-3 の前提を覆すことに加え、メンテナンス停滞リスクが大きい。

### 案5: dry-container 等の DI コンテナ gem を導入する配線方式

**概要**: `EmbeddingModel` / `VectorSearch` の差し替えを dry-container や他の DI コンテナ gem で管理する方式

**メリット**:
- 依存解決のライフサイクル・スコープ管理を宣言的に書ける
- 大規模アプリで複数実装を切り替える場合に有用

**デメリット**:
- 本デモは単一実装を前提とし、テスト時のみ差し替えれば十分
- 追加 gem の学習コスト・記事中の解説負担が増える
- Rails 標準の `Rails.application.config` および定数バインドで要件を満たせる

**却下理由**: 本デモのスコープでは過剰。Rails 標準機構で十分な配線方式が組めるため、追加の gem 依存を導入する合理性がない。

## 関連 ADR

- [ADR 001: Rails / Ruby バージョン選定（A-1）](./001-rails-ruby-versions.md) — Rails 8.1.3 / Ruby 3.4.9 が neighbor 1.0.0 の Ruby >= 3.3 / AR >= 7.2 を満たす
- [ADR 002: 埋め込みモデルと実行基盤の選定（A-2）](./002-embedding-model-and-runtime.md) — 出力次元 768、L2 正規化済み
- [ADR 003: ベクターDB 選定（A-3）](./003-vector-database.md) — pgvector 採用
- [ADR 005: 類似度指標の選定（A-5）](./005-similarity-metric.md) — 本 ADR の `nearest_neighbors(distance: "cosine")` 引数および HNSW opclass の決定根拠

## 関連調査報告書

- [調査報告書 R-C: Rails とベクターDBを橋渡しする gem の比較](../reports/r-c-rails-integration-gems-comparison.md)
- [調査報告書 R-B: ベクターDB比較](../reports/r-b-vector-db-comparison.md)（A-3 の根拠）
- [機能設計書 §6.2 / §6.3](../functional-design/functional-design.md)（抽象インターフェース定義）
- [用語集](../glossary/glossary.md)

## 参照ソース URL

[^1]: ankane/neighbor CHANGELOG.md, https://github.com/ankane/neighbor/blob/master/CHANGELOG.md
[^2]: RubyGems neighbor gem ページ, https://rubygems.org/gems/neighbor
[^3]: ankane/neighbor README, https://github.com/ankane/neighbor
[^4]: ankane/neighbor-redis README, https://github.com/ankane/neighbor-redis
[^5]: RubyGems pgvector gem ページ, https://rubygems.org/gems/pgvector
[^6]: pgvector/pgvector-ruby README, https://github.com/pgvector/pgvector-ruby
[^8]: patterns-ai-core/qdrant-ruby README, https://github.com/patterns-ai-core/qdrant-ruby
[^10]: RubyGems weaviate-ruby gem ページ, https://rubygems.org/gems/weaviate-ruby
[^11]: patterns-ai-core/weaviate-ruby README, https://github.com/patterns-ai-core/weaviate-ruby
[^13]: Vector Search in Ruby - Visuality Blog, https://www.visuality.pl/posts/vector-search-in-ruby
[^14]: ActiveRecord neighbor vector search, with per-document max - Bibliographic Wilderness (2026-02-18), https://bibwild.wordpress.com/2026/02/18/activerecord-neighbor-vector-search-with-per-document-max/
