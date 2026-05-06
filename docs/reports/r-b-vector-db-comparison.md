# R-B: ローカル動作可能なベクターDBの比較

**作成日**: 2026/05/06
**ステータス**: Draft
**調査ID**: R-B
**関連ADR**: [A-3「ベクターDB（物理層）の選定」](../adr/003-vector-database.md)

## 概要

### 調査の背景

本デモアプリは「ローカル完結（外部API禁止）」「Docker Compose による追体験性」「記事規模 20〜50 件」「Zenn 技術記事の題材としての説明しやすさ」という制約の下で、埋め込みベクトルの保管と類似検索を実現する物理層の選定を要する。要件定義書 §3.4 および機能設計書 §2.1.3 で示された未決事項であり、ADR A-3 の判断材料を収集する目的で本調査を実施した。

### 調査の目的

ローカル動作可能なベクターDBおよびRDB拡張を網羅的に比較し、以下を明らかにする。

- 各候補が本デモの制約（ローカル動作、20〜50件規模、Rails親和性、説明しやすさ）にどの程度適合するか
- Zenn記事の題材として推薦できる候補と、その理由

### 調査範囲

**対象**:
1. PostgreSQL拡張: pgvector
2. SQLite拡張: sqlite-vec, sqlite-vss
3. 専用ベクターDB（self-hosted）: Qdrant, Weaviate, Chroma, Milvus（Lite / Standalone）
4. Rails文脈での代替: neighbor gem の線形走査モード（pgvector非依存の純Rubyベクター検索の可能性）

**対象外**:
- マネージドサービス（Pinecone, Qdrant Cloud, Weaviate Cloud 等）
- 外部API依存の埋め込み生成（本調査の対象は保管・検索層のみ）
- 大規模パフォーマンスベンチマーク（本デモ規模では決定要因にならない）

## 調査内容

### 調査対象

| # | 候補 | 種別 |
|---|------|------|
| 1 | pgvector | PostgreSQL拡張 |
| 2 | sqlite-vec | SQLite拡張 |
| 3 | sqlite-vss | SQLite拡張（メンテナンス停止） |
| 4 | Qdrant | 専用ベクターDB（Rust製） |
| 5 | Weaviate | 専用ベクターDB（Go製） |
| 6 | Chroma | 専用ベクターDB（Rust + Python） |
| 7 | Milvus Lite | 組み込み型ベクターDB（Pythonライブラリ） |
| 8 | Milvus Standalone | 専用ベクターDB（多コンテナ構成） |
| 9 | neighbor gem（線形走査） | Ruby gem |

### 調査方法

- 各候補の公式GitHubリポジトリ・公式ドキュメントをWebFetchで参照
- ライセンス・最新バージョン・分散指標・インデックス方式を一次情報から取得
- Rails向けクライアントgemの存在と保守状況を確認
- 本デモ規模（20〜50件）における適合性を評価軸ごとに整理

## 調査結果

### 1. pgvector

- **最新バージョン**: 0.8.2[^pgvector-gh]
- **ライセンス**: PostgreSQL License（MITライク）[^pgvector-gh][^pgvector-brew]
- **対応PostgreSQLバージョン**: 13以降[^pgvector-gh]
- **ベクター次元数上限**: vector型 16,000次元（halfvec も同様、bit型は64,000、sparsevecは16,000非ゼロ要素）[^pgvector-gh]
- **類似度指標**: L2、内積、コサイン、L1、ハミング、Jaccard[^pgvector-gh]
- **インデックス方式**: HNSW、IVFFlat、インデックスなし時は線形走査（exact）[^pgvector-gh]
- **Docker提供**: あり（`pgvector/pgvector:pg18-trixie` 等、PostgreSQL 13〜18対応）[^pgvector-gh]
- **Rails向けgem**: `neighbor` gem（ankane作）が公式に近い扱いで、`has_neighbors` DSLによりActiveRecord的な記述が可能[^neighbor-gh]
- **Docker Compose構成**: 既存のPostgresサービスのイメージを `pgvector/pgvector` に差し替えるだけで導入可能。追加コンテナ不要

