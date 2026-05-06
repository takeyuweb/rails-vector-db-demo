# R-A: ローカル動作可能な埋め込みモデルと実行基盤の比較

**作成日**: 2026/05/06
**ステータス**: Draft
**調査担当**: 調査報告書作成サブエージェント
**関連ADR**: [A-2「埋め込みモデルと実行基盤の選定」](../adr/002-embedding-model-and-runtime.md)

## 概要

### 調査の背景

本デモは「Rails 標準機能と埋め込みベクトルによる類似検索の組み合わせ方を、Zenn 技術記事の題材として動作する形で示す」ことを目的とする（[要件定義書](../requirements/requirements.md) §1）。要件定義書 §3.2 で「埋め込みベクトル生成および類似度計算を含む全機能が、外部APIに依存せずローカルで完結すること」が制約として明示されており、§3.4 にて採用する埋め込みモデルおよび実装方式の決定は ADR に委ねられている。

### 調査の目的

Ruby/Rails プロセスから呼び出せる「埋め込みモデル」と「実行基盤（Ruby gem またはサイドカー方式）」の組み合わせを比較し、ADR A-2 の判断材料を提供する。読者が記事を読んで自リポジトリで追体験できることを最重視するため、「日本語埋め込み品質」と「セットアップ容易性」「Rails からの呼び出しのしやすさ」「記事執筆・解説のしやすさ」を中心に評価する。

### 調査範囲

**埋め込みモデル候補**:
- intfloat/multilingual-e5（small / base / large）
- cl-nagoya/ruri 系（v3-30m / v3-70m / v3-130m / v3-310m）
- BAAI/bge-m3
- pfnet/plamo-embedding-1b
- 参考: 英語のみの sentence-transformers 系（all-MiniLM-L6-v2 等）

**実行基盤候補**:
- informers gem（ankane/informers、ONNX Runtime ベース）
- onnxruntime gem（ankane/onnxruntime-ruby、informers の下回り）
- transformers-ruby gem（ankane/transformers-ruby、Torch.rb ベース）
- red-candle gem（scientist-labs/red-candle、Rust + Candle ベース）
- llama_cpp.rb gem（yoshoku/llama_cpp.rb、llama.cpp バインディング）
- Python サイドカー（HTTP/gRPC、別プロセスで sentence-transformers を実行）

**スコープ外**:
- クラウド API（OpenAI Embeddings、Cohere、Vertex AI 等）— 要件定義書 §3.2 の「外部APIに依存しない」に反するため除外
- 実機ベンチマーク — 本調査は文献調査のみ。レイテンシ・メモリは公式情報および公開ベンチマークから引用する範囲にとどめ、実測値は ADR 段階の PoC で確認する

## 調査内容

### 調査方法

- 各 gem の GitHub リポジトリ README / RubyGems ページ
- HuggingFace モデルカード（モデル仕様・ライセンス・推奨プレフィックス・JMTEB / MTEB スコア）
- JMTEB（Japanese Massive Text Embedding Benchmark）公式リポジトリおよび論文
- Ruby/Rails で実際に埋め込みを使った第三者の記事
- 各情報源の URL は本書末尾「参照したソース URL の一覧」に列挙する

## 調査結果

### A. 埋め込みモデル

#### A-1. intfloat/multilingual-e5（small / base / large）

| 項目 | small | base | large |
|------|-------|------|-------|
| パラメータ数 | 約 118M | 約 278M | 約 560M |
| 出力次元 | 384 | 768 | 1024 |
| 最大トークン長 | 512 | 512 | 512 |
| ライセンス | MIT | MIT | MIT |
| 対応言語 | XLM-R 由来の100言語（日本語含む） | 同左 | 同左 |
| ONNX 公式配布 | あり（Xenova/multilingual-e5-small）[^e5small-onnx] | あり（Xenova/multilingual-e5-base）[^e5base-onnx] | あり（Xenova/multilingual-e5-large）[^e5large-onnx] |
| 推奨プレフィックス | `query: ` / `passage: ` | 同左 | 同左 |

