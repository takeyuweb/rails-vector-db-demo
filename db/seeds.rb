# 機能設計書 §8 に従う初期データ。24件のブログ記事を6テーマに分散配置し、
# 「明らかに関連する記事が上位に来る」ことを確認できるようにする。
#
# 投入後の埋め込み生成: seed 実行時にも Article#after_commit が ArticleEmbeddingJob
# をエンキューするため、別途 bin/jobs を起動して非同期処理を完了させる必要が
# ある（README 参照）。
#
# 冪等性: title 一致で find_or_create_by を行い、再投入時に重複を作らない。

ARTICLES = [
  # ===== Rails テーマ =====
  {
    title: "Rails 8 の Solid Queue で非同期ジョブを動かす",
    body: <<~BODY
      Rails 8 から ActiveJob のバックエンドとして Solid Queue が公式に同梱され、
      Redis を介さず PostgreSQL のテーブルだけでジョブキューを運用できるように
      なりました。bin/jobs プロセスを起動するだけでジョブの実行が始まり、Kamal で
      デプロイする小規模アプリでも追加の依存サービスを増やさずに非同期処理を
      導入できます。本記事では Solid Queue の最小構成と再試行の挙動を解説します。
    BODY
  },
  {
    title: "Rails の after_commit でモデル保存後に処理を起動する",
    body: <<~BODY
      ActiveRecord の after_commit コールバックは、トランザクションがコミットされた
      直後に発火します。after_save との違いは、ロールバックされたケースで実行され
      ないことと、関連レコードの保存も含むトランザクション全体の確定後に動く点です。
      非同期ジョブのエンキューには after_commit を使うと、保存が確定したものに
      対してのみジョブが走り、整合性が保ちやすくなります。
    BODY
  },
  {
    title: "Hotwire Turbo Frame で部分的な画面更新を実装する",
    body: <<~BODY
      Turbo Frame は HTML レスポンスから対応する frame ID の中身だけを取り出して
      入れ替える Hotwire の中核機能です。フォーム送信や lazy loading により、
      JavaScript を書かずに「ページ全体は再描画せず、特定領域だけを差し替える」
      動作を実現できます。本デモでは検索結果と類似記事セクションを Turbo Frame で
      実装しています。
    BODY
  },
  {
    title: "Rails の ActiveJob retry_on で一時的失敗をリトライする",
    body: <<~BODY
      ActiveJob には retry_on という宣言的な再試行 DSL があります。例外クラスを
      指定し、待機戦略（polynomially_longer など）と最大試行回数を設定するだけで、
      一時的なネットワーク失敗や I/O エラーを吸収できます。最終的に失敗した場合は
      DiscardJob として扱われ、ジョブが二度と再実行されないため、永続的なエラーは
      別途監視で気付ける運用が必要です。
    BODY
  },

  # ===== Ruby テーマ =====
  {
    title: "Ruby のブロックと Proc と lambda の違い",
    body: <<~BODY
      Ruby では「コードのかたまり」を表現する方法としてブロック・Proc・lambda の
      3 通りがあります。ブロックはメソッドに渡される無名のかたまりで、yield や
      &block で受け取ります。Proc.new と lambda はオブジェクト化できますが、
      引数チェックの厳密さと return の振る舞いに違いがあります。
    BODY
  },
  {
    title: "Ruby の Enumerable を使ったコレクション操作",
    body: <<~BODY
      Array や Hash には Enumerable モジュールが mixin されており、map・select・
      reduce・group_by といった豊富なコレクション操作が利用できます。each を
      実装するだけで Enumerable を mixin できるため、自作クラスにも統一的な
      コレクション API を提供できます。each_with_object や tally も実用的です。
    BODY
  },
  {
    title: "Ruby のキーワード引数とデフォルト値",
    body: <<~BODY
      Ruby 3 以降、位置引数とキーワード引数は明確に分離されました。**options のような
      ハッシュ受け取りからの自動変換は廃止され、明示的にキーワード引数として
      宣言する必要があります。デフォルト値はキーワードごとに指定でき、可読性の
      高い API を作る上で欠かせない機能です。
    BODY
  },
  {
    title: "Ruby のメソッドの可視性と private の使い方",
    body: <<~BODY
      Ruby のメソッドには public・protected・private の3つの可視性があります。
      private メソッドは同じインスタンスでのみ呼び出せ、protected は同じクラスの
      別インスタンスでも呼び出せます。クラス設計の際に、外部から呼ばれることを
      想定しない補助メソッドは private にすることで、意図しない依存を防げます。
    BODY
  },

  # ===== データベース / pgvector テーマ =====
  {
    title: "pgvector で類似度検索を PostgreSQL に統合する",
    body: <<~BODY
      pgvector は PostgreSQL の拡張で、固定次元の数値ベクトルを vector 型として
      格納し、コサイン類似度・内積・L2 距離などの距離演算子で類似度検索を行えます。
      pg_trgm のように CREATE EXTENSION で有効化し、専用の索引型として HNSW や
      IVFFlat も利用できます。既存の RDB 上でベクター検索を完結させたい場合の定番です。
    BODY
  },
  {
    title: "コサイン類似度・内積・ユークリッド距離の使い分け",
    body: <<~BODY
      ベクター検索でよく使う距離指標にはコサイン類似度・内積・ユークリッド距離が
      あります。L2 正規化済みのベクトル同士であれば3指標は同じ近傍順序を返すため、
      品質ではなく実装の素直さや説明のしやすさで選ぶのが現実的です。本デモでは
      コサイン類似度を採用しています。
    BODY
  },
  {
    title: "PostgreSQL のインデックスと EXPLAIN の読み方",
    body: <<~BODY
      PostgreSQL のインデックスは B-tree が標準で、Hash・GIN・GiST・BRIN・HNSW
      など用途別の索引型もあります。EXPLAIN ANALYZE を読むと、Seq Scan・Index Scan・
      Bitmap Heap Scan などの選択された実行計画と、実際の処理時間が分かります。
      クエリ最適化の第一歩はこのプランを読み解くことです。
    BODY
  },
  {
    title: "Rails のマイグレーションで外部キーと CASCADE を設定する",
    body: <<~BODY
      add_reference や t.references でカラムを追加する際、foreign_key オプションで
      外部キー制約を有効にできます。on_delete: :cascade を指定すると、親レコードの
      削除時に関連レコードも自動的に削除されます。アプリケーション層の
      dependent: :destroy と組み合わせるか、DB 側に整合性を寄せるかは設計判断です。
    BODY
  },

  # ===== フロントエンド / Hotwire テーマ =====
  {
    title: "Stimulus controllers で軽量なフロントエンド機能を作る",
    body: <<~BODY
      Stimulus は Hotwire の一部で、HTML 上に data-controller 属性を書くだけで
      JavaScript の挙動を結びつけられる軽量フレームワークです。コンポーネント単位で
      スコープを限定でき、サーバーレンダリングを主体とした Rails アプリと
      相性が良いです。フォームのバリデーション補助やドロップダウン制御など、
      小さなインタラクションに向いています。
    BODY
  },
  {
    title: "Importmap で Rails の JavaScript を bundler なしで管理する",
    body: <<~BODY
      Rails 7 から標準採用された Importmap は、ES Modules を Node.js のバンドラー
      なしで読み込む仕組みです。pin コマンドで依存を追加し、config/importmap.rb に
      宣言するだけで利用できます。フロントエンドのビルド工程を持たない小〜中規模
      アプリで威力を発揮します。
    BODY
  },
  {
    title: "Turbo Drive で SPA 風の高速遷移を実現する",
    body: <<~BODY
      Turbo Drive はリンククリックやフォーム送信を fetch に置き換え、ページ遷移時の
      JavaScript・CSS の再評価を避けることで体感速度を向上させます。data-turbo
      属性で挙動を制御でき、特定のリンクだけ通常の遷移にしたいときも簡単に
      設定できます。SPA 化のための JavaScript フレームワーク導入を回避できる
      実用的な選択肢です。
    BODY
  },
  {
    title: "ERB のテンプレートで部分テンプレートを使い回す",
    body: <<~BODY
      ERB の render は部分テンプレート（_partial.html.erb）を呼び出してビューを
      共通化できます。collection オプションで配列を渡すとループで描画でき、locals
      でローカル変数を明示的に渡せます。複雑なロジックは Helper や ViewComponent
      に分離するのが見通しを保つコツです。
    BODY
  },

  # ===== インフラ / 運用 テーマ =====
  {
    title: "Docker Compose で Rails の開発環境を再現可能にする",
    body: <<~BODY
      Docker Compose は複数コンテナをまとめて起動・停止できるツールです。Rails の
      開発では、アプリケーション・PostgreSQL・ジョブワーカーなどを compose.yaml に
      宣言しておくことで、新しい開発者が docker compose up 一発で同じ環境を
      再現できます。ボリュームマウントによりホットリロードも維持できます。
    BODY
  },
  {
    title: "Kamal で Rails アプリを VPS にデプロイする",
    body: <<~BODY
      Kamal は Rails 開発元の 37signals 製のデプロイツールで、Docker イメージを
      指定したホストに SSH 経由でデプロイします。Kubernetes ほどの複雑さを必要とせず、
      かつ Heroku のような PaaS に依存しないという中間的なポジションを担っています。
      Rails 8 では config/deploy.yml の雛形が同梱されています。
    BODY
  },
  {
    title: "Rails のログを構造化して観察可能にする",
    body: <<~BODY
      Rails のログは config.log_tags や TaggedLogging を使うとリクエストごとの
      識別情報を付与できます。本番環境では JSON 形式で出力して fluentd や
      OpenTelemetry に流し込み、メトリクスやトレースと突き合わせるのが一般的です。
      lograge gem で1リクエスト1行に集約する手法もよく使われます。
    BODY
  },
  {
    title: "本番環境の credentials と環境変数の使い分け",
    body: <<~BODY
      Rails では機密情報の扱いとして credentials.yml.enc と環境変数の2系統が
      あります。credentials はコードと一緒にバージョン管理でき、master.key で
      復号する仕組みです。環境変数は実行環境ごとに切り替えやすい一方、
      ヒストリやプロセス一覧から漏れやすいリスクもあるため、用途に応じて
      使い分けるのが現実的です。
    BODY
  },

  # ===== テスト / 品質 テーマ =====
  {
    title: "Minitest で Rails アプリの単体テストを書く",
    body: <<~BODY
      Minitest は Rails のデフォルトテストフレームワークで、シンプルな構文と
      速い実行速度が特徴です。assert・assert_equal・assert_difference などの
      アサーションを使い分け、setup/teardown でテスト前後の準備と後片付けを
      行います。fixtures によるテストデータ投入も組み合わせて使えます。
    BODY
  },
  {
    title: "RSpec と FactoryBot を使った Rails のテスト戦略",
    body: <<~BODY
      RSpec は記述的な DSL で人気の Ruby 製テストフレームワークです。FactoryBot を
      組み合わせると、fixture よりも柔軟にテストデータを生成できます。describe・
      context・it のネストで仕様を表現でき、shared_examples で共通の振る舞いを
      抽出できます。Capybara と組み合わせれば E2E テストも書けます。
    BODY
  },
  {
    title: "システムテストで Hotwire の挙動を検証する",
    body: <<~BODY
      Rails のシステムテストは Capybara を経由して実際のブラウザを操作し、
      JavaScript を含む画面の挙動を検証できます。Selenium や Cuprite を driver に
      使い、Turbo Frame の差し替えや Stimulus コントローラの動作も確認できます。
      毎回起動コストがあるため、ユニットテストでは確認しづらい領域に絞って
      使うのがバランスの取れた使い方です。
    BODY
  },
  {
    title: "Rubocop と Brakeman で Rails のコード品質を保つ",
    body: <<~BODY
      Rubocop は Ruby のコードスタイルチェッカ・自動整形ツールで、rubocop-rails や
      rubocop-rails-omakase の規則を採用すれば Rails 流の慣用に沿ったコードに
      整えられます。Brakeman は静的解析でセキュリティ脆弱性を検出します。CI で
      両方を回しておくと、レビューの認知コストを下げられます。
    BODY
  }
].freeze

ARTICLES.each do |attrs|
  Article.find_or_create_by!(title: attrs[:title]) do |article|
    article.body = attrs[:body]
  end
end

puts "Article count: #{Article.count}"
puts "ArticleEmbeddingJob を bin/jobs ワーカー側で順次処理してください。"
