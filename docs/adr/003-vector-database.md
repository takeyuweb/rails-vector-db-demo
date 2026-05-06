# ADR A-3: ベクターDB（物理層）の選定

## ステータス

提案中

## 日付

2026-05-06

## 信頼度

高 — 候補は調査報告書 R-B にて公式ドキュメント・公式リポジトリの一次情報で網羅的に比較済み。本デモ規模（ブログ記事 20〜50 件）と「Rails 開発者を主読者とする Zenn 技術記事の題材」という用途を満たす最適解として、技術選定の不確実性は小さい。ただしパフォーマンス実測は未実施のため、性能観点では「中」相当の留保がある。

## 再評価条件

以下のいずれかが発生した場合、本決定を再評価する。

- 記事規模が 10,000 件超に拡大し、線形走査と HNSW のいずれでも応答性能が要件（要件定義書 §3.3）を満たさなくなった場合
- pgvector が新規開発を停止、または本デモが採用する PostgreSQL 系列のサポートを終える場合
- Zenn 記事のテーマを「Rails の外側にベクター DB を置くアーキテクチャ」へ変更する場合（その場合は第二推薦の Qdrant への置換を検討）
- 埋め込みモデル（ADR A-2）が pgvector の `vector` 型上限 16,000 次元を超える次元数を出力するモデルへ変更された場合

## コンテキスト

本デモは、Rails アプリにブログ記事の類似検索機能を統合する過程を Zenn 技術記事として題材化することを目的とする。要件定義書 §3.4 および機能設計書 §2.1.3 において、埋め込みベクトルの保管と類似検索を担う物理層は ADR で決定するものとされており、本 ADR がそれに該当する。

調査報告書 R-B（`docs/reports/r-b-vector-db-comparison.md`）にて、ローカル動作可能な 9 候補（pgvector / sqlite-vec / sqlite-vss / Qdrant / Weaviate / Chroma / Milvus Lite / Milvus Standalone / neighbor gem 単体）を一次情報ベースで比較済み。

### 現状の問題点

- 物理層が未確定であるため、機能設計書では `article_embeddings` の物理表現を「ADR で決定」と保留している（機能設計書 §2.1.3）。実装フェーズに進むためには物理層の確定が必須
- 候補ごとに「Rails 統合の濃さ」「Docker Compose 構成の複雑さ」「ライセンス」「説明コスト」が大きく異なり、Zenn 記事の題材適性に直接影響する

### 制約条件

- **完全ローカル動作**: 外部 API・マネージドサービスは不可（要件定義書 §3.2）
- **Docker Compose で起動容易**: 読者の追体験コストを最小化する（要件定義書 §3.2）
- **既存 Rails の PostgreSQL を流用**: 追加コンテナを最小化し、構成の単純さを保つ
- **記事規模 20〜50 件**: 大規模パフォーマンス最適化は不要
- **Zenn 記事での説明容易性**: Rails 開発者にとって認知負荷が小さい構成であること
- **OSS 公開**: ライセンス条項が緩いものを選ぶ（用語集「OSS 公開」）

## 決定

**ベクター DB の物理層として `pgvector` を採用する。Rails からの呼び出しには `neighbor` gem を用いる。**

PostgreSQL バージョンは **本デモ作成時点（2026-05-06）における `pgvector/pgvector` の最新安定タグに従う**ものとし、`compose.yaml` 上では `pgvector/pgvector:pg17` 系（または `pgvector/pgvector` の最新安定 `pg18` 系）の固定タグを使用する。具体タグは実装着手時点の Docker Hub の `pgvector/pgvector` リポジトリで最新の non-`latest` 固定タグを選定する（本 ADR の追記事項。A-1 は Rails / Ruby のバージョンのみを扱うため、PostgreSQL バージョンの決定は本 ADR に内包する）。

ANN インデックスについては **「初期実装は線形走査（インデックスなし、`exact` 検索）をデフォルトとし、HNSW インデックスの導入は Zenn 記事内で別章として段階的に解説する」方針を採用する。**