- ライセンス・次元・最大長・プレフィックスは [intfloat/multilingual-e5-base モデルカード](https://huggingface.co/intfloat/multilingual-e5-base) による。
- Mr. TyDi ベンチマークでの日本語 MRR@10 は base モデルで 56.6（[同モデルカード](https://huggingface.co/intfloat/multilingual-e5-base)）。
- multilingual-e5-large-instruct（560M）は MMTEB 多言語タスクで平均 63.2 を獲得しており、Mistral-7B などより大きなモデルを上回る（[MMTEB 論文 arXiv:2502.13595](https://arxiv.org/abs/2502.13595)）。
- 「base モデル < ruri-base」「large 級 < ruri-large/plamo」という日本語特化モデルとの比較は次項以降で示す。

#### A-2. cl-nagoya/ruri v3 系

ModernBERT-Ja を基盤とした日本語特化の汎用テキスト埋め込みモデル。サイズ別に v3-30m / v3-70m / v3-130m / v3-310m が公開されている（[Ruri v3 コレクション](https://huggingface.co/collections/cl-nagoya/ruri-v3)）。

| 項目 | v3-30m | v3-70m | v3-130m | v3-310m |
|------|--------|--------|---------|---------|
| パラメータ数 | 37M | 70M（参考値） | 130M（参考値） | 315M |
| 出力次元 | 256 | 384 | 512 | 768 |
| 最大トークン長 | 8,192 | 8,192 | 8,192 | 8,192 |
| ライセンス | Apache 2.0 | Apache 2.0 | Apache 2.0 | Apache 2.0 |
| JMTEB 平均 | 74.51 | （未確認） | （未確認） | 77.24 |

- 30m / 310m のスペックは [cl-nagoya/ruri-v3-30m](https://huggingface.co/cl-nagoya/ruri-v3-30m) および [cl-nagoya/ruri-v3-310m](https://huggingface.co/cl-nagoya/ruri-v3-310m) のモデルカードに準拠。
- v3 系は「1+3 プレフィックス方式」を採用し、検索用途では `検索クエリ: ` / `検索文書: ` を入力に付与する（[ruri-v3-310m モデルカード](https://huggingface.co/cl-nagoya/ruri-v3-310m)）。
- ONNX 公式配布は確認できなかった（`cl-nagoya/*` リポジトリ配下に ONNX サブフォルダなし）。第三者による ONNX 変換版が将来出現する可能性はあるが、本調査時点では未確認。
- Ruri 論文では「base サイズで multilingual-e5-large を上回る平均性能」と主張されている（[Ruri 論文 arXiv:2409.07737](https://arxiv.org/abs/2409.07737)）。

#### A-3. BAAI/bge-m3

| 項目 | 値 |
|------|-----|
| 出力次元 | 1024（dense） |
| 最大トークン長 | 8,192 |
| 対応言語 | 100+ 言語（日本語含む） |
| 特徴 | dense / sparse / multi-vector（ColBERT 風）の3種類を同時出力可 |
| ONNX | 第三者実装あり（[yuniko-software/bge-m3-onnx](https://github.com/yuniko-software/bge-m3-onnx)）。公式配布は未確認 |

- 仕様は [BAAI/bge-m3 モデルカード](https://huggingface.co/BAAI/bge-m3) および [BGE-M3 公式ドキュメント](https://bge-model.com/bge/bge_m3.html) による。
- 1024 次元 + 8192 トークン対応で能力は高いが、本デモの 20〜50 件・短文のブログ記事には過剰仕様。
- ライセンスは MIT（モデルカード末尾）。

#### A-4. pfnet/plamo-embedding-1b

| 項目 | 値 |
|------|-----|
| パラメータ数 | 1B |
| 出力次元 | 2048 |
| 最大トークン長 | 4,096（評価は 1,024 で実施） |
| ライセンス | Apache 2.0（商用可） |
| JMTEB 平均 | 76.10（2025年4月初頭時点で「top-class」と自称） |
| ONNX | 公式配布なし（SafeTensors のみ） |
| API | `encode_query()` / `encode_document()` を分離提供。クエリ用プレフィックスは内部で付与 |

- 仕様および JMTEB スコアは [pfnet/plamo-embedding-1b モデルカード](https://huggingface.co/pfnet/plamo-embedding-1b) による。
- 1B パラメータ・2048 次元はクラス最大級で、CPU 推論時のメモリ・レイテンシのコストが他モデルより大きい（公式の数値は未掲載。ADR 段階で実測要）。
- `trust_remote_code=True` を要するカスタム実装で、ONNX 化や Ruby 系 gem からの利用には追加のコンバート作業が必要。

#### A-5. 英語特化 sentence-transformers 系（参考）

| モデル | パラメータ | 次元 | ライセンス | 日本語対応 |
|--------|-----------|------|-----------|-----------|
| sentence-transformers/all-MiniLM-L6-v2 | 23M | 384 | Apache 2.0 | 不可（英語専用） |

- informers / red-candle / RubyLLM 等の Ruby 系資料は概ねこのモデルを例示する。本デモは日本語記事を扱うため不適だが、「Ruby から呼び出す例」の参考値としては有用。

### B. 実行基盤

#### B-1. informers gem（ankane/informers）

| 項目 | 値 |
|------|-----|
| 最新版 | v1.2.x 系（2026年5月時点。203 commits、605 stars。明示的バージョンは [RubyGems](https://rubygems.org/gems/informers) で確認） |
| ライセンス | Apache 2.0 |
| 下回り | onnxruntime（ankane/onnxruntime-ruby）+ tokenizers gem |
| 必須モデル形式 | ONNX（`.onnx` ファイルを含むこと） |
| 量子化サポート | fp32 / fp16 / int8 / uint8 / q8 / q4 / q4f16 / bnb4 |
| Transformers.js からの移植 | あり（同 API・Apache 2.0） |
| 既知のサポートモデル | sentence-transformers/all-MiniLM-L6-v2、intfloat/e5-base-v2、BAAI/bge-base-en-v1.5、jinaai/jina-embeddings-v2-base-en、Snowflake/snowflake-arctic-embed-m-v1.5 等 11 モデル |
| 公式 README での multilingual-e5 言及 | なし |

- 出典: [ankane/informers](https://github.com/ankane/informers) および [README](https://github.com/ankane/informers/blob/master/README.md)、[informers gem doc](https://www.rubydoc.info/gems/informers/file/README.md)。
- multilingual-e5 は README には記載されないが、Xenova/multilingual-e5-{small,base,large} に ONNX が用意されており（[Xenova/multilingual-e5-small](https://huggingface.co/Xenova/multilingual-e5-small)）、informers の「ONNX を含む任意のモデルを `model_file_name` で指定して読み込める」仕様により、追加コードなしで利用できる見込み。本調査時点で公式の動作保証情報は未確認、ADR 段階での PoC が必要。
- 周辺整備: ankane の [neighbor gem](https://github.com/ankane/neighbor)（pgvector の Rails ラッパー）と組み合わせる例が公式 README に掲載されており、Rails 統合の一次資料が揃っている。
- Rails / Kamal でのデプロイ運用例（モデルの事前ダウンロード）が第三者ブログにも存在する（[Predownloading embedding models in Rails with Kamal](https://nts.strzibny.name/predownload-embed-models-kamal/)）。
- 既知の制限・注意点: README にレイテンシ・メモリのベンチマーク記載なし。CPU 推論前提のため、モデルサイズに比例して遅くなる。

#### B-2. transformers-ruby gem（ankane/transformers-ruby）

| 項目 | 値 |
|------|-----|
| ライセンス | Apache 2.0 |
| 下回り | Torch.rb（LibTorch の Ruby バインディング） |
| サポートタスク | embedding、reranking、NER、sentiment-analysis、QA、feature-extraction |
| モデル形式 | HuggingFace 標準（safetensors / pytorch_model.bin） |

- 出典: [ankane/transformers-ruby](https://github.com/ankane/transformers-ruby)。
- ONNX 不要で HuggingFace モデルをそのまま読めるが、Torch.rb（≒ LibTorch）依存のため Docker イメージサイズと初期セットアップコストが informers より大きい。
- informers README にも「ONNX 化されていない非 ONNX モデルを使うには Transformers.rb を見よ」との案内がある（[informers README](https://github.com/ankane/informers/blob/master/README.md)）。informers の補完的位置付け。

#### B-3. red-candle gem（scientist-labs/red-candle）

| 項目 | 値 |
|------|-----|
| 最新版 | v1.7.1（2026年4月6日） |
| ライセンス | MIT |
| 下回り | Rust + Candle（HuggingFace の Rust ML フレームワーク）+ Magnus（Ruby-Rust FFI） |
| サポート埋め込みモデル | Jina BERT / MiniLM / DistilBERT / 標準 BERT（safetensors のみ） |
| アクセラレータ | Metal（Apple GPU、約 3 倍）、CUDA（約 18 倍）、CPU（ベースライン） |
| 制約 | 埋め込み・リランカーは safetensors のみ対応（GGUF は LLM 用途のみ） |

- 出典: [scientist-labs/red-candle](https://github.com/scientist-labs/red-candle)。
- multilingual-e5 や ruri は XLM-R / ModernBERT-Ja ベースであり、現時点の red-candle のサポートアーキテクチャ（Jina/MiniLM/DistilBERT/標準BERT）に該当するか個別の確認が必要。XLM-RoBERTa は標準 BERT とアーキテクチャが異なり、サポート可否は未確認。
- Metal 加速は Mac 開発者にとって魅力だが、Linux/Docker Compose 中心の追体験環境では恩恵を受けにくい。
- 「informers と同じく `:doc_id` / `:score` 形式で結果を返せる」という相互互換性の記載がドキュメントにあり、informers からの移行を意識した設計（[red-candle README 検索結果](https://github.com/scientist-labs/red-candle)）。
- ネイティブ拡張のビルドが必要（Rust toolchain、Magnus）。Docker でのビルドは informers より重い。

#### B-4. llama_cpp.rb gem（yoshoku/llama_cpp.rb）

| 項目 | 値 |
|------|-----|
| 最新版 | v0.23.3（2025年10月11日） |
| ライセンス | MIT |
| 下回り | llama.cpp（事前インストール必須。Homebrew 等で導入） |
| 主用途 | LLM のテキスト生成 |
| 埋め込みサポート | llama.cpp 本体は `--embeddings` フラグで対応するが、Ruby gem README では生成例のみ掲載され、埋め込み API の例示は確認できず |

- 出典: [yoshoku/llama_cpp.rb](https://github.com/yoshoku/llama_cpp.rb)、[llama.cpp の embedding 議論 #4117](https://github.com/ggml-org/llama.cpp/discussions/4117)。
- llama.cpp の事前インストールが必要で、Docker Compose で完結させるには別途ビルドステップが要る。本デモの「セットアップ容易性」では不利。
- GGUF 形式の埋め込みモデルは限定的（embeddinggemma 等の一部モデルが GGUF 提供されているが、multilingual-e5 / ruri / plamo はいずれも公式 GGUF 配布なし）。

#### B-5. onnxruntime gem（ankane/onnxruntime-ruby）

- 低レベルの ONNX Runtime ラッパー。informers の下回りであり、informers が抽象化を提供している。直接利用するメリットは「informers がサポートしないタスクを自前実装する場合」のみで、本デモの用途では informers 経由のほうが書く量が少ない。

#### B-6. Python サイドカー（HTTP/gRPC）

- Rails と別プロセスで `sentence-transformers` / `transformers` を起動し、HTTP API（FastAPI 等）または gRPC で呼び出す方式。
- メリット: Python 側の任意の埋め込みモデル（plamo / ruri / bge-m3 等を含む）をすべて使える。日本語特化モデルの選択肢が最大化する。
- デメリット:
  - Docker Compose に Python コンテナを追加する必要があり、Rails 単体構成より複雑。
  - 「Ruby/Rails 内で完結する」記事題材としての一貫性が損なわれる。Zenn 記事の主題が「Rails ↔ Python サイドカー連携」にずれる懸念。
  - ローカル動作制約は満たすが、追体験のためのコンテナ起動数が増える。
- 参考: [requirements.md §3.1](../requirements/requirements.md) に Docker Compose 利用が明記されているため、技術的には許容範囲だが、§3.2 「コードの説明しやすさを最優先」に対するコストは大きい。

## 分析・考察

### 主要な発見

#### 発見1: 「日本語品質」と「Ruby から直接呼べる利便性」はトレードオフ

JMTEB / Ruri 論文上で日本語品質が最も高いのは **ruri 系** および **plamo-embedding-1b** だが、いずれも公式 ONNX 配布がなく、informers / transformers-ruby 等の Ruby gem から直接読み込むには第三者コンバートまたは自前変換が必要。一方、**multilingual-e5** は informers が依拠する Transformers.js エコシステム（Xenova アカウント）が ONNX 版を公式メンテナンスしており、Ruby から「追加変換なし」で利用できる唯一の有力候補。

| モデル | 日本語品質 | Ruby gem 直接利用 |
|--------|-----------|-----------------|
| multilingual-e5-base | 中（Mr. TyDi MRR@10 56.6） | 容易（Xenova ONNX + informers） |
| ruri v3-310m | 高（JMTEB 77.24） | 困難（ONNX 自前変換要） |
| plamo-embedding-1b | 高（JMTEB 76.10） | 困難（ONNX 化未確認＋カスタムコード依存） |
| bge-m3 | 高（多言語） | 中（第三者 ONNX あり、ただし dense/sparse/colbert 同時出力で API がやや複雑） |

#### 発見2: 「記事執筆・追体験」の観点で informers が突出

informers gem は以下の点で記事題材として有利：

- README に embedding パイプラインの完結した最小例がある（数行で動く）
- ankane/neighbor との組み合わせで「Rails + pgvector + 埋め込み」の最短ルートがすでに公式に示されている（[neighbor README](https://github.com/ankane/neighbor)）
- 第三者の Rails 運用記事も存在し、追体験者が躓いた際の検索性が高い
- Apache 2.0 で商用・記事公開ともに制限なし
- ONNX Runtime 単体に依存するため、Docker イメージサイズが Torch.rb / Rust ビルドより小さい

ただし、informers の README は英語モデル例が中心で、日本語モデルでの動作実例は公式には未確認。これは記事内で読者に提示すべき「実装上の注意点」となる（ADR 段階の PoC で確認）。

#### 発見3: red-candle は「Rust + Metal」が魅力だが本デモには過剰

red-candle は最新（v1.7.1, 2026/04）かつ Rust ベースで informers より高速な可能性があるが：

- Rust toolchain のビルド要件で Docker イメージが膨らむ
- 埋め込みは safetensors のみで、ONNX 中心の HuggingFace エコシステム（特に量子化版）の恩恵が受けにくい
- multilingual-e5（XLM-R 系）のサポートが安定して動くかは未確認
- Metal 加速の恩恵は macOS 開発者限定で、Linux/Docker での追体験が標準の本デモでは活きない

「20〜50 件のブログ記事」規模では informers の CPU 推論で十分応答可能と推定されるため、Rust ビルドコストを払う合理性は薄い。

#### 発見4: Python サイドカーは「日本語品質を妥協したくない場合の現実解」

ruri / plamo を使いたい場合、Python サイドカーが最も素直。ただし「Rails 単体で完結する記事」というメッセージ性は失われ、記事のテーマが「Rails と Python サービスの連携設計」に傾く。本デモの主題（Rails + Hotwire + ActiveJob + ベクター検索）から焦点が外れるため、デフォルト推奨にはしにくい。

### 技術的評価

| 評価項目 | informers + multilingual-e5-base | informers + multilingual-e5-small | red-candle + （要確認） | Python サイドカー + ruri-v3-310m |
|----------|----------------------------------|-----------------------------------|------------------------|----------------------------------|
| 日本語品質（出典付き定性） | 中（[Mr. TyDi 56.6](https://huggingface.co/intfloat/multilingual-e5-base)） | 中（base より低下、[MMTEB 論文](https://arxiv.org/abs/2502.13595)で言語別差あり） | モデル依存 | 高（[JMTEB 77.24](https://huggingface.co/cl-nagoya/ruri-v3-310m)） |
| 出力次元 | 768 | 384 | モデル依存 | 768 |
| Ruby から直接利用 | ◎ | ◎ | ○（XLM-R 系の動作要確認） | ×（HTTP 経由） |
| ONNX 公式配布 | ◎（[Xenova/multilingual-e5-base](https://huggingface.co/Xenova/multilingual-e5-base)） | ◎（[Xenova/multilingual-e5-small](https://huggingface.co/Xenova/multilingual-e5-small)） | — | — |
| ライセンス | MIT + Apache 2.0 | 同左 | MIT + モデル依存 | Apache 2.0 |
| Docker Compose 構成の単純さ | ◎ | ◎ | ○（Rust ビルド要） | ×（Python コンテナ追加要） |
| 記事の説明しやすさ | ◎（公式例豊富） | ◎ | ○（事例少） | △（連携設計の説明が増える） |
| 推論速度・メモリ | 公式数値なし。ADR 段階の PoC で実測要 | base より軽量と推定（パラメータ数比） | Rust 化により informers より高速の可能性（自社主張、第三者ベンチ未確認） | サイドカー越しのため通信オーバーヘッドあり |

### リスクと制約

- **R-1: informers + multilingual-e5 の動作確認が公式に存在しない**
  - 記事公開前の PoC で「Xenova/multilingual-e5-base を informers から読み込んで日本語入力で埋め込みが取れること」を確認する必要がある。
  - 失敗時のフォールバックとして、Xenova の他多言語モデル（例: multilingual-e5-small）または Python サイドカーを準備しておく。

- **R-2: 推論速度・メモリの公式数値が乏しい**
  - 多くの Ruby gem README にベンチマーク記載がなく、CPU 推論の実測値は ADR 段階で測定が必要。
  - 一般論として CPU 推論は GPU 比 10〜50 倍遅いという第三者言及はあるが、本デモは 20〜50 件・top-K=10 規模のため、実用速度に収まる蓋然性は高い（推測。実測要）。

- **R-3: 日本語特化モデル（ruri/plamo）の Ruby 直接利用は当面困難**
  - 公式 ONNX 配布がない、または `trust_remote_code` 必須のため、Ruby gem 経由での簡易利用は現状想定できない。
  - 将来的に第三者 ONNX 変換が出現すれば情勢は変わるが、本調査時点では選択肢として提示しにくい。

- **R-4: 記事公開後のメンテナンス性**
  - informers は ankane の保守下で活発（commits 203）だが、特定バージョンに固定する必要あり。
  - red-candle は 2026/04 リリース直後で安定性の蓄積が乏しい。

## 結論・推奨事項

### 結論

「Zenn 記事の題材として、追体験性とコードの説明しやすさを最優先する」観点で評価した場合、**informers gem + intfloat/multilingual-e5-base（ONNX 版は Xenova/multilingual-e5-base）の組み合わせ** が最も整合的である。次点として **同 small** が「より軽量で動かしたい」読者向けに提示できる。

ただし、日本語埋め込み品質を最優先するならば、ruri v3-310m（または plamo-embedding-1b）を Python サイドカー経由で使う構成が JMTEB スコア上は上回る。本デモが「Ruby/Rails 内完結」を価値として打ち出すか、「日本語品質最大化」を優先するかは ADR の判断事項である。

### 推奨事項

#### 推奨案 1（第一候補）: informers gem + Xenova/multilingual-e5-base

- **採用条件**:
  - 「Rails 単体で完結する」記事の物語を維持したい
  - 20〜50 件規模で「明らかに関連する記事が上位に来る」レベル（[要件定義書 §5 受入条件](../requirements/requirements.md)）が達成できれば品質要件を満たすと判断できる
  - PoC で「informers から Xenova/multilingual-e5-base を呼び出し、日本語入力で 768 次元ベクトルが取得できる」ことを確認する
- **理由**:
  - Ruby から追加変換なしで使える唯一の多言語モデル系統
  - informers + neighbor + pgvector の組み合わせは ankane エコシステム公式の組み合わせで、記事の各ステップで参照すべき一次資料が揃っている
  - Apache 2.0 + MIT で記事公開・コード公開ともに障害なし
- **期待効果**:
  - 追体験者は `bundle install` と Docker Compose 起動のみで動作確認に到達できる
  - 記事内のコード断片が短く、Rails 標準の説明（CRUD・ActiveJob・Hotwire）に紙幅を割ける

#### 推奨案 2（軽量版・補足）: informers gem + Xenova/multilingual-e5-small

- **採用条件**:
  - PoC で base モデルの推論時間が ActiveJob ジョブとして許容できない場合、または記事内で「もっと軽量な選択肢」を併記したい場合
- **理由**: 384 次元・パラメータ数約 1/2 で、CPU 推論時のメモリ・レイテンシが軽減されると見込まれる（公式の数値比較なし、ADR 段階で実測要）
- **期待効果**: 低スペック環境での追体験性向上

#### 採否判断は ADR A-2 に委ねる

本報告書は判断材料の提供にとどまる。以下の判断は ADR A-2 にて行うこと:

- 第一候補・補足候補の確定
- 「日本語品質最優先で Python サイドカー + ruri/plamo を採用するか」のメッセージ設計判断
- model_identifier の文字列形式（[機能設計書 §2.1.2](../functional-design/functional-design.md)）

### 次のアクション

- [ ] ADR A-2 にて、本報告書の推奨案 1/2 を出発点に採用モデルと実行基盤を決定する
- [ ] ADR 決定後の PoC で、informers + Xenova/multilingual-e5-base の日本語入力動作を確認する
- [ ] ベクターDB の選定（pgvector + neighbor 等）は別途 ADR で扱う（本調査の範囲外）

---

## 関連資料

- [要件定義書](../requirements/requirements.md) — 特に §3.2 ローカル動作制約、§3.4 ADR 委譲事項
- [機能設計書](../functional-design/functional-design.md) — 特に §6 抽象インターフェース `EmbeddingModel`
- [用語集](../glossary/glossary.md) — 「埋め込みベクトル」「埋め込みモデル」「クエリ文」の正式表記
- [ADR A-2「埋め込みモデルと実行基盤の選定」](../adr/002-embedding-model-and-runtime.md)（本報告書を判断材料として作成済み）

## 改訂履歴

| バージョン | 日付 | 変更内容 |
|-----------|------|----------|
| 1.0 | 2026/05/06 | 初版作成 |

---

## 参照したソース URL の一覧

### 埋め込みモデル

- intfloat/multilingual-e5-small: https://huggingface.co/intfloat/multilingual-e5-small
- intfloat/multilingual-e5-base: https://huggingface.co/intfloat/multilingual-e5-base
- intfloat/multilingual-e5-large: https://huggingface.co/intfloat/multilingual-e5-large
- Xenova/multilingual-e5-small（ONNX）: https://huggingface.co/Xenova/multilingual-e5-small
- Xenova/multilingual-e5-base（ONNX）: https://huggingface.co/Xenova/multilingual-e5-base
- Xenova/multilingual-e5-large（ONNX）: https://huggingface.co/Xenova/multilingual-e5-large
- cl-nagoya/ruri v3 コレクション: https://huggingface.co/collections/cl-nagoya/ruri-v3
- cl-nagoya/ruri-v3-30m: https://huggingface.co/cl-nagoya/ruri-v3-30m
- cl-nagoya/ruri-v3-310m: https://huggingface.co/cl-nagoya/ruri-v3-310m
- cl-nagoya/ruri-large: https://huggingface.co/cl-nagoya/ruri-large
- BAAI/bge-m3: https://huggingface.co/BAAI/bge-m3
- BGE-M3 公式ドキュメント: https://bge-model.com/bge/bge_m3.html
- bge-m3 ONNX 実装（第三者）: https://github.com/yuniko-software/bge-m3-onnx
- pfnet/plamo-embedding-1b: https://huggingface.co/pfnet/plamo-embedding-1b

### Ruby 実行基盤

- ankane/informers: https://github.com/ankane/informers
- informers README: https://github.com/ankane/informers/blob/master/README.md
- informers gem doc: https://www.rubydoc.info/gems/informers/file/README.md
- ankane/transformers-ruby: https://github.com/ankane/transformers-ruby
- ankane/onnxruntime-ruby: https://github.com/ankane/onnxruntime-ruby
- scientist-labs/red-candle: https://github.com/scientist-labs/red-candle
- red-candle ドキュメント: https://assaydepot.github.io/red-candle/
- yoshoku/llama_cpp.rb: https://github.com/yoshoku/llama_cpp.rb
- llama_cpp gem (RubyGems): https://rubygems.org/gems/llama_cpp
- ankane/neighbor: https://github.com/ankane/neighbor

### ベンチマーク・評価

- MMTEB 論文（arXiv:2502.13595）: https://arxiv.org/abs/2502.13595
- MTEB Leaderboard: https://huggingface.co/spaces/mteb/leaderboard
- JMTEB（評価リポジトリ）: https://github.com/sbintuitions/JMTEB
- Ruri 論文（arXiv:2409.07737）: https://arxiv.org/abs/2409.07737
- ggml-org/llama.cpp embedding 議論 #4117: https://github.com/ggml-org/llama.cpp/discussions/4117

### Rails 連携・運用

- Predownloading embedding models in Rails with Kamal: https://nts.strzibny.name/predownload-embed-models-kamal/

[^e5small-onnx]: https://huggingface.co/Xenova/multilingual-e5-small
[^e5base-onnx]: https://huggingface.co/Xenova/multilingual-e5-base
[^e5large-onnx]: https://huggingface.co/Xenova/multilingual-e5-large
