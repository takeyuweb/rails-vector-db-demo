# ドキュメントワークフロー進捗

## プロジェクト情報

- **ワークフローID**: rails-vector-search-demo
- **プロジェクト名**: Railsアプリにベクター検索を統合するデモ
- **用途**: 登壇・プレゼン用
- **開始日**: 2026-05-06
- **最終更新日**: 2026-05-06
- **ステータス**: 完了（Phase 7 まで実施。全 ADR は Proposed ステータス、ユーザー承認後に Accepted へ更新）

## ワークフロー進捗

- [x] Phase 1: インベントリと計画
- [x] Phase 2: 要件定義
- [x] Phase 3: 用語集
- [x] Phase 4: 機能設計
- [x] Phase 5: 調査報告書 & ADR
- [x] Phase 6: ファクトチェック
- [x] Phase 7: 完了レビュー

## 成果物一覧

| 文書種別 | タイトル | ステータス | ファイルパス |
|---------|---------|-----------|------------|
| 要件定義書 | Railsベクター検索デモ 要件定義書 | 完了 | docs/requirements/requirements.md |
| 用語集 | Railsベクター検索デモ 用語集 | 完了 | docs/glossary/glossary.md |
| 機能設計書 | ブログ記事の類似検索デモ 機能設計書 | 完了 | docs/functional-design/functional-design.md |
| 調査報告書 R-A | ローカル動作可能な埋め込みモデルと実行基盤の比較 | 完了 | docs/reports/r-a-embedding-models-comparison.md |
| 調査報告書 R-B | ローカル動作可能なベクターDBの比較 | 完了 | docs/reports/r-b-vector-db-comparison.md |
| 調査報告書 R-C | Rails とベクターDBを橋渡しする gem の比較 | 完了 | docs/reports/r-c-rails-integration-gems-comparison.md |
| ADR A-1 | Rails / Ruby バージョンの選定（→ Rails 8.1.3 / Ruby 3.4.9） | 完了（Proposed） | docs/adr/001-rails-ruby-versions.md |
| ADR A-2 | 埋め込みモデルと実行基盤の選定（→ informers + multilingual-e5-base） | 完了（Proposed） | docs/adr/002-embedding-model-and-runtime.md |
| ADR A-3 | ベクターDB の選定（→ pgvector） | 完了（Proposed） | docs/adr/003-vector-database.md |
| ADR A-4 | Rails 統合 gem の選定（→ neighbor） | 完了（Proposed） | docs/adr/004-rails-integration-gem.md |
| ADR A-5 | 類似度指標の決定（→ cosine） | 完了（Proposed） | docs/adr/005-similarity-metric.md |
| ファクトチェック | ADR 5本＋要件定義書＋機能設計書を検証 | 完了 | 検出された事実誤認1件（A-3 の weaviate-ruby 保守状況）を修正済み |

## 計画メモ

- 技術選定（ベクターDB / 埋め込みモデル / Rails統合方式）はすべて未定。Phase 4 以降の調査・ADR で決定する。
- 登壇用途のため Phase 6（ファクトチェック）を必須として含める。
  - 主張・数値・gem仕様・モデル仕様の誤りは信用毀損リスク。
- Phase 4.1 で確定した調査・ADRトピック:
  - 調査報告書（3本）:
    - R-A: ローカル動作可能な埋め込みモデルと実行基盤の比較
    - R-B: ローカル動作可能なベクターDBの比較
    - R-C: Rails とベクターDBを橋渡しする gem の比較
  - ADR（5本）:
    - A-1: Rails / Ruby バージョンの選定
    - A-2: 埋め込みモデルと実行基盤の選定（入力: R-A）
    - A-3: ベクターDB（物理層）の選定（入力: R-B）
    - A-4: Rails 統合方式（gem）の選定（入力: R-C）
    - A-5: 類似度指標の決定（入力: R-A, R-B）

## 備考

- 出力先ディレクトリ: `docs/`（標準構成）
- ワークフロー完了後は本ファイルを git にコミットして履歴として保存することを推奨