### 2. sqlite-vec

- **最新バージョン**: v0.1.9（2026年3月31日リリース）[^sqlitevec-gh]
- **ライセンス**: Apache-2.0 と MIT のデュアルライセンス[^sqlitevec-gh]
- **プロジェクト状態**: pre-v1（READMEに「expect breaking changes」の警告あり）。Mozilla Builders、Fly.io、Turso等が後援し、活発に開発中[^sqlitevec-gh]
- **インデックス方式**: 仮想テーブル `vec0` による線形走査が中心。IVF・DiskANN等の実験的実装あり（ただし安定版機能はブルートフォース中心）[^sqlitevec-gh]
- **Rails向けgem**: `neighbor` gem の SQLite バックエンドが対応（experimentalマーク）[^neighbor-gh]
- **Docker Compose構成**: SQLite はファイル DB のため独立コンテナ不要。Railsコンテナにビルド済みバイナリを同梱する形になる
- **留意点**: pre-v1 で破壊的変更の可能性、Rails標準DBとしてはSQLiteを使うケースが限定的

### 3. sqlite-vss

- **最新バージョン**: v0.1.2（2023年8月6日）[^sqlitevss-gh]
- **ライセンス**: MIT[^sqlitevss-gh]
- **プロジェクト状態**: メンテナンス停止。同一作者（asg017）が後継の sqlite-vec に開発リソースを集約[^sqlitevss-gh]
- **判定**: 2026年5月時点で新規採用は推奨されない。記事題材として選ぶ理由がない

### 4. Qdrant

- **最新バージョン**: v1.17.1（2026年3月27日）[^qdrant-gh]
- **ライセンス**: Apache 2.0[^qdrant-gh]
- **言語**: Rust
- **類似度指標**: Cosine、Dot、Euclid、Manhattan[^qdrant-collections]
- **インデックス方式**: HNSW[^qdrant-gh]
- **Docker提供**: 公式イメージ `qdrant/qdrant`。`docker run -p 6333:6333 qdrant/qdrant` の単一コマンドで起動可能（ただし認証なしの設定）[^qdrant-gh]
- **Rails向けgem**: `qdrant-ruby`（patterns-ai-core / Langchain.rbエコシステム、最新0.9.x）。Faraday依存のシンプルなAPIラッパー。ActiveRecord統合は提供されない[^qdrant-ruby]
- **Docker Compose構成**: 単一コンテナ追加で完結

### 5. Weaviate

- **最新バージョン**: v1.37.2（2026年4月23日）[^weaviate-gh]
- **ライセンス**: BSD-3-Clause[^weaviate-gh]
- **言語**: Go
- **類似度指標**: Cosine（既定）、Dot、L2-squared、Hamming、Manhattan[^weaviate-distances]
- **インデックス方式**: HNSW[^weaviate-gh]
- **Docker Compose構成**: 公式ドキュメントは Weaviate本体 + 任意の埋め込みモデルサービスの2サービス構成を提示[^weaviate-gh]
- **Rails向けgem**: `weaviate-ruby`（patterns-ai-core、最新0.9.2 / 2024年10月）。コミュニティ製で公式ではない。`weaviate_record` というActiveRecord風ORMも存在[^weaviate-ruby]
- **特徴**: ハイブリッド検索・RAG・マルチテナンシー等の高機能を持つが、本デモのスコープには過剰

### 6. Chroma

- **最新バージョン**: 1.5.9（2026年5月5日）[^chroma-gh]
- **ライセンス**: Apache 2.0[^chroma-gh][^chroma-license]
- **言語**: Rust（68.1%）+ Python + TypeScript[^chroma-gh]
- **類似度指標**: Squared L2（既定）、Cosine、Inner Product[^chroma-distances]
- **インデックス方式**: 単一ノード版はHNSW、分散・Cloud版はSPANN[^chroma-distances]
- **Docker提供**: あり（`chromadb/chroma`、Docker Hub および ghcr.io）[^chroma-docker]
- **Rails向けgem**: `chroma-db`（mariochavez作）、`chromable`（AliOsm作、Rails統合・after_save / after_destroy callbackで埋め込みを自動管理）[^chromable]
- **Docker Compose構成**: 単一コンテナ追加で完結