### 実装方針

1. **Docker Compose 構成**: 既存の PostgreSQL サービスのイメージを `pgvector/pgvector` の公式イメージに差し替える（追加コンテナを設けない）。具体タグは Rails / PostgreSQL バージョン決定 ADR（本 ADR の「決定」セクション参照）と整合させて確定する
2. **マイグレーション**: 初回マイグレーションで `CREATE EXTENSION IF NOT EXISTS vector` を実行する
3. **テーブル設計**: 機能設計書 §2.1.2 のとおり、`articles` とは別の独立した `article_embeddings` テーブルを設け、`embedding` 列に pgvector の `vector(N)` 型を割り当てる。`N` は採用する埋め込みモデル（ADR A-2）の出力次元数に一致させる
4. **整合性保証**: `article_embeddings.article_id` に UNIQUE 制約と `ON DELETE CASCADE` の外部キー制約を設定し、機能設計書 §2.1.3 の整合性要件を満たす
5. **gem 統合**: `neighbor` gem を Gemfile に追加し、`ArticleEmbedding` モデルで `has_neighbors :embedding` を宣言する。`VectorSearch` 抽象（機能設計書 §6.2.2）の具体実装はこの DSL を経由する
6. **インデックス方針**:
   - 初期実装ではインデックスを作成せず、線形走査（`exact: true` 相当）で類似度検索を行う
   - Zenn 記事の独立した章として「HNSW インデックスを追加する」マイグレーション例と、その効果（クエリプラン・応答時間の変化）を別途解説する
7. **類似度指標**: 採用する具体指標は ADR A-5 で決定する（pgvector はコサイン・内積・L2・L1・ハミング・Jaccard をサポートするため、A-5 の決定に追従可能）

## 結果

### ポジティブな影響

1. **Rails 開発者の認知負荷が最小**
   - 既存の PostgreSQL の延長線上で、マイグレーションでカラム追加・ActiveRecord で `has_neighbors` を宣言するだけで類似検索を実装できる
   - Zenn 記事として「Rails アプリに類似検索を後付けする」という導線を、既存知識のみで説明可能

2. **Docker Compose 構成の単純さが維持される**
   - 既存 PostgreSQL コンテナのイメージを差し替えるだけで導入完了。読者は `docker compose up` 一発で同じ環境を再現できる
   - 追加コンテナ・ネットワーク設定・サイドカーが不要

3. **ライセンスが緩い**
   - PostgreSQL License（MIT 類似）であり、OSS 公開・商用利用ともに制約が小さい[^pgvector-gh][^pgvector-brew]

4. **ANN インデックスを段階的に説明できる教材性**
   - 「最初は線形走査で十分動く → 件数が増えたときに HNSW を追加して効果を確認する」というストーリーが、Zenn 記事として自然に展開できる
   - pgvector は HNSW・IVFFlat・線形走査（`exact`）の 3 方式を切り替え可能であり[^pgvector-gh]、比較教材として価値が高い

5. **整合性が ON DELETE CASCADE で担保される**
   - 記事削除時に埋め込みも RDB の外部キー制約で自動削除される。アプリ層で削除順序を意識する必要がない

### ネガティブな影響・トレードオフ

1. **PostgreSQL のバージョンと拡張イメージが連動する**
   - `pgvector/pgvector` のタグは PostgreSQL のメジャーバージョンごとに分かれているため、Rails 側の `pg` gem と PostgreSQL 本体のバージョンを跨いで固定する必要がある[^pgvector-gh]
   - 対策: 本 ADR の「決定」セクションで PostgreSQL バージョンと `pgvector/pgvector` Docker タグの選定方針を確定済み。`compose.yaml` と `Gemfile.lock` でバージョンを明示固定する

