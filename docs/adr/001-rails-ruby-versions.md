# ADR A-1: Rails / Ruby バージョンの選定

## ステータス

提案中

## 日付

2026-05-06

## 信頼度

中 — Rails 8.1 系・Ruby 3.4 系の採用については一次情報（rubyonrails.org / ruby-lang.org / RubyGems）と後続 ADR 入力（調査報告書 R-C）から確実に整合する。一方、Ruby 4.0 系を見送る判断は「リリース後 4 ヶ月時点で周辺 gem の互換性検証コストが本デモの追体験性を損なうリスク」という性質上の判断であり、定量的な互換 gem 充足率は未測定であるため信頼度は中とする。

## 再評価条件

- 本デモの後続 ADR（A-2 埋め込みモデル / A-3 ベクターDB / A-4 Rails 統合方式）で採用が確定する gem のいずれかが、Ruby 3.4 系を要求できない（Ruby 4.0 必須または 3.4 非対応）と判明した場合
- Ruby 3.4 系が security maintenance に移行する見込みが立った場合（現時点では normal maintenance）
- Rails 8.2 がリリースされ、本デモのリポジトリを更新する場合
- 後発記事で Ruby 4.0 / Rails の最新メジャーを取り上げる必要が生じた場合（本 ADR を置換する新 ADR を作成）

## コンテキスト

本デモは「Rails アプリにブログ記事の類似検索を統合する」題材を Zenn 技術記事として公開するためのリファレンス実装であり、読者がリポジトリをクローンして同じ環境を再構築できること（追体験性）が成果の前提となる。要件定義書 §3.2 は「Rails / Ruby は最新安定版を使用する」と規定しており、本 ADR ではこの「最新安定版」を本デモの目的に照らして具体バージョンへ落とし込む。

### 現状の問題点

- 「最新安定版」という規定だけでは、後続 ADR（特に A-4 で採用予定の `neighbor` v1.0.0）の最低要件と整合するかが判定できない。
- 2026-05-06 時点で Ruby 4.0.0 が最新安定版として公開されている（2025-12-25 リリース）が、Ractor API・Net::HTTP・CGI・SortedSet 等の破壊的変更を含み、Rails / 周辺 gem の追従状況を本デモのスコープで個別検証することは記事題材として焦点がずれる。
- Rails 8.1 系の推奨 Ruby は 3.4 系であり、Ruby 4.0 系で動作させた場合の挙動は「最新安定版同士の組み合わせ」とは言えない時期にある。

### 制約条件

- **要件定義書 §3.2**: Rails / Ruby は最新安定版を使用すること、Hotwire（Turbo + Stimulus）採用、ローカル完結、ActiveJob 採用。
- **後続 ADR の入力**: 調査報告書 R-C で確認済みのとおり、`neighbor` v1.0.0（2026-04-04 リリース）は Ruby >= 3.3 / ActiveRecord >= 7.2 を要求する。本 ADR で決定するバージョンはこの要件を満たす必要がある。
- **追体験性**: 読者が GitHub からクローンして Docker Compose で起動できること、および記事公開後の一定期間（最低 1 年）を見据えて「読者の手元で再現可能な、メンテナンスされているバージョン」であること。
- **解説容易性**: バージョン特有の落とし穴（破壊的変更回避策、互換 gem の代替探索等）を記事本文に含めずに、ベクター検索の解説に集中できること。

## 決定

本デモでは **Rails 8.1.3 / Ruby 3.4.9** を採用する。

具体的には、以下のとおり Gemfile / `.ruby-version` / `Dockerfile` で固定する：

- `Gemfile`: `gem "rails", "~> 8.1.3"`
- `.ruby-version`: `3.4.9`
- `Dockerfile`: ベースイメージに `ruby:3.4.9` 系を指定

### 実装方針

1. プロジェクト初期化時に上記バージョンで `rails new` を実行し、生成された `Gemfile` / `Gemfile.lock` / `.ruby-version` をコミット起点とする。
2. Docker Compose 用の `Dockerfile` で Ruby 3.4.9 系の公式イメージを使用し、ローカル Ruby のインストール状態に依存しない実行環境を提供する。
3. CI を導入する場合は同じ Ruby / Rails バージョンの組み合わせをマトリクスのデフォルトとする（CI 構築は本 ADR のスコープ外）。
4. パッチバージョンの更新（Rails 8.1.x の x、Ruby 3.4.x の x）は ADR を改訂せず追従可能とする。マイナー以上のアップデート（Rails 8.2 / Ruby 3.5 等）は新規 ADR で再決定する。