### 7. Milvus Lite

- **形態**: Pythonライブラリ（SQLite的に組み込み利用）[^milvus-overview]
- **ライセンス**: Apache 2.0[^milvus-overview]
- **適用範囲**: 100万ベクトル未満のプロトタイピング・エッジデバイス向け[^milvus-overview]
- **Rails親和性**: Pythonライブラリのため、Rails（Ruby）から直接利用するにはサブプロセス呼び出しまたはPython製サイドカー経由が必要。**Rails題材としては不適合**

### 8. Milvus Standalone

- **形態**: Docker Composeで自己ホスト（multi-container）[^milvus-standalone]
- **ライセンス**: Apache 2.0[^milvus-overview]
- **Docker Compose構成**: milvus-standalone、milvus-minio、milvus-etcd の3コンテナ構成（MinIOはオブジェクトストレージ、etcdはメタデータ管理）[^milvus-standalone]
- **Rails向けgem**: 公式・主要なRubyクライアントは確認できず。HTTP/gRPC API直叩きまたは非公式ラッパーが必要
- **判定**: 20〜50件規模に対して構成が明らかに過大。記事執筆時の説明コストも大きい

### 9. neighbor gem の線形走査モード

- **gem**: ankane/neighbor[^neighbor-gh]
- **ライセンス**: MIT[^neighbor-gh]
- **対応バックエンド**: PostgreSQL（cube、pgvector）、MariaDB 11.8、MySQL 9（HeatWave、experimental）、SQLite（sqlite-vec、experimental）[^neighbor-gh]
- **重要点**: neighbor は「Rails用のNN検索抽象化」であり、独立したベクター保管層ではない。PostgreSQLの `cube` 拡張モードでは pgvector 不要で線形走査が可能だが、`cube` は最大100次元の制約があり[^cube-pg]、現代の埋め込みモデル（典型的に384〜1536次元）には適合しない
- **判定**: 「pgvector非依存の純Rails内ベクター検索」は cube の次元制約により非現実的。neighbor gem は pgvector または sqlite-vec と組み合わせる前提で評価すべき

## 分析・考察

### 主要な発見

1. **「Rails標準のRDBをそのまま使える」候補は pgvector が突出**
   既存のPostgreSQLサービスのイメージを差し替えるだけで導入でき、ActiveRecord・マイグレーション・SQLという既存知識の延長で説明できる。Rails開発者の認知負荷が最も小さい。

2. **sqlite-vec は pre-v1 でリスクあり**
   破壊的変更の警告がREADMEに明記されており[^sqlitevec-gh]、Zenn記事として公開する場合、記事公開後の互換性破綻リスクがある。後援企業が多く将来性は期待できるが、現時点では「読者が追体験するときに動かない」リスクが pgvector より高い。

3. **専用ベクターDB（Qdrant, Weaviate, Chroma）は単一コンテナで起動可能だが、Rails統合は薄い**
   いずれも Apache 2.0 / BSD-3 で OSS としての信頼性は高く、Docker Compose に1コンテナ追加するだけで動く。一方、Rubyクライアントはコミュニティ製で、ActiveRecord的な統合（after_commit でのインデックス更新等）はChromaの `chromable` を除いて自前実装が必要となる。記事内で「Rails標準の流儀から外れた配線コード」を解説する負担が増える。

4. **Milvus はオーバーキル**
   Standaloneは3コンテナ構成、LiteはPythonライブラリでありRailsに直接統合できない。20〜50件規模かつRails題材としては不適合。

5. **sqlite-vss は新規採用候補から除外**
   作者本人が sqlite-vec に移行を明言している。

### 技術的評価