2. **「専用ベクター DB の運用知識」が記事に登場しない**
   - 記事のテーマが「Rails 内で完結する類似検索」に閉じるため、Qdrant 等の専用ベクター DB を使うパターンを読者に提示できない
   - 対策: 記事末尾に「Rails の外側にベクター DB を置く選択肢（Qdrant 等）」への言及と、第二推薦の根拠（R-B）への参照を残す

3. **線形走査をデフォルトにすることのトレードオフ**
   - 20〜50 件規模では線形走査で性能要件を満たすと推定されるが、調査報告書 R-B は実測ベンチマークを持たない
   - 対策: 記事内で HNSW 追加手順を別章として用意し、件数増加時の対処法を読者に明示する

4. **HNSW を初期から採用しないことの教材的損失**
   - 記事公開時点ではインデックスの効果を直接示せない
   - 対策: 別章での比較解説により、むしろ「インデックス導入前後の差分」をより明確に提示できる利点に転化する

## 代替案

### 案 1: pgvector + HNSW を初期から採用

**概要**: 物理層は pgvector とし、初期マイグレーションで HNSW インデックスも同時に作成する。

**メリット**:
- 初期構成のままスケール耐性を持つ
- 「ベクター DB はインデックスを張るもの」という業界標準の理解と整合

**デメリット**:
- 20〜50 件規模ではインデックスの効果が体感できず、教材としての対比が弱まる
- pgvector の HNSW は線形走査と異なり再現性のある結果を保証しない（近似のため）。記事の動作確認手順がランダム性を含むことになり、追体験時の説明コストが増える
- マイグレーションの最初の一歩が複雑になり、「単に gem を入れて検索する」最小構成の魅力が薄れる

**却下理由**: 線形走査をデフォルトにすることで「最小構成 → 段階的にインデックスを導入」という記事構成が成立し、教材価値が高まる。本デモの主目的は本番運用ではなく題材提供であるため、初期から HNSW を強制する利益が小さい。

### 案 2: Qdrant + qdrant-ruby

**概要**: 専用ベクター DB として Qdrant を別コンテナで起動し、`qdrant-ruby` gem 経由で HTTP API を呼び出す。

**メリット**:
- 「専用ベクター DB とは何か」を記事題材として直接扱える
- HNSW・複数の類似度指標・フィルタリングなどベクター DB 固有機能を素直に紹介できる[^qdrant-collections]
- Apache 2.0 ライセンス、Rust 製で軽量[^qdrant-gh]

**デメリット**:
- Docker Compose に追加コンテナが 1 つ増える
- Rails 側で「ActiveRecord ではないクライアント」を経由するため、`after_commit` でのインデックス同期等のコードを自前実装する必要がある（記事中の配線コードが増える）
- `qdrant-ruby` はコミュニティ製で ActiveRecord 統合が提供されない[^qdrant-ruby]

**却下理由**: 本デモの主読者である Rails 開発者にとって認知負荷が大きく、「既存の Rails アプリに最小差分で類似検索を後付けする」という記事の主題と合致しない。R-B の第二推薦としての位置づけは維持し、記事末尾で言及する。

### 案 3: sqlite-vec + neighbor gem（SQLite バックエンド）

**概要**: SQLite の拡張 sqlite-vec を Rails コンテナに同梱し、追加コンテナなしで完結させる。

**メリット**:
- DB コンテナすら不要になり、構成が最小化される
- ライセンスは Apache-2.0 / MIT デュアル[^sqlitevec-gh]

**デメリット**:
- sqlite-vec は pre-v1（v0.1.9、2026 年 3 月時点）で、README に「expect breaking changes」と明記されており[^sqlitevec-gh]、Zenn 記事公開後にバージョン破綻で追体験できなくなるリスクがある
- `neighbor` gem の SQLite バックエンドは experimental マーク[^neighbor-gh]
- Rails の標準 DB 選択は PostgreSQL が一般的であり、Zenn 読者にとって「あえて SQLite を選ぶ理由」の説明コストが追加で必要

**却下理由**: 記事の保守性・追体験安定性のリスクが pgvector より高く、教材としての安定性を優先する。