## 結果

### ポジティブな影響

1. **後続 ADR との整合**
   - `neighbor` v1.0.0 の Ruby >= 3.3 / ActiveRecord >= 7.2 要件を満たす。後続 ADR A-4 で `neighbor` 採用が確定した場合に追加調整が不要。
2. **Rails 公式の推奨構成と一致**
   - Rails 8.1 系で「preferred」とされる Ruby 3.4 系を選択しているため、フレームワーク本体・標準依存 gem の動作確認パスが厚い構成になる。
3. **追体験性の長期確保**
   - Ruby 3.4 系は normal maintenance（2026-05-06 時点）であり、Rails 8.1 系のバグフィックス支援は 2026-10-10 まで、セキュリティ支援は 2027-10-10 までが公式に確約されている。記事公開後 1 年以上、読者が同じ構成で再現できる見込みが立つ。
4. **解説容易性**
   - Ruby 4.0 の破壊的変更（Ractor API 改廃、Net::HTTP の Content-Type 自動付与廃止、CGI の default gem 縮小、SortedSet の別 gem 化）に伴う互換性回避コードを記事本文に含めずに済むため、ベクター検索の本筋に集中できる。

### ネガティブな影響・トレードオフ

1. **「最新安定版」の文言と Ruby 4.0 系を採用しない判断のギャップ**
   - 要件定義書 §3.2 の「最新安定版」を厳密に読めば Ruby 4.0 系の採用が含意されうるが、本 ADR は追体験性・解説容易性の観点から Ruby 3.4 系を採用する。
   - **対策**: 要件定義書側に注記を追加するか、本 ADR を「『最新安定版』の運用解釈」として参照可能にする。本デモのリポジトリ README で「Ruby 3.4 系を採用した理由は ADR A-1 を参照」と明示する。
2. **Ruby 3.4 / Rails 8.1 の新機能解説に踏み込みにくい**
   - 本 ADR は「ベクター検索の解説」を主題とする選定であり、Ruby 4.0 / Rails 最新マイナーの新機能解説（ZJIT、Ruby Box 等）は別記事のスコープになる。
   - **対策**: 該当機能を取り上げる別記事を独立して企画する。本デモの ADR を新規作成して置換する形で再構成する。
3. **Rails 8.1 系のバグフィックス支援終了（2026-10-10）後の追体験性**
   - 公開後 5 ヶ月程度で bugfix サポートが終了する。それ以降は security fix のみとなる。
   - **対策**: 記事公開直後に Rails 8.1 の最新パッチで動作することを確認し、サポート終了が見えた段階で再評価条件に従って ADR を更新する。

## 代替案

### 案1: Ruby 4.0 系（最新安定版）+ Rails 8.1 系

**概要**: 要件定義書 §3.2 の「最新安定版」を文字通り適用し、2025-12-25 リリースの Ruby 4.0 系最新パッチを採用する。

**メリット**:
- 要件定義書の文言と完全一致する。
- Ruby 4.0 で導入された ZJIT・Ruby Box などの新機能を記事中で言及できる余地が生まれる。

**デメリット**:
- Ruby 4.0 は Ractor API・Net::HTTP・CGI・SortedSet 等の破壊的変更を含む。Rails 8.1 系および本デモが採用する周辺 gem（`neighbor` 等）が Ruby 4.0 で問題なく動作するかを本デモの責務として個別検証する必要がある。
- Rails 8.1 の preferred Ruby は 3.4 系であり、Rails 公式のテストマトリクスとずれる組み合わせになる。
- リリース後 4 ヶ月時点（2026-05-06）では、ベクター検索関連 gem の Ruby 4.0 対応が進んでいるかについての確証がなく、追体験性のリスクが残る。

**却下理由**: 本デモの主題はベクター検索の組み込み方の解説であり、Ruby 4.0 互換性検証を副次的な課題として抱えるのはスコープに合わない。要件定義書の「最新安定版」は、追体験性・解説容易性の文脈で「広く検証された安定マイナー」と解釈する方が、デモの目的に整合する。

### 案2: Rails 7.2 系 + Ruby 3.3 系（neighbor 互換性の最低ライン）

**概要**: `neighbor` v1.0.0 が要求する Ruby >= 3.3 / ActiveRecord >= 7.2 の最低ラインを採用する。