| 評価項目 | pgvector | sqlite-vec | Qdrant | Weaviate | Chroma | Milvus Standalone |
|----------|----------|-----------|--------|----------|--------|-------------------|
| 追加コンテナ要否 | 不要（既存Postgresを差し替え） | 不要（ファイルDB） | 1コンテナ | 1〜2コンテナ | 1コンテナ | 3コンテナ |
| 次元数上限 | 16,000（vector型） | 明示的記載なし | 公式ページで明示なし | 公式ページで明示なし | 明示的記載なし | （調査範囲外） |
| 主要類似度指標 | cosine / 内積 / L2 / L1 / hamming / jaccard | 線形走査でcosine等（neighbor経由） | cosine / dot / euclid / manhattan | cosine / dot / L2² / hamming / manhattan | L2² / cosine / 内積 | （調査範囲外） |
| インデックス方式 | HNSW / IVFFlat / 線形 | 線形走査中心、ANNは実験的 | HNSW | HNSW | HNSW | HNSW等 |
| Rails向け公式・準公式gem | neighbor（ankane） | neighbor（experimental） | qdrant-ruby（コミュニティ） | weaviate-ruby（コミュニティ、最終更新2024-10） | chroma-db / chromable（コミュニティ） | 主要クライアントなし |
| ライセンス | PostgreSQL License | Apache-2.0 / MIT | Apache 2.0 | BSD-3-Clause | Apache 2.0 | Apache 2.0 |
| 20〜50件規模での適合 | 適合 | 適合 | 適合だが過剰機能 | 適合だが過剰機能 | 適合だが過剰機能 | 過剰 |
| Zenn記事での説明しやすさ | 高（Rails標準の延長） | 中（SQLiteを使う前提が必要） | 中（別DBの概念導入が必要） | 中（同左） | 中（同左） | 低（多コンポーネント） |

### リスクと制約

- **pgvectorのリスク**: PostgreSQLのバージョンと拡張のビルド済みイメージが連動するため、Rails側で利用するPostgreSQLバージョンを固定する必要がある。ただしこれは追体験の安定性にむしろ寄与する
- **sqlite-vecのリスク**: pre-v1のため、記事公開後にAPI変更が起こると追体験が壊れる。バージョンを `Gemfile.lock` 同様に固定し、READMEで明示する必要がある
- **専用ベクターDB全般のリスク**: Rubyクライアントgemの保守がコミュニティ依存であり、長期的なメンテナンス保証がない（特にweaviate-rubyは2024年10月以降の更新が確認できない）
- **共通の制約**: 本調査ではパフォーマンス実測は行っていない。20〜50件規模ではいずれの候補も十分高速と推定されるが、定量的根拠は持たない

## 結論・推奨事項

### 結論

Zenn技術記事の題材としては、**pgvector** を第一推薦、**Qdrant** を第二推薦とする。

### 推奨事項

1. **第一推薦: pgvector + neighbor gem**
   - **理由**:
     - Rails開発者にとって最も馴染みのあるPostgreSQLの延長線上で説明できる（マイグレーションでカラム追加・インデックス追加、ActiveRecordで `has_neighbors`）
     - Docker Composeの構成変更が最小（既存のPostgresサービスイメージを `pgvector/pgvector:pg18-trixie` に差し替えるのみ）
     - PostgreSQL Licenseで配布制約が緩い
     - `neighbor` gem がRails標準の流儀（ActiveRecord、マイグレーション）と整合し、記事内のコード片を引用しやすい
     - HNSW・IVFFlat・線形走査の3方式を切り替えて比較する記事展開が可能（拡張記事の余地）
   - **期待効果**:
     - 読者の追体験コストが最小化される
     - 記事執筆時のコード解説が「Railsアプリにカラムを足してgemを入れる」というシンプルな構成に収まる

