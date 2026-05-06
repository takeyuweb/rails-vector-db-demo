# 調査報告書 R-C: Rails とベクターDBを橋渡しする gem の比較

**作成日**: 2026/05/06
**ステータス**: Draft
**関連ADR**: A-4「Rails 統合方式（gem）の選定」

## 概要

### 調査の背景

機能設計書（[functional-design.md](../functional-design/functional-design.md) §6.2）では、`EmbeddingModel` と `VectorSearch` という抽象インターフェースを定義し、コントローラ・ジョブ・ビューが具体実装に依存しない構造を採っている。`VectorSearch` の具体実装は ADR で決定する採用ベクターDB（pgvector / Qdrant / Weaviate / sqlite-vec 等）に依存し、その背後で Rails（ActiveRecord）からベクターDBを操作するための gem を選定する必要がある。

### 調査の目的

各候補 gem の機能・対応範囲・メンテナンス状況・Rails 互換性・抽象化レイヤーとの相性を把握し、ADR A-4 における判断材料を提供する。本報告書は採否を決定するものではなく、ADR で意思決定を行うための情報整理を行う。

### 調査範囲

調査対象:

1. **ankane/neighbor** — Rails 向けの近傍検索 gem。複数バックエンド対応
2. **pgvector/pgvector-ruby**（gem 名 `pgvector`）— pgvector の低レベル型アダプタ
3. **patterns-ai-core/qdrant-ruby** — Qdrant の HTTP API ラッパー
4. **patterns-ai-core/weaviate-ruby** — Weaviate の HTTP API ラッパー
5. **直接 SQL（Arel / raw SQL）** — gem を使わず ActiveRecord で生クエリを書く方式
6. （補助）**ruby-ist/weaviate_record** — Weaviate に対する ActiveRecord 風 ORM

調査範囲外:

- 各ベクターDB そのもののベンチマーク（R-A / R-B 系の調査担当）
- 埋め込みモデル選定（別調査）
- ADR A-4 の意思決定そのもの（本報告書はインプットを提供するに留まる）

## 調査内容

### 調査方法

- 各 gem の GitHub リポジトリ（README・CHANGELOG）と RubyGems ページを WebFetch で参照
- 最終リリース日・依存バージョン・ライセンス・ActiveRecord 統合度を一次ソースから取得
- 否定的情報（メンテナンス停滞・Rails 統合の欠如・代替案の存在）も意図的に収集

## 調査結果

### R-C.1 ankane/neighbor

- **gem 名**: `neighbor`
- **最新版**: 1.0.0 / 2026-04-04 リリース[^1][^2]
- **総ダウンロード数**: 約 1,975 万[^2]
- **ライセンス**: MIT[^2]
- **Ruby 要件**: >= 3.3、**Active Record 要件**: >= 7.2（1.0.0 で旧版サポート打ち切り）[^1][^2]
- **対応バックエンド**[^3]:
  - PostgreSQL: pgvector、cube
  - MariaDB 11.8
  - MySQL 9（HeatWave 経由）
  - SQLite: sqlite-vec
  - 別 gem として **neighbor-redis**（Redis 向け）、**neighbor-s3**（S3 Vectors 向け）が存在[^4]
- **未対応**: Qdrant、Weaviate、OpenSearch、Elasticsearch、Pinecone、Milvus 等の専用ベクターDB（README に記載なし）[^3]
- **ActiveRecord 統合**[^3]:
  - `has_neighbors :embedding` マクロでモデル宣言
  - `item.nearest_neighbors(:embedding, distance: "cosine")` でインスタンス／クラスメソッドの両方から検索
  - 結果に `neighbor_distance` 属性が付与される
- **距離演算子**[^3]:
  - 全バックエンド共通: `euclidean`、`cosine`
  - pgvector 追加: `inner_product`、`taxicab`、`hamming`、`jaccard`
  - cube 追加: `taxicab`、`chebyshev`
  - SQLite/MariaDB 追加: `hamming`
- **ANN インデックス**[^3]:
  - pgvector の HNSW・IVFFlat をマイグレーション DSL で作成可能
    - 例: `add_index :items, :embedding, using: :hnsw, opclass: :vector_l2_ops`
  - `hnsw.ef_search` のセッション単位設定もサポート
  - SQLite では vec0 仮想テーブルの作成支援あり（Rails 8 以降の virtual tables を活用）
- **ドキュメント**: README が単一バックエンド単位で詳細セクションに分かれており、設定〜検索〜インデックスまで一通り揃う[^3]
- **メンテナンス**: 1.0.0 が 2026-04-04 リリース、それ以前も 2024〜2025 にかけて継続的に 0.5.x → 0.6.x → 1.0.0 と更新されている[^1]