**メリット**:
- 後続 ADR 入力の最低要件をギリギリで満たす保守的構成。
- Rails 7.2 系はセキュリティ支援が 2026-08-09 まで公式に確約されている。

**デメリット**:
- 「最新安定版」という要件定義書の規定から大きく外れる（Rails 8.0 / 8.1 が既に安定リリースされている）。
- Rails 8 系の標準機能（Solid Queue / Solid Cable / Kamal 統合等の最新動向）に触れにくくなる。
- セキュリティ支援終了（2026-08-09）が早く、記事公開後 3 ヶ月程度で「公式サポート対象外」の指摘を受けるリスクがある。

**却下理由**: 「最新安定版」要件と乖離し、かつ公式サポート期間が短いため追体験性も劣る。`neighbor` 互換性の最低ラインを取りに行く合理性が、本デモの目的（最新の Rails 標準構成にベクター検索を組み込む方法を示す）と合わない。

### 案3: Rails 8.0 系 + Ruby 3.3 系

**概要**: Rails 8 系の前マイナー（8.0）と Ruby 3.3 系の組み合わせ。

**メリット**:
- 8.0 系は 2026-05-06 時点でも bugfix 支援が継続中（同年 5 月 7 日まで、その後は security 支援が 2026-11-07 まで）。
- Ruby 3.3 系は security maintenance に入っており、互換性が安定している。

**デメリット**:
- Rails 8.1 系がすでにリリースされており「最新安定版」とは言いにくい。
- 採用直後に bugfix 支援が終了する（2026-05-07）ため、記事公開時点で「最新版を採用していない理由」を別途説明する必要がある。

**却下理由**: Rails 8.1 を採用しない積極的理由がなく、bugfix 支援終了直前に着地するため追体験性も劣る。

## 関連 ADR・関連調査報告書

- [調査報告書 R-C: Rails とベクターDBを橋渡しする gem の比較](../reports/r-c-rails-integration-gems-comparison.md) — `neighbor` v1.0.0 の Ruby / ActiveRecord 要件の根拠
- [ADR 002: 埋め込みモデルと実行基盤の選定（A-2、入力: R-A）](./002-embedding-model-and-runtime.md)
- [ADR 003: ベクターDB の選定（A-3、入力: R-B）](./003-vector-database.md)
- [ADR 004: Rails 統合方式（gem）の選定（A-4、入力: R-C）](./004-rails-integration-gem.md) — 本 ADR で決定するバージョンが `neighbor` 採用の前提を満たす
- [ADR 005: 類似度指標の決定（A-5、入力: R-A, R-B）](./005-similarity-metric.md)
- [要件定義書 §3.2](../requirements/requirements.md) — 「最新安定版」制約の出所
- [用語集](../glossary/glossary.md) — Rails / ActiveJob / Hotwire 等の用語定義

## 参考資料

- [Ruby on Rails Releases カテゴリ](https://rubyonrails.org/category/releases) — Rails 8.1.3 が 2026-03-24 リリースであることの一次情報
- [New Rails Releases and End of Support Announcement (2025-10-29)](https://rubyonrails.org/2025/10/29/new-rails-releases-and-end-of-support-announcement) — Rails 7.x / 8.0 / 8.1 のサポート期間
- [Ruby Downloads](https://www.ruby-lang.org/en/downloads/) — Ruby 3.4.9 / 3.3.11 / 4.0.3 が現行リリースであることの一次情報
- [Ruby Branches](https://www.ruby-lang.org/en/downloads/branches/) — 各ブランチのメンテナンス状況（4.0 / 3.4 が normal、3.3 が security、3.2 以前は EOL）
- [Ruby 4.0.0 Released (2025-12-25)](https://www.ruby-lang.org/en/news/2025/12/25/ruby-4-0-0-released/) — Ruby 4.0 の破壊的変更（Ractor API / Net::HTTP / CGI / SortedSet）
- [FastRuby.io: Ruby & Rails Compatibility Table](https://www.fastruby.io/blog/ruby/rails/versions/compatibility-table.html) — Rails 8.1 の minimum Ruby 3.2.0 / preferred Ruby 3.4 系
- [ankane/neighbor CHANGELOG](https://github.com/ankane/neighbor/blob/master/CHANGELOG.md) — neighbor 1.0.0 (2026-04-04) が Ruby >= 3.3 / Active Record >= 7.2 を要求

## 改訂履歴

| バージョン | 日付 | 変更内容 |
|-----------|------|---------|
| 0.1 | 2026-05-06 | 初版ドラフト作成（提案中） |
