# ADR 002: 埋め込みモデルと実行基盤の選定

## ステータス

提案中（Proposed）

## 日付

2026-05-06

## 信頼度

中

informers から `Xenova/multilingual-e5-base` を読み込んで日本語入力で埋め込みベクトルが取得できることは、informers の「ONNX を含む任意のモデルを `model_file_name` で読み込める」仕様と Xenova 配下の ONNX 公式配布から強く期待できるが、informers 公式 README にこの組み合わせの動作実例は記載されておらず、実機検証は未実施である。実装着手直後の PoC で動作確認することを採用条件とする。

## 再評価条件

以下のいずれかが発生した場合、本決定を見直す。

- PoC で informers から `Xenova/multilingual-e5-base` を呼び出した際に、日本語入力で 768 次元ベクトルが取得できない、または推論時間が ActiveJob ジョブとして許容できない（具体閾値は PoC 時に設定）。
- ruri v3 系または plamo-embedding-1b について、第三者または公式の ONNX 変換版が安定提供され、informers から追加変換なしで読み込める状態になった。
- 「日本語埋め込み品質を最大化する」という記事メッセージへ方針転換し、Python サイドカー方式の解説に紙幅を割くことを許容するようになった。
- Xenova の HuggingFace アカウントの ONNX 配布が停止または改変され、再現性が失われた。
- informers gem の保守が停止した、または `intfloat/multilingual-e5` 系統の利用に支障のある破壊的変更が行われた。

## コンテキスト

本デモは「Rails 標準機能と埋め込みベクトルによる類似検索の組み合わせ方を、Zenn 技術記事の題材として動作する形で示す」ことを目的とする（[要件定義書](../requirements/requirements.md) §1）。要件定義書 §3.2 で「埋め込みベクトル生成および類似度計算を含む全機能が、外部APIに依存せずローカルで完結すること」が制約として明示されている。また機能設計書 §6.2.1 では `EmbeddingModel` を抽象インターフェースとして定義し、その具体実装の選定を本 ADR に委ねている。

埋め込みベクトル生成は本デモの中核処理であり、選定が決まらない限り `ArticleEmbeddingJob` の実装、`embedding` カラムの次元、`model_identifier` の文字列形式、Docker Compose 構成が確定しない。下流の意思決定（ベクターDB の次元設定、類似度指標、Rails 統合 gem の組み合わせ）も本決定に依存する。

### 現状の問題点

- 採用すべき埋め込みモデルとその実行基盤が未確定であり、機能設計書 §2.1.2（`embedding` 次元）、§3.1（トークン上限超過時の方針）、§6.2.1（`EmbeddingModel` 実装）が宙に浮いている。
- ローカル動作必須・Ruby から呼び出し可能・記事題材として説明しやすい、の 3 条件を同時に満たす組み合わせが自明ではない。日本語品質の高い ruri / plamo は公式 ONNX 配布がなく Ruby から直接利用しにくい一方、Ruby から最も呼びやすい multilingual-e5 系は日本語特化モデルに対して JMTEB 上のスコアで劣る。
- `model_identifier` の文字列形式が定まっていないため、再生成バッチの判別ロジック（機能設計書 §4.2.4）が確定できない。
- 埋め込みモデルのトークン上限を超える本文の扱いが未定で、`ArticleEmbeddingJob` の実装に判断不能な箇所が残っている。

### 制約条件

- ローカル動作必須（要件定義書 §3.2）。外部 API 呼び出しは不可。
- Docker Compose 内で完結すること（要件定義書 §3.1）。追体験者は `docker compose up` 相当で動作環境を再現できる必要がある。
- Ruby（Rails アプリのプロセス）から呼び出せること。機能設計書 §6.2.1 の `EmbeddingModel` インターフェースに適合する形で組み込めること。
- 商用利用および記事中でのコード公開に支障のないライセンス（OSI 承認の許容ライセンス）であること。
- 日本語のブログ記事 20〜50 件規模で「明らかに関連する記事が上位に来る」水準の検索品質が得られること（要件定義書 §5）。

## 決定

以下を採用する。

