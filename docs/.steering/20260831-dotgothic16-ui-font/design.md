# 設計

## テーマ

`resources/themes/dot_gothic16_theme.tres` を Theme リソースとして追加し、`resources/DotGothic16/DotGothic16-Regular.ttf` を `default_font` に設定する。プロジェクト設定の `gui/theme/custom` にこのテーマを指定することで、ルートシーン配下で動的に生成する Control にも継承させる。

## 直接描画テキスト

`MatchPrototype` が `draw_string` で表示するネットワーク時の「あなた」には、同じ TTF を preload した FontFile を渡す。これにより Control 外の文字も UI と書体を統一する。

## 検証

Godot のヘッドレス起動またはエディタ実行が可能なら、テーマリソースとスクリプトの読み込みエラーがないことを確認する。実行環境がなければ、ファイル参照・設定・GDScript 構文を静的確認する。
