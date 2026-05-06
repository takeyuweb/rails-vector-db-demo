#!/usr/bin/env ruby
# ADR A-2 §「PoC で確認すべき事項」を検証するスクリプト。
#
# 実行: docker compose run --rm web bin/rails runner script/poc_embedding.rb
#
# 検証項目:
#   1. informers から Xenova/multilingual-e5-base を読み込み、エラーなく初期化できる
#   2. 日本語サンプル文を入力し、長さ 768 の浮動小数配列が返る
#   3. passage と query のコサイン類似度で意味的に近いペアが高い値を返す
#   4. 1 件あたりの推論時間を計測（数百 ms〜数秒に収まること）
#   5. トークン上限 512 を超える長文でも truncation で例外なく完了する

require "benchmark"

embedding_model = Embeddings::InformersMultilingualE5Base.instance

def cosine(a, b)
  a.zip(b).sum { |x, y| x * y }
end

# 検証 1, 2: 初期化と次元
puts "[1/5] 初期化と次元の検証"
short_text = "Rails 8 と pgvector を組み合わせてベクター検索を実装する"
elapsed = Benchmark.realtime do
  vec, mid = embedding_model.embed_passage(short_text)
  puts "  ベクトル次元: #{vec.size}"
  puts "  モデル識別子: #{mid}"
  raise "次元数が 768 ではありません" unless vec.size == 768
end
puts "  初回呼び出し（モデルロード含む）: #{(elapsed * 1000).round}ms"

# 検証 4: 推論時間（モデルキャッシュ済み）
puts "\n[2/5] 推論時間（キャッシュ済み）"
elapsed = Benchmark.realtime do
  embedding_model.embed_passage(short_text)
end
puts "  2回目呼び出し: #{(elapsed * 1000).round}ms"

# 検証 3: 意味的類似度
puts "\n[3/5] 意味的類似度の検証"
related_passage = "PostgreSQL の拡張 pgvector を Rails アプリケーションから利用する方法"
unrelated_passage = "東京の交通網の歴史と発展について"
query = "Rails でベクター検索を導入する手順"

q_vec, _ = embedding_model.embed_query(query)
p_related, _ = embedding_model.embed_passage(related_passage)
p_unrelated, _ = embedding_model.embed_passage(unrelated_passage)

sim_related = cosine(q_vec, p_related)
sim_unrelated = cosine(q_vec, p_unrelated)
puts "  類似ペア cos: #{sim_related.round(4)}"
puts "  非類似ペア cos: #{sim_unrelated.round(4)}"
raise "意味的類似度の順序が逆転しています" unless sim_related > sim_unrelated

# 検証 5: 長文 truncation
puts "\n[4/5] トークン上限超過時の挙動"
long_text = "ベクター検索の解説。" * 200  # 概ね 1500 文字 / 数千トークン
begin
  vec, _ = embedding_model.embed_passage(long_text)
  puts "  例外なく完了: ベクトル次元 #{vec.size}"
rescue => e
  raise "長文入力で例外発生: #{e.class}: #{e.message}"
end

puts "\n[5/5] PoC すべて成功"
