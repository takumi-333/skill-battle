# タスクリスト

- [x] ノイズ状態とデコイの既存描画・同期値を確認する。
- [x] ノイズ状態のプレイヤー頭上へ青いノイズ演出を追加する。
- [x] 敵HPバー下に算術士の倍率表示部品を追加する。
- [x] 敵キャラクター・倍率に応じて表示を更新する。
- [x] 算術士スキル仕様書へ頭上ノイズと敵側倍率表示を追記する。
- [x] Godot起動および差分チェックを行う。

## 検証結果

- `godot --headless --path . --quit-after 3`: 成功。既知の `user://logs` とルート証明書ストアの警告のみ。
- `godot --headless --path . --script res://tests/network/match_simulation_test.gd`: 成功（`server-authoritative match simulation tests passed`）。
- `git diff --check`: 空白エラーなし（改行コード変換の警告のみ）。