### R-C.2 pgvector/pgvector-ruby（gem 名 `pgvector`）

- **gem 名**: `pgvector`
- **最新版**: 0.3.3 / 2026-03-19 リリース[^5]
- **総ダウンロード数**: 約 201 万[^5]
- **ライセンス**: MIT[^5]
- **Ruby 要件**: >= 3.1[^5]
- **位置づけ**: 低レベル型アダプタ。`pg` および `Sequel` の双方をサポートし、Ruby 値と pgvector の `vector` 型の相互変換を提供する[^6]
- **Rails での位置づけ**: README に「For Rails, check out [Neighbor](https://github.com/ankane/neighbor)」と明記されており、**Rails 用途では neighbor の利用が公式に推奨されている**[^6]
- **ActiveRecord 統合**: 直接の統合機能は提供されない（`pg` と `Sequel` 向けの例のみ）[^6]
- **メンテナンス**: 同じく Andrew Kane 氏が neighbor と並行して保守。最終更新は 2026-03-19[^5]

### R-C.3 patterns-ai-core/qdrant-ruby

- **gem 名**: `qdrant-ruby`
- **最新版**: 0.9.10 / 2025-11-25 リリース[^7]
- **総ダウンロード数**: 約 14.3 万[^7]
- **ライセンス**: Apache-2.0[^7]
- **Ruby 要件**: >= 2.6.0[^7]
- **依存**: `faraday >= 2.0.1, < 3`（Rails 依存なし）[^7]
- **位置づけ**: Qdrant REST API の薄い HTTP ラッパー。Langchain.rb スタックの一部として開発されている[^8]
- **ActiveRecord 統合**: なし。`client.collections.create(...)`、`client.points.upsert(...)`、`client.points.search(...)` など低レベル API のみ提供[^8]
- **scope や `has_neighbors` 風 DSL**: 提供されない[^8]
- **メンテナンス**: 0.9.10 が 2025-11-25。RubyGems 上の Rails 互換性メタデータでは Rails 2.3〜8.0 の幅広いレンジで動作報告がある（依存が薄いため）[^9]

### R-C.4 patterns-ai-core/weaviate-ruby

- **gem 名**: `weaviate-ruby`
- **最新版**: 0.9.2 / 2024-10-01 リリース[^10]
- **総ダウンロード数**: 約 8.1 万[^10]
- **ライセンス**: MIT[^10]
- **Ruby 要件**: >= 2.6.0[^10]
- **依存**: `faraday >= 2.0.1, < 3.0`、`graphlient >= 0.7.0, < 0.9.0`（Rails 依存なし）[^10]
- **位置づけ**: Weaviate REST/GraphQL API の薄い HTTP ラッパー。Langchain.rb スタックの一部[^11]
- **ActiveRecord 統合**: なし。クライアント生成 → スキーマ作成 → object CRUD → `near_text`/`near_vector` クエリの低レベル操作のみ[^11]
- **ローカル動作**: 任意の `url` を指定可能なため、Docker Compose 上のローカル Weaviate を指せる[^11]
- **メンテナンス**: 最終リリースが 2024-10-01 で、本調査時点（2026-05-06）から 1 年 7 ヶ月更新がない。qdrant-ruby（2025-11-25）と比較するとペースが遅い[^10]

### R-C.5 ruby-ist/weaviate_record（補助情報）

- **位置づけ**: Weaviate に対して ActiveRecord 風の ORM を提供する第三者 gem[^12]
- **採用情報**: GitHub 上のスター数 15・コミット数 33（2026-05-06 時点の README 表示）[^12]
- **評価**: 採用実績・コミュニティの厚みは neighbor や qdrant-ruby/weaviate-ruby 本体と比較して大きく劣る。本デモのように「記事執筆で読者に薦める」用途では追加採用の合理性が薄い[^12]

### R-C.6 直接 SQL（Arel / raw SQL）

- **概要**: gem を使わず、`ActiveRecord::Base.connection.execute` や `Model.find_by_sql` / `Arel.sql` から pgvector の演算子（`<->`、`<=>`、`<#>`）を直接記述する方式
- **典型例**[^13]:
  ```sql
  SELECT items.* FROM items ORDER BY items.embedding <=> '[0.1, 0.4, 0.6]' LIMIT 10
  ```
- **ActiveRecord 統合**:
  - 型情報を ActiveRecord に伝えないため、INSERT 時に値を `to_s` 等で文字列化する必要がある[^13]
  - 高度なクエリ（CTE、ウィンドウ関数による per-document max 等）では `Arel.sql(<<~SQL)` ベースの記述が現実解になる場合もあり、Bibliographic Wilderness（2026-02-18）でもそのパターンが報告されている[^14]
- **メリット**:
  - gem 依存ゼロで、SQL の挙動が直接見える（記事の解説では「ベクターDB の生のクエリ」を示しやすい）
  - pgvector に閉じれば Rails のバージョン互換性問題は実質発生しない
- **デメリット**:
  - INSERT/UPDATE 時の型変換、ベクトル値のエスケープ、距離演算子の選択を毎回手書きすることになる
  - ANN インデックス作成のマイグレーション DSL も自前で書く必要がある（`execute "CREATE INDEX ... USING hnsw (...)"` 相当）
  - 上記負担は neighbor が解消する範囲と完全に重複しており、デモ規模でも実装行数が増える
- **記事執筆観点**:
  - 「neighbor が裏で生成しているクエリ」を補足として示す価値はある
  - 主実装として採用すると、Rails 流の自然さを犠牲にし、各画面の実装で SQL リテラルが分散する

## 分析・考察

### 比較表

| 評価項目 | neighbor | pgvector | qdrant-ruby | weaviate-ruby | 直接 SQL |
|---------|----------|----------|-------------|---------------|---------|
| 対応ベクターDB | pgvector / cube / sqlite-vec / MariaDB 11.8 / MySQL 9 / Redis(別gem) / S3(別gem)[^3][^4] | pgvector のみ[^6] | Qdrant のみ[^8] | Weaviate のみ[^11] | RDB 拡張系のみ（pgvector 等） |
| ActiveRecord 統合 | 高（`has_neighbors` / `nearest_neighbors`）[^3] | 低（型アダプタのみ）[^6] | なし（HTTP クライアント）[^8] | なし（HTTP クライアント）[^11] | 自前実装 |
| 距離指標の DSL | あり（`distance: "cosine"` 等）[^3] | なし[^6] | API パラメータで指定[^8] | API パラメータで指定[^11] | SQL 演算子を直書き |
| ANN インデックス DSL | あり（HNSW / IVFFlat）[^3] | なし | API でコレクション作成時に指定[^8] | API でクラス作成時に指定[^11] | `execute` で手書き |
| 最終リリース | 2026-04-04（v1.0.0）[^1] | 2026-03-19（v0.3.3）[^5] | 2025-11-25（v0.9.10）[^7] | 2024-10-01（v0.9.2）[^10] | — |
| 公式 Rails サポート | あり（AR >= 7.2）[^2] | Rails 用途は neighbor を案内[^6] | Rails 依存なし、互換は薄い依存により広い[^7][^9] | Rails 依存なし[^10] | — |
| ライセンス | MIT[^2] | MIT[^5] | Apache-2.0[^7] | MIT[^10] | — |
| ドキュメント | 充実（バックエンド別セクション）[^3] | 簡潔（pg/Sequel 例）[^6] | API メソッド網羅型[^8] | API メソッド網羅型[^11] | pgvector 公式ドキュメント参照 |
| 抽象化レイヤー（`VectorSearch`）との相性 | 高（`has_neighbors` を `ArticleEmbedding` に付与し、`nearest_neighbors` を `VectorSearch` 実装内で呼ぶ自然な構造） | 中（型変換は任せ、検索ロジックは自前） | 中（クライアントを `VectorSearch` 実装に DI） | 中（同上） | 中（`VectorSearch` 実装内に SQL を集約すれば抽象化は維持） |
| Rails 8.x 互換 | 1.0.0 が AR >= 7.2 を要求[^1][^2] | 制約なし[^5] | 制約なし[^7] | 制約なし[^10] | Rails 自体に従う |
| 記事執筆のしやすさ | 高（コード量が最小、Rails 規約に沿う） | 低（単独では Rails 風実装に届かない） | 中（Qdrant 採用が前提なら自然） | 中（Weaviate 採用が前提だが更新頻度に懸念） | 中（SQL を見せたい記事には向くが冗長） |

### 主要な発見

1. **neighbor は pgvector / sqlite-vec / MariaDB / MySQL / Redis / S3 Vectors を単一の `has_neighbors` インターフェースで吸収する**。RDB 拡張系のベクターDB を採用する場合の事実上の標準である[^3][^4]。
2. **pgvector gem は Rails 用途では neighbor 経由での利用が前提**になっている（README が明示的に neighbor を案内）[^6]。pgvector 単独で ActiveRecord 風の DSL を期待することはできない。
3. **qdrant-ruby と weaviate-ruby は ActiveRecord 統合を提供しない HTTP クライアント**であり、`VectorSearch` 抽象化との接続は「クライアントオブジェクトを DI してクエリを実装側で組み立てる」形になる[^8][^11]。
4. **weaviate-ruby は最終リリースから 1 年 7 ヶ月（2024-10-01 → 2026-05-06）更新が止まっている**[^10]。qdrant-ruby（2025-11-25）と比較してメンテナンス頻度に明確な差がある。
5. **直接 SQL 案は技術的には成立するが、neighbor が解消している型変換・距離指標選択・ANN インデックス DSL を自前で再実装することになる**[^13][^14]。記事執筆の観点では「neighbor が生成する SQL を補足として示す」用途のほうが価値が高い。
6. **本デモの抽象化（`VectorSearch`）は、どの選択肢を採用しても成立する**。`VectorSearch` 実装クラスの内部に gem の API 呼び出し（または SQL）を閉じ込める構造のため、選択肢間の差は「実装の素直さ」と「記事の説明しやすさ」に集約される。

### リスクと制約

- **Rails 8.x 互換性**: neighbor 1.0.0 は Active Record >= 7.2 を要求するため、Rails 8.x のみを採用する本デモでは制約にはならない[^1][^2]。ただし、Rails バージョン決定（別 ADR）が 7.1 以前まで遡る場合は neighbor 0.6.x 系の利用が必要になる。
- **専用ベクターDB（Qdrant/Weaviate）採用時の二段構成**: ADR で Qdrant を採用すると、neighbor は使えず、qdrant-ruby を `VectorSearch` 実装に DI する必要がある。この場合、`ArticleEmbedding` は ActiveRecord モデルではなく Qdrant 側のコレクションになり、機能設計書 §2.1.2 の物理層前提（§2.1.3 で柔軟性を確保済み）と整合する。
- **weaviate-ruby のメンテナンス**: 1 年 7 ヶ月更新が止まっている事実は、Weaviate を採用する場合のリスクとして ADR で扱う必要がある[^10]。代替として weaviate_record があるが、コミュニティ規模が小さく、推奨は難しい[^12]。
- **記事の対象読者**: 本デモの第一目的は「Rails 標準構成へのベクター検索の組み込み方を示す」ことであり、専用ベクターDB を選ぶと「ベクターDB クライアントの使い方」の比重が上がる。読者層として Rails 開発者を想定するなら、ActiveRecord 統合が深い neighbor 系のほうが解説の焦点を絞りやすい。

## 結論・推奨事項

### 結論

- **ベクターDB 候補ごとの推奨 gem の対応**:
  - **pgvector を採用する場合**: `neighbor` 一択。pgvector gem は neighbor の依存として裏で使われる位置づけ[^3][^6]
  - **sqlite-vec を採用する場合**: `neighbor` + `sqlite-vec` の組み合わせが README 推奨ルート[^3]
  - **MariaDB 11.8 / MySQL 9 (HeatWave) を採用する場合**: `neighbor`[^3]
  - **Qdrant を採用する場合**: `qdrant-ruby`（HTTP クライアント）+ 自作の `VectorSearch` 実装[^8]
  - **Weaviate を採用する場合**: `weaviate-ruby`（メンテナンス頻度に懸念あり）+ 自作の `VectorSearch` 実装、または `weaviate_record`（採用実績は限定的）[^11][^12]
  - **直接 SQL**: pgvector 採用かつ「gem に頼らない透明な実装」を記事の主題にする場合のみ合理性がある

- **ベクターDB が未確定の段階で「最も柔軟な選択肢」**: **neighbor**。理由は以下の通り。
  1. **対応バックエンドの広さ**: pgvector / cube / sqlite-vec / MariaDB / MySQL / Redis / S3 と、本デモが現実的に検討する RDB 拡張系をほぼ網羅する[^3][^4]
  2. **ベクターDB 切り替え時の影響範囲が小さい**: `has_neighbors` と `nearest_neighbors` のインターフェースが共通であり、`VectorSearch` 実装の中身を最小の差分で差し替えられる
  3. **メンテナンスが活発**: 2026-04-04 に v1.0.0 がリリースされ、Active Record 7.2+ への明示的な対応がある[^1][^2]
  4. **記事執筆との相性**: ActiveRecord 規約に沿うため、Rails 開発者にとっての追加学習コストが小さく、コードスニペットを記事に貼った際の意図が伝わりやすい

- **専用ベクターDB（Qdrant / Weaviate）を採用する場合の留意点**:
  - 本デモのスコープ（記事 20〜50 件）では neighbor + pgvector/sqlite-vec で十分に成立する。専用ベクターDB を採用するなら「なぜ専用 DB を選ぶか」を ADR 本文で明示する必要がある
  - Weaviate を採用する場合、weaviate-ruby のメンテナンス停滞リスクを許容できるか ADR で判定する

### 推奨事項

採否判断は ADR A-4 に委ねる。本報告書は以下の入力を ADR に提供する:

1. **ベクターDB が pgvector / sqlite-vec / MariaDB / MySQL / Redis / S3 のいずれかになる場合は、gem 選定は事実上 `neighbor` で確定**できる。ADR A-4 ではベクターDB 自体の判定に集中できる
2. **ベクターDB が Qdrant の場合**は `qdrant-ruby` を採用し、`VectorSearch` 実装で HTTP クライアントを呼ぶ構造とする
3. **ベクターDB が Weaviate の場合**は `weaviate-ruby` のメンテナンス頻度を踏まえてリスクを ADR で記述したうえで採用判断する
4. **直接 SQL 案は本デモの主実装としては推奨しない**。ただし、技術記事内で「neighbor が裏で生成する SQL」の解説に直接 SQL を併記する価値はある

### 次のアクション

- [ ] ADR A-4「Rails 統合方式（gem）の選定」で、本報告書を入力として gem を確定する
- [ ] 関連 ADR（採用ベクターDB、Rails バージョン）の決定状況を踏まえ、neighbor のバージョン要件（AR >= 7.2 / Ruby >= 3.3）と整合するかを最終確認する

## 関連資料

- [要件定義書](../requirements/requirements.md)（特に §3.4 未決事項）
- [機能設計書](../functional-design/functional-design.md)（特に §6.2 抽象インターフェース、§6.3 抽象化の境界）
- [用語集](../glossary/glossary.md)
- [ADR A-4「Rails 統合方式（gem）の選定」](../adr/004-rails-integration-gem.md)（本報告書を判断材料として作成済み）

## 参照ソース URL 一覧

[^1]: ankane/neighbor CHANGELOG.md, https://github.com/ankane/neighbor/blob/master/CHANGELOG.md
[^2]: RubyGems neighbor gem ページ, https://rubygems.org/gems/neighbor
[^3]: ankane/neighbor README, https://github.com/ankane/neighbor
[^4]: ankane/neighbor-redis README, https://github.com/ankane/neighbor-redis
[^5]: RubyGems pgvector gem ページ, https://rubygems.org/gems/pgvector
[^6]: pgvector/pgvector-ruby README, https://github.com/pgvector/pgvector-ruby
[^7]: RubyGems qdrant-ruby gem ページ, https://rubygems.org/gems/qdrant-ruby
[^8]: patterns-ai-core/qdrant-ruby README, https://github.com/patterns-ai-core/qdrant-ruby
[^9]: RailsBump qdrant-ruby compatibility, https://www.railsbump.org/gems/qdrant-ruby
[^10]: RubyGems weaviate-ruby gem ページ, https://rubygems.org/gems/weaviate-ruby
[^11]: patterns-ai-core/weaviate-ruby README, https://github.com/patterns-ai-core/weaviate-ruby
[^12]: ruby-ist/weaviate_record README, https://github.com/ruby-ist/weaviate_record
[^13]: Vector Search in Ruby - Visuality Blog, https://www.visuality.pl/posts/vector-search-in-ruby
[^14]: ActiveRecord neighbor vector search, with per-document max - Bibliographic Wilderness (2026-02-18), https://bibwild.wordpress.com/2026/02/18/activerecord-neighbor-vector-search-with-per-document-max/

参考（直接引用していないが調査過程で参照したもの）:

- Crunchy Data: Ruby on Rails Neighbor Gem for AI Embeddings, https://www.crunchydata.com/blog/ruby-on-rails-neighbor-gem-for-ai-embeddings
- FireHydrant: Semantic search with Ruby on Rails, https://firehydrant.com/blog/semantic-search-with-ruby-on-rails/
- Liam ERD: Building Semantic Search in Ruby on Rails Using the Neighbor Gem, https://liambx.com/blog/semantic-search-rails-neighbor-gem
- Till Code: Vector Search in Rails with SQLite (sqlite-vec), https://tillcode.com/vector-search-in-rails-with-sqlite-sqlite-vec/
- Alex Garcia: Using sqlite-vec in Ruby, https://alexgarcia.xyz/sqlite-vec/ruby.html

## 改訂履歴

| バージョン | 日付 | 変更内容 |
|-----------|------|---------|
| 1.0 | 2026/05/06 | 初版作成 |