### 案 4: Weaviate（または Chroma）

**概要**: Weaviate もしくは Chroma を別コンテナで起動し、コミュニティ製の Ruby クライアントから利用する。

**メリット**:
- ハイブリッド検索・RAG 等の高機能を持つ（Weaviate）[^weaviate-gh]
- Chroma には Rails 統合 gem `chromable` が存在[^chromable]

**デメリット**:
- 本デモのスコープ（用語集「スコープ外」: RAG / ハイブリッド検索 / 全文検索）に対して機能過剰
- Weaviate の Ruby クライアントは最終リリース（v0.9.2）が 2024-10-01 で、その後は dependabot 経由の依存更新コミットが中心。新機能追加や Weaviate 本体の API 進化への追従は限定的で、長期保守の不確実性がある[^weaviate-ruby]
- Chroma 単一ノード版は HNSW のみで線形走査との比較教材化が難しい

**却下理由**: 「20〜50 件規模、Rails 統合のシンプルさ、記事題材としての説明容易性」の三点で pgvector に劣る。

### 案 5: Milvus（Lite / Standalone）

**概要**: Milvus Lite は Python ライブラリ、Standalone は 3 コンテナ構成（milvus-standalone / minio / etcd）[^milvus-standalone]。

**却下理由**: Lite は Ruby から直接呼べない（Python ライブラリ）。Standalone は本デモ規模に対して構成が明らかに過大であり、Docker Compose の単純さ要件に反する。

## 関連 ADR・関連調査報告書

- [調査報告書 R-B: ローカル動作可能なベクターDB の比較](../reports/r-b-vector-db-comparison.md) — 本 ADR の判断材料
- [ADR 001: Rails / Ruby バージョンの選定（A-1）](./001-rails-ruby-versions.md)
- [ADR 002: 埋め込みモデルと実行基盤の選定（A-2）](./002-embedding-model-and-runtime.md) — 本 ADR で決定する `vector(N)` の `N`（次元数）は A-2 の決定（768）に追従する
- [ADR 004: Rails 統合 gem の選定（A-4）](./004-rails-integration-gem.md) — 本 ADR で `neighbor` gem 採用を方向付けるが、最終的な gem 選定は A-4 で決定する
- [ADR 005: 類似度指標の選定（A-5）](./005-similarity-metric.md) — pgvector は複数指標をサポートするため、A-5 の決定（コサイン類似度）に追従可能
- 機能設計書 §2.1.2 / §2.1.3 / §6.2.2 / §6.3: `docs/functional-design/functional-design.md`
- 用語集: `docs/glossary/glossary.md`（「ベクター DB」「ANN インデックス」「埋め込みベクトル」）

## 参考資料

[^pgvector-gh]: pgvector 公式 GitHub: https://github.com/pgvector/pgvector
[^pgvector-brew]: Homebrew Formulae - pgvector: https://formulae.brew.sh/formula/pgvector
[^sqlitevec-gh]: sqlite-vec 公式 GitHub: https://github.com/asg017/sqlite-vec
[^qdrant-gh]: Qdrant 公式 GitHub: https://github.com/qdrant/qdrant
[^qdrant-collections]: Qdrant 公式ドキュメント - Collections: https://qdrant.tech/documentation/concepts/collections/
[^qdrant-ruby]: qdrant-ruby gem: https://github.com/patterns-ai-core/qdrant-ruby
[^weaviate-gh]: Weaviate 公式 GitHub: https://github.com/weaviate/weaviate
[^weaviate-ruby]: weaviate-ruby gem: https://github.com/patterns-ai-core/weaviate-ruby
[^chromable]: chromable gem - Rails 統合: https://github.com/AliOsm/chromable
[^milvus-standalone]: Milvus 公式ドキュメント - Standalone Docker Compose: https://milvus.io/docs/install_standalone-docker-compose.md
[^neighbor-gh]: neighbor gem 公式 GitHub: https://github.com/ankane/neighbor