1. **埋め込みモデル**: `intfloat/multilingual-e5-base`（ONNX 配布版である `Xenova/multilingual-e5-base` を読み込む）。出力次元 **768**、最大入力 512 トークン、ライセンス MIT。量子化は適用せず **fp32** で利用する。
2. **実行基盤**: Ruby gem `informers`（[ankane/informers](https://github.com/ankane/informers)、Apache 2.0、ONNX Runtime ベース）。Rails アプリと同一プロセスで `EmbeddingModel` 実装が `informers` を直接呼び出す。Python サイドカーは導入しない。
3. **トークン上限超過時の処理**: 入力テキストはモデル側のトークナイザに渡し、**上限超過時はトークナイザによる末尾側 truncation（先頭 512 トークンを保持し末尾を切り捨て）に任せる**（HuggingFace Transformers 標準の `truncation_side="right"`、`truncation: true` 相当）。アプリケーション側で事前にトークン数をカウントしての分割・要約は行わない。
4. **`model_identifier` の文字列形式**: `<HF リポジトリ名>@<revision>` 形式とする。本決定での具体値は **`Xenova/multilingual-e5-base@<commit-sha>`**（`<commit-sha>` は導入時に固定したフルコミット SHA）。同一論理モデルの fp16/int8 等のバリアントを将来追加する場合は `?dtype=<dtype>` をクエリ風サフィックスとして付与する規約を予約する（例: `Xenova/multilingual-e5-base@abc123…?dtype=q8`）。

### 実装方針

1. `Gemfile` に `informers` を追加し、`bundle install` で依存解決する。下回りの `onnxruntime` gem はトランジティブに導入される。
2. `EmbeddingModel` の具体実装クラス（例: `Embeddings::InformersMultilingualE5Base`）を作成し、`informers` の embedding パイプラインで `Xenova/multilingual-e5-base` を初回呼び出し時にロードする（プロセス内でモデルを保持し、リクエスト毎の再ロードを避ける）。
3. 入力前処理として、e5 系モデルの規約に従い検索対象テキスト（記事本文）には `passage: ` プレフィックスを、クエリ文には `query: ` プレフィックスを付与する。プレフィックス付与は `EmbeddingModel` 実装の責務とする（呼び出し側は意識しない）。
4. 出力ベクトルは正規化したものを返す（コサイン類似度との親和性のため。最終的な類似度指標は ADR A-5 で確定するが、L2 正規化済みベクトルで保持しておけばコサイン類似度・内積のいずれでも追加処理なしで利用可能）。
5. モデルファイル（ONNX）は Docker イメージビルド時に事前ダウンロードする（[Predownloading embedding models in Rails with Kamal](https://nts.strzibny.name/predownload-embed-models-kamal/) と同様の方針）。これにより、実行時のオフライン動作と起動レイテンシの安定を両立する。
6. `model_identifier` は実装クラス内で定数または設定値として保持し、`ArticleEmbedding#model_identifier` に毎回書き込む。`<commit-sha>` を含めることで、同名タグでモデルが差し替わるリスクを排除する。
7. PoC として、本 ADR 承認直後に「`informers` から `Xenova/multilingual-e5-base` を読み込み、日本語サンプル文（記事本文相当）で 768 次元ベクトルが取得できる」ことを最小スクリプトで確認する。失敗時は本 ADR を「却下」に変更し、後続の代替案（informers + multilingual-e5-small へのフォールバック、または Python サイドカーへの切り替え）を別 ADR として起票する。

## 結果

### ポジティブな影響

1. **追体験性が高い**
   - `bundle install` と `docker compose up` のみで動作する単一プロセス構成となり、Python ランタイムや別コンテナの導入が不要。Zenn 記事の読者はリポジトリをクローンするだけで再現できる。
2. **記事の主題から逸れない**
   - 「Rails ↔ Python サイドカー」のような連携設計の解説が不要となり、Rails 標準機能（CRUD・ActiveJob・Hotwire）と pgvector/neighbor 等の組み合わせ方に紙幅を集中できる。
3. **公式エコシステムの一次資料が揃っている**
   - `informers`・`onnxruntime`・`neighbor` はいずれも ankane の保守下にあり、組み合わせ例が公式 README に存在する。記事の各ステップから一次資料へのリンクで誘導できる。
4. **ライセンス的に明快**
   - モデル（MIT）・gem（Apache 2.0）・ONNX 配布（Apache 2.0 / MIT 系）すべてが OSI 承認の許容ライセンスであり、記事公開・コード公開のいずれにも障害がない。
5. **ANN インデックスとの親和性**
   - 768 次元固定長ベクトルは pgvector の HNSW / IVFFlat や他の主要な ANN ライブラリで標準的に扱える次元帯であり、ADR A-3（ベクターDB 選定）の選択肢を狭めない。
6. **日本語多言語ベンチでの実績**
   - `multilingual-e5-base` は Mr. TyDi 日本語で MRR@10 = 56.6（[モデルカード](https://huggingface.co/intfloat/multilingual-e5-base)）であり、20〜50 件規模で「明らかに関連する記事が上位に来る」水準には届くと判断できる。
7. **`model_identifier` のリビジョン固定で再現性を担保**
   - HF リポジトリ名 + コミット SHA で識別することで、上流のサイレントな差し替えが起きても本デモの埋め込みは固定モデルで生成されたことが追跡できる。再生成判別ロジック（機能設計書 §4.2.4）も単純な文字列一致で実装可能。

### ネガティブな影響・トレードオフ

1. **日本語特化モデル比でスコア劣後**
   - JMTEB スコア上は ruri v3-310m（77.24）や plamo-embedding-1b（76.10）が上位だが、`multilingual-e5-base` の同条件スコアは公開されておらず、定量比較は不能。
   - **対策**: 本デモは「20〜50 件規模で明らかに関連する記事が上位に来ること」を受入条件とし、ベンチマーク順位ではなく体感品質で評価する。読者向けには記事内で「より高い日本語品質を求めるなら ruri / plamo + Python サイドカー」という選択肢を補足として明記する。
2. **CPU 推論のレイテンシは実測未確認**
   - `informers` README にレイテンシ記載がなく、ActiveJob 1 件あたりの推論時間は実機で確認するまで不明。
   - **対策**: PoC 時に推論時間を計測し、許容できない場合は `multilingual-e5-small`（384 次元）へのダウングレードを検討する（軽量な代替パスとして残しておく）。
3. **トークン上限 512 を超える長文記事は末尾が落ちる**
   - 先頭 512 トークン分の意味のみで埋め込みベクトルが構成されるため、記事末尾の重要キーワードが反映されない可能性がある。
   - **対策**: 本デモはブログ記事 20〜50 件・短文中心を前提とし、追加対策は導入しない。トークン上限超過の発生頻度と影響は seed データで観察し、目立つ劣化があれば別 ADR で「先頭 N トークン切り出し」「タイトル + 本文先頭 + 本文末尾の合成」等を再検討する。
4. **informers + multilingual-e5 の動作は公式に保証されていない**
   - 公式 README は英語モデルの例示が中心で、当組み合わせの動作実例は確認できていない（リスク R-1）。
   - **対策**: 実装着手直後に PoC を実施し、失敗時は本 ADR を「却下」に変更して別 ADR で代替案を起票する。失敗確率を見積もるための一次情報がないため、影響度の大きさに対し対応はフォールバック準備に限定する。
5. **`model_identifier` にコミット SHA を含めるため見た目が冗長**
   - `Xenova/multilingual-e5-base@a1b2c3d4e5f6…` のような長い文字列が `ArticleEmbedding` の各行に保持される。
   - **対策**: ストレージコストは無視できる（数十バイト × 50 行 = 2KB 未満）。可読性が問題になる場面ではログ・画面表示時に短縮 SHA（先頭 7 文字）にトリミングする運用で吸収する。

### PoC で確認すべき事項

実装着手直後に以下を最小スクリプトで検証する。

1. `informers` から `Xenova/multilingual-e5-base` を読み込み、エラーなく初期化できる。
2. 日本語サンプル文（500 文字程度のブログ記事相当テキスト）を入力し、長さ 768 の浮動小数配列が返る。
3. `passage: ` プレフィックス付き文と `query: ` プレフィックス付き文の埋め込みベクトル間でコサイン類似度を計算し、意味的に近いペアの方が高い値を示す（最低限の動作妥当性確認）。
4. 1 件あたりの推論時間を計測し、ActiveJob のジョブとして許容できる範囲（目安: 単一記事処理で数百 ms〜数秒以内）に収まる。
5. トークン上限 512 を超える長文を入力し、トークナイザによる truncation で例外なく処理が完了する。
6. ONNX モデルファイルがビルド時に取得できる経路（HF ハブからのダウンロード）と、取得後にオフラインで再現できることを確認する。

## 代替案

### 案1: ruri v3-310m（または v3-30m）を Ruby から利用

**概要**: 日本語特化の cl-nagoya/ruri v3 系モデルを採用し、informers または red-candle 等から呼び出す。

**メリット**:
- JMTEB 平均で 77.24（v3-310m）と、本調査範囲で最高水準の日本語埋め込み品質。
- Apache 2.0 ライセンスで商用・記事公開ともに障害なし。
- 最大 8,192 トークン対応で、長文記事の truncation 問題が事実上発生しない。

**デメリット**:
- 公式 ONNX 配布が確認できず、informers から直接読み込めない（[R-A §A-2](../reports/r-a-embedding-models-comparison.md)）。第三者 ONNX 変換版も本調査時点では未確認。
- HuggingFace 標準形式（safetensors）で利用するには transformers-ruby（Torch.rb 経由）が必要となり、Docker イメージサイズと初期セットアップコストが膨らむ。

**却下理由**: 「Ruby から追加変換なしで利用可能」という追体験性の中核要件を満たさない。記事の読者に ONNX 自前変換を要求する手順が増えると、本デモの「Rails 標準と組み合わせる」という主題から外れた前段の作業が長くなる。

### 案2: plamo-embedding-1b を Python サイドカーで利用

**概要**: pfnet/plamo-embedding-1b を Python プロセスで起動し、Rails から HTTP/gRPC で呼び出す。

**メリット**:
- JMTEB 平均 76.10 で日本語品質が高い。`encode_query()` / `encode_document()` がモデル側に組み込まれており、プレフィックス付与の責務をクライアント側に持たせなくて済む。
- Apache 2.0（商用可）。

**デメリット**:
- Docker Compose に Python コンテナを追加する必要があり、構成の単純さが失われる。
- 1B パラメータ・2048 次元はクラス最大級で、CPU 推論時のメモリ・レイテンシコストが他モデルより大きい（公式数値非公開、実測要）。
- `trust_remote_code=True` を要するカスタム実装で、ONNX 化や Ruby 系 gem からの直接利用は実質不可能。Rails 単体構成に組み込めない。
- 記事の主題が「Rails ↔ Python サービス連携」にずれ、ベクター検索本体の解説に割ける紙幅が減る。

**却下理由**: 「Rails 内で完結する」という追体験性とメッセージ性を犠牲にしてまで採用する根拠（本デモの 20〜50 件規模で品質差が体感できるか）が薄い。本デモのスコープでは過剰仕様。

### 案3: red-candle gem + 対応モデル

**概要**: scientist-labs/red-candle（Rust + Candle ベース）を採用し、対応する埋め込みモデル（Jina BERT / MiniLM / DistilBERT / 標準 BERT 系）から日本語に耐えうるものを選ぶ。

**メリット**:
- Rust 実装で informers より高速な可能性（自社主張、第三者ベンチ未確認）。
- Metal / CUDA アクセラレータ対応で、対応 GPU を持つ開発者には恩恵が大きい。
- MIT ライセンス。

**デメリット**:
- 埋め込みは safetensors のみ対応で ONNX 量子化版の恩恵を受けられない。
- multilingual-e5（XLM-R 系）が安定動作するかは未確認。標準 BERT 系のみのサポートでは、英語特化モデル中心となり日本語品質が確保できない。
- Rust toolchain のビルド要件で Docker イメージが膨らむ。
- v1.7.1（2026/04 リリース）で安定性の蓄積が乏しく、躓いた際の検索性が低い。

**却下理由**: Linux/Docker Compose を前提とする本デモでは Metal 加速の恩恵が活きず、Rust ビルドコストを払う合理性が薄い。日本語に適したモデルのサポート可否が未確認である点もリスクが大きい。

### 案4: Python サイドカー（sentence-transformers）+ 任意のモデル

**概要**: Rails と別プロセスで Python の sentence-transformers を起動し、HTTP/gRPC で呼び出す。モデルは ruri / multilingual-e5 / bge-m3 等から自由選択。

**メリット**:
- Python エコシステムの全モデルが選択肢になり、日本語品質を最大化できる。
- HuggingFace の最新研究成果を即座に取り込める。

**デメリット**:
- Docker Compose に Python コンテナを追加。構成が複雑化する。
- 「Ruby/Rails 内で完結」というメッセージ性が失われる。
- HTTP/gRPC のシリアライズ・通信オーバーヘッドが発生する（数 ms オーダー、本デモでは無視可能だが、ローカル直呼びより遅い）。

**却下理由**: 案 2 と同じく、本デモの追体験性とメッセージ性を犠牲にする規模の品質向上が必要なシナリオではない。

### 案5: llama_cpp.rb gem + GGUF 形式の埋め込みモデル

**概要**: yoshoku/llama_cpp.rb（llama.cpp バインディング）を採用し、GGUF 形式の埋め込みモデルを利用。

**メリット**:
- llama.cpp の量子化により低メモリ動作が可能。
- MIT ライセンス。

**デメリット**:
- llama.cpp 本体の事前インストールが必要で、Docker Compose で完結させるには追加ビルドステップが要る。
- gem README は LLM のテキスト生成例のみで、埋め込み API の例示が確認できない。
- multilingual-e5 / ruri / plamo はいずれも公式 GGUF 配布なし。GGUF 化された日本語対応埋め込みモデルは限定的。

**却下理由**: セットアップ容易性と日本語対応モデルの選択肢の双方で informers に劣る。

## 関連 ADR

- ADR A-3「ベクターDB（物理層）の選定」: 本決定の出力次元 768 は ADR A-3 の選定対象（pgvector 等）にとって標準的な次元帯であり、ANN インデックスのパラメータ選定に影響する。
- ADR A-4「Rails 統合方式（gem）の選定」: 本決定で採用する `informers` は、`neighbor` gem 等の Rails 統合 gem との組み合わせ前提となる。
- ADR A-5「類似度指標の選定」: 本決定で出力ベクトルを L2 正規化することにより、コサイン類似度・内積のいずれを採用しても追加処理なしで利用可能となる。

## 関連調査報告書

- [R-A: ローカル動作可能な埋め込みモデルと実行基盤の比較](../reports/r-a-embedding-models-comparison.md) — 本 ADR の根拠調査。

## 参考資料

### モデル

- intfloat/multilingual-e5-base モデルカード: https://huggingface.co/intfloat/multilingual-e5-base
- Xenova/multilingual-e5-base（ONNX 配布）: https://huggingface.co/Xenova/multilingual-e5-base
- Xenova/multilingual-e5-small（ONNX 配布、フォールバック候補）: https://huggingface.co/Xenova/multilingual-e5-small
- cl-nagoya/ruri v3 コレクション: https://huggingface.co/collections/cl-nagoya/ruri-v3
- cl-nagoya/ruri-v3-310m モデルカード: https://huggingface.co/cl-nagoya/ruri-v3-310m
- pfnet/plamo-embedding-1b モデルカード: https://huggingface.co/pfnet/plamo-embedding-1b
- BAAI/bge-m3 モデルカード: https://huggingface.co/BAAI/bge-m3

### 実行基盤

- ankane/informers: https://github.com/ankane/informers
- informers README: https://github.com/ankane/informers/blob/master/README.md
- ankane/onnxruntime-ruby: https://github.com/ankane/onnxruntime-ruby
- ankane/transformers-ruby: https://github.com/ankane/transformers-ruby
- ankane/neighbor: https://github.com/ankane/neighbor
- scientist-labs/red-candle: https://github.com/scientist-labs/red-candle
- yoshoku/llama_cpp.rb: https://github.com/yoshoku/llama_cpp.rb

### 評価・運用

- MMTEB 論文（arXiv:2502.13595）: https://arxiv.org/abs/2502.13595
- Ruri 論文（arXiv:2409.07737）: https://arxiv.org/abs/2409.07737
- JMTEB 評価リポジトリ: https://github.com/sbintuitions/JMTEB
- Predownloading embedding models in Rails with Kamal: https://nts.strzibny.name/predownload-embed-models-kamal/

### プロジェクト内文書

- [要件定義書](../requirements/requirements.md) — 特に §3.2 ローカル動作制約、§3.4 ADR 委譲事項、§5 受入条件
- [機能設計書](../functional-design/functional-design.md) — 特に §2.1.2 `ArticleEmbedding`、§3.1 埋め込みベクトル生成、§4.2.4 model_identifier 運用、§6.2.1 `EmbeddingModel`
- [用語集](../glossary/glossary.md) — 「埋め込みベクトル」「埋め込みモデル」「クエリ文」の正式表記

## 改訂履歴

| バージョン | 日付 | 変更内容 |
|------------|------|----------|
| 1.0 | 2026-05-06 | 初版作成（Proposed）。R-A の推奨案 1 を採用。 |