2. **第二推薦: Qdrant + qdrant-ruby**
   - **理由**:
     - 「専用ベクターDBとは何か」というテーマで記事化する場合、単一コンテナで完結し、HTTP APIが直感的
     - HNSW・複数の類似度指標・フィルタリング等、ベクターDB固有の機能を素直に紹介できる
     - Rust製で軽量、ライセンスもApache 2.0
   - **期待効果**:
     - 「Railsから外部のベクターDBを呼ぶ」パターンの提示が可能
     - 将来的なスケール（マネージドQdrant等への移行）への接続がしやすい
   - **採用条件**: 「Railsの外側にベクターDBを置くアーキテクチャを示すこと」自体が記事のテーマである場合

### 採否判断について

最終的な採否は ADR A-3「ベクターDB（物理層）の選定」に委ねる。本報告書は技術的事実と推薦根拠を提示するに留まり、Zenn記事のテーマ設定（「Rails内完結」「外部DB連携」のいずれを主軸とするか）と整合する選択を ADR で決定すること。

### 次のアクション

- [x] ADR A-3「ベクターDB（物理層）の選定」を起票し、本報告書を判断材料として参照する → [A-3](../adr/003-vector-database.md) で pgvector 採用を決定済み
- [x] PostgreSQL バージョンと `pgvector/pgvector` Docker タグを確定する → [A-3 「決定」セクション](../adr/003-vector-database.md)に内包して決定済み

## 関連資料

- [要件定義書](../requirements/requirements.md) — §3.4 未決事項、§3.2 ローカル動作制約
- [機能設計書](../functional-design/functional-design.md) — §2.1.3 物理層の前提、§6.3 抽象化の境界
- [用語集](../glossary/glossary.md) — 「ベクターDB」「埋め込みベクトル」「ANNインデックス」等
- [ADR A-3「ベクターDB（物理層）の選定」](../adr/003-vector-database.md)（本報告書を判断材料として作成済み）

## 参照したソースURL

[^pgvector-gh]: pgvector公式GitHub: https://github.com/pgvector/pgvector
[^pgvector-brew]: Homebrew Formulae - pgvector: https://formulae.brew.sh/formula/pgvector
[^sqlitevec-gh]: sqlite-vec公式GitHub: https://github.com/asg017/sqlite-vec
[^sqlitevss-gh]: sqlite-vss公式GitHub（メンテナンス停止）: https://github.com/asg017/sqlite-vss
[^qdrant-gh]: Qdrant公式GitHub: https://github.com/qdrant/qdrant
[^qdrant-collections]: Qdrant公式ドキュメント - Collections: https://qdrant.tech/documentation/concepts/collections/
[^qdrant-ruby]: qdrant-ruby gem: https://github.com/patterns-ai-core/qdrant-ruby
[^weaviate-gh]: Weaviate公式GitHub: https://github.com/weaviate/weaviate
[^weaviate-distances]: Weaviate公式ドキュメント - Distance metrics: https://docs.weaviate.io/weaviate/config-refs/distances
[^weaviate-ruby]: weaviate-ruby gem: https://github.com/patterns-ai-core/weaviate-ruby
[^chroma-gh]: Chroma公式GitHub: https://github.com/chroma-core/chroma
[^chroma-license]: Chroma LICENSEファイル: https://github.com/chroma-core/chroma/blob/main/LICENSE
[^chroma-distances]: Chroma公式ドキュメント - Configure: https://docs.trychroma.com/docs/collections/configure
[^chroma-docker]: Chroma Docker Hub: https://hub.docker.com/r/chromadb/chroma
[^chromable]: chromable gem - Rails統合: https://github.com/AliOsm/chromable
[^milvus-overview]: Milvus公式ドキュメント - Deployment options: https://milvus.io/docs/install-overview.md
[^milvus-standalone]: Milvus公式ドキュメント - Standalone Docker Compose: https://milvus.io/docs/install_standalone-docker-compose.md
[^neighbor-gh]: neighbor gem公式GitHub: https://github.com/ankane/neighbor
[^cube-pg]: PostgreSQL公式ドキュメント - cube拡張: https://www.postgresql.org/docs/current/cube.html

## 改訂履歴

| バージョン | 日付 | 変更内容 |
|------------|------|----------|
| 1.0 | 2026/05/06 | 初版作成 |
