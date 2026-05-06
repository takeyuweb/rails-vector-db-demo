# ADR 005: 類似度指標の決定

## ステータス

Proposed

## 日付

2026-05-06

## 信頼度

高

採用する埋め込みモデル（multilingual-e5-base）が L2 正規化済み出力（norm=1）であることを公式モデルカードで確認済み（[intfloat/multilingual-e5-base](https://huggingface.co/intfloat/multilingual-e5-base)）。単位ベクトル同士では cosine／inner product／L2 の3指標は同じ近傍順序を返すため、検索結果の品質はどれを選んでも変わらない。本決定の主たる根拠は「Zenn 記事の説明しやすさ」と「pgvector / neighbor の慣用表現との整合」であり、技術的な正解が複数あるなかから記事題材として最適なものを選ぶ判断であるため、確信度は高い。

## 再評価条件

- 採用する埋め込みモデルを A-2 で再決定し、出力が L2 正規化されていない（または明示的に inner product / L2 を推奨する）モデルに変更された場合
- ベクターDB を A-3 で pgvector 以外に変更し、新 DB のデフォルト指標が cosine 以外で、cosine 採用が記事の説明コストを増やす場合
- ブログ記事規模が拡大し（数十万件以上）、cosine 演算の正規化処理（ノルム計算）が無視できない CPU コストになった場合

## コンテキスト

本デモの類似検索は、ブログ記事の本文・タイトルから生成した埋め込みベクトルを格納し、クエリ文（または特定記事）から得たベクトルと最も近い上位 K 件を返す処理である（[要件定義書](../requirements/requirements.md)、[機能設計書](../functional-design/functional-design.md)）。「ベクトル間の近さ」を計算するための類似度指標は、以下の関連 ADR の決定を前提として選ぶ必要がある。

### 前提となる関連決定

- **A-2: 埋め込みモデル**: multilingual-e5-base 系を informers gem 経由で採用（[R-A 推奨案 1](../reports/r-a-embedding-models-comparison.md)）。E5 系は **公式モデルカードの利用例で `F.normalize(embeddings, p=2, dim=1)` による L2 正規化を行っている**（[multilingual-e5-base モデルカード](https://huggingface.co/intfloat/multilingual-e5-base)）。出力ベクトルは単位ベクトル（norm=1）である前提で扱う。
- **A-3: ベクターDB**: pgvector を採用（[R-B 推奨案 1](../reports/r-b-vector-db-comparison.md)）。pgvector は L2（`<->`）／負の内積（`<#>`）／コサイン距離（`<=>`）／L1（`<+>`）／ハミング／Jaccard をサポートし、HNSW インデックスは指標ごとに別の opclass（`vector_l2_ops` / `vector_ip_ops` / `vector_cosine_ops` 等）を使う（[pgvector README](https://github.com/pgvector/pgvector)）。
- **A-4: Rails 統合 gem**: neighbor gem を採用。`add_index ... using: :hnsw, opclass: :vector_cosine_ops` の形でマイグレーションに指標を記述し、検索時は `nearest_neighbors(:embedding, distance: "cosine")` のように指標を指定する（[neighbor README](https://github.com/ankane/neighbor)）。

### 数学的事実

L2 正規化済みベクトル u, v（||u||=||v||=1）について、3 指標は次の関係を満たす:

- `cosine_similarity(u, v) = u · v`（コサイン類似度 = 内積）
- `||u - v||² = 2 - 2(u · v)`（L2 距離の二乗 = 2 − 2×内積）
- いずれの指標も「u と v が近いほど」単調に変化するため、**top-K の順序は3指標で完全に一致する**

つまり「品質（検索結果の妥当性）」は3指標で同等であり、選定軸は **実装の素直さ・記事執筆時の説明コスト・将来の拡張性** に絞られる。

### 現状の問題点

- 類似度指標は「コサイン類似度」を直感的に使う読者が多い一方、pgvector の README やチュートリアルでは内積を例示することもあり、記事執筆時の表記選択が決まっていない
- マイグレーションの opclass、検索時の `distance:` パラメータ、用語集（[glossary.md](../glossary/glossary.md) §技術-ベクター検索の基礎概念）の表記を統一する必要がある

なお、本 ADR で言及する pgvector の演算子（`<=>` 等）は SQL レベルの距離計算演算子であり、用語集の禁止表現「クエリ単独」「検索クエリ」の対象とは別概念である。本 ADR 内で以後「クエリ」「SQL クエリ」と書く場合はいずれも SQL 文の意味を指す。

### 制約条件

- A-2 で確定する埋め込みモデルは L2 正規化済みである前提（E5 系の公式利用例に従う）
- pgvector の演算子・opclass・neighbor の `distance:` 引数の3層で指標表記を一貫させる
- 用語集に登録済みの「コサイン類似度」「内積」「ユークリッド距離」のいずれかを正式採用する

## 決定

**類似度指標として「コサイン類似度（cosine similarity）」を採用する。**

pgvector 上ではコサイン距離演算子 `<=>` を使用し、HNSW インデックスは `vector_cosine_ops` opclass で構築する。neighbor gem からは `nearest_neighbors(:embedding, distance: "cosine")` を経由して呼び出す。

### 実装方針

1. **マイグレーション**: 埋め込みベクトルは別テーブル `article_embeddings` に保持される設計（[機能設計書 §2.1.2](../functional-design/functional-design.md)、[A-3 §実装方針](./003-vector-database.md)）。インデックスは当該テーブルの `embedding` カラムに対して `opclass: :vector_cosine_ops` で作成する。
   ```ruby
   add_index :article_embeddings, :embedding, using: :hnsw, opclass: :vector_cosine_ops
   ```
2. **モデル**: `ArticleEmbedding` モデルで `has_neighbors :embedding, dimensions: 768, normalize: false` を宣言する（E5 出力が既に正規化済みのため、neighbor 側での再正規化は不要）。`dimensions` は A-2 で確定する次元数（base 採用時は 768）に揃える。
3. **検索**: `ArticleEmbedding.nearest_neighbors(:embedding, query_vector, distance: "cosine").limit(top_k)` の形で呼び出し、必要に応じて `joins(:article)` 等で記事属性を取得する。
4. **記事内表記**: 「コサイン類似度（値域 -1〜1、1 に近いほど類似）」と一貫して表記する。pgvector が返す値はコサイン**距離**（1 − cosine_similarity、0 に近いほど類似）であるため、距離と類似度の符号差は記事内で 1 度だけ明示する。
5. **正規化済み前提のドキュメント化**: 「E5 系は出力が L2 正規化済みのため、内積に切り替えても結果順序は同じである」旨を記事の補足コラムまたは付録で言及する（読者が他モデルへ差し替える際の参考情報）。

## 結果

### ポジティブな影響

1. **記事執筆時の認知コストが低い**
   - 「類似度」という語と「コサイン類似度」が直感的に対応する。読者が新たに「内積を距離として読む」「L2 距離を類似度に反転する」といった頭の切り替えを必要としない。
   - 用語集の「類似度」「コサイン類似度」の定義をそのまま利用できる。

2. **業界デファクトに沿う**
   - sentence-transformers / E5 / Ruri 等、多くの埋め込みモデルの公式ドキュメントが cosine similarity を例示する（[multilingual-e5-base モデルカード](https://huggingface.co/intfloat/multilingual-e5-base)）。読者が他資料を参照する際の連続性が保たれる。

3. **モデル差し替えに強い**
   - 将来 A-2 を見直して非正規化出力のモデル（または L2 距離前提のモデル）に変えた場合でも、コサイン類似度はノルムに依存しないため、記事の説明と実装が破綻しにくい。
   - 他方、内積を採用すると「正規化済み前提」が暗黙の制約となり、モデル差し替え時に検索品質が劣化する罠がある。

4. **pgvector / neighbor で一級サポート**
   - `<=>` 演算子と `vector_cosine_ops` opclass、neighbor の `distance: "cosine"` がいずれも公式の第一級 API として提供されている（[pgvector README](https://github.com/pgvector/pgvector)、[neighbor README](https://github.com/ankane/neighbor)）。

### ネガティブな影響・トレードオフ

1. **コサイン演算は内積よりわずかに計算量が多い**
   - cosine 距離は内部で両ベクトルのノルム計算（`sqrt(sum(x²))`）を必要とする。E5 出力は正規化済みのため、理論上は内積で十分であり、cosine の追加計算はオーバーヘッドである。
   - 対策: 本デモは 20〜50 件規模（[要件定義書 §5 受入条件](../requirements/requirements.md)）で、ノルム計算のコストは検索全体のレイテンシに対して無視できる。実規模で問題化した場合は、再評価条件に従い ADR を新規作成して内積へ切り替える。

2. **「距離」と「類似度」の符号差を読者に説明する手間**
   - pgvector / neighbor が返す値は cosine **距離**（1 − cosine_similarity）であり、用語集の「類似度」（1 に近いほど類似）と符号方向が逆になる。
   - 対策: 記事内で 1 度だけ「pgvector の cosine 距離 = 1 − コサイン類似度」と明示し、UI 表示やログ出力では類似度に変換する方針を明文化する。

3. **「内積で十分なのになぜ cosine か」というツッコミの余地**
   - 技術的厳密性を重視する読者から、「正規化済みなら内積のほうが自然」という指摘を受ける可能性がある。
   - 対策: 本 ADR の「コンテキスト > 数学的事実」を記事内コラムとして引用し、「3 指標は同順序で、cosine を選ぶのは説明しやすさを優先したため」と明記する。

## 代替案

### 案1: 内積（inner product）

**概要**: pgvector の `<#>` 演算子（負の内積を返す）と HNSW `vector_ip_ops` opclass、neighbor の `distance: "inner_product"` を使う。

**メリット**:
- E5 出力は L2 正規化済みのため、ノルム計算が不要で計算量が最小
- pgvector のドキュメントや `vector` 拡張のチュートリアルで内積の使用例が示されることがある
- 単位ベクトル前提なら cosine と数学的に等価で、検索順序は変わらない

**デメリット**:
- pgvector の `<#>` は **負の内積**を返す（PostgreSQL が `ASC` 順インデックススキャンしかサポートしないための実装上の都合）。記事内で「結果に -1 を掛けて反転する」「距離として読み替える」説明が必要になり、初学者の認知コストが増える（[pgvector README](https://github.com/pgvector/pgvector)）
- 「正規化済み前提」が暗黙の制約となり、モデル差し替え時の罠が生じる
- 用語集の「類似度」と直接結びつかず、別途「内積を類似度として使う」前置きが要る

**却下理由**: 計算量上のメリットは本デモ規模では誤差レベル。一方、「負の内積」「正規化済み前提の暗黙制約」「用語との不整合」という3つの説明コストが Zenn 記事の流れを乱す。記事題材としての適合性が低い。

### 案2: ユークリッド距離（L2）

**概要**: pgvector の `<->` 演算子と HNSW `vector_l2_ops` opclass、neighbor の `distance: "euclidean"` を使う。

**メリット**:
- 「距離」という直感的な概念で、幾何学的なイメージがつかみやすい読者がいる
- pgvector のデフォルト指標として README の冒頭例示で使われており、最初に出会う読者も多い
- 単位ベクトル前提なら cosine と等価な順序を返す

**デメリット**:
- L2 距離は値域が `[0, 2]`（単位ベクトル同士の場合）で、「1 に近いほど類似」「0 に近いほど類似」のどちらの慣用とも合わず、UI 表示で正規化や反転が必要になる
- 用語集の「類似度」（高いほど類似）と方向が逆で、記事内で「距離 → 類似度」の変換ロジックを別途解説する必要がある
- 単位ベクトル前提を外れると（モデル差し替え時等）、ベクトルの絶対的な長さの差が距離に混入し、cosine と結果が大きく乖離する。読者が他モデルを試す際のリスクが大きい

**却下理由**: 「類似度」を主軸に据える本デモの用語設計と整合せず、UI・ログ表示で距離→類似度の変換を強いる。モデル差し替え時の挙動も最も不安定で、Zenn 記事の汎用解説には不向き。

### 案3: 現状維持（指標を決めない）

**概要**: 指標を ADR で固定せず、実装フェーズで都度判断する。

**メリット**: 後続の PoC 結果に応じて柔軟に変更できる

**デメリット**:
- マイグレーション・モデル宣言・検索 SQL・用語集・記事内表記の5箇所で指標表記が分散し、整合性が取れない
- Zenn 記事の説明軸（「類似度」を中心に据えるかどうか）が定まらず、要件定義書・用語集との接続が曖昧になる

**却下理由**: ADR の目的（決定事項の固定化）を満たさず、後続フェーズの一貫性を阻害する。

## 関連 ADR・関連調査報告書

- [ADR 002: 埋め込みモデルと実行基盤の選定（A-2）](./002-embedding-model-and-runtime.md)
- [ADR 003: ベクターDB の選定（A-3）](./003-vector-database.md)
- [ADR 004: Rails 統合 gem の選定（A-4）](./004-rails-integration-gem.md)
- [調査報告書 R-A: 埋め込みモデルと実行基盤の比較](../reports/r-a-embedding-models-comparison.md)
- [調査報告書 R-B: ベクターDB の比較](../reports/r-b-vector-db-comparison.md)
- [用語集](../glossary/glossary.md) — 「類似度」「コサイン類似度」「内積」「ユークリッド距離」の正式表記
- [要件定義書](../requirements/requirements.md) — §3.4 ADR 委譲事項
- [機能設計書](../functional-design/functional-design.md) — 類似検索処理の抽象インターフェース

## 参考資料

- [intfloat/multilingual-e5-base モデルカード](https://huggingface.co/intfloat/multilingual-e5-base) — L2 正規化の前提とコサイン類似度の利用例
- [pgvector 公式 README](https://github.com/pgvector/pgvector) — 距離演算子（`<=>`、`<#>`、`<->` 等）と HNSW opclass（`vector_cosine_ops`、`vector_ip_ops`、`vector_l2_ops`）の対応、`<#>` が負の内積を返す仕様
- [neighbor gem 公式 README](https://github.com/ankane/neighbor) — `add_index ... using: :hnsw, opclass: :vector_cosine_ops` の指定方法、`nearest_neighbors(..., distance: "cosine")` の検索 API
- [MMTEB 論文（arXiv:2502.13595）](https://arxiv.org/abs/2502.13595) — multilingual-e5 系の評価ベンチマーク（cosine similarity を前提とした評価）
