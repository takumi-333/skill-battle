# タスクリスト

- [x] 完成イメージ、既存背景・立ち絵・UI素材を確認し、使用する固定ノードとデータ接続を確定する。
- [x] `result_screen.tscn` を暗影背景、上半分の立ち絵、試合時間一行表示、下部成績パネルの構成へ更新する。
- [x] `MatchPrototype` を更新し、選択キャラクターの立ち絵、勝敗名、HP表示、平均点、引き分け時の表示を接続する。
- [x] Godot headless 起動および結果画面に関係する自動テストを実行し、エラーがないことを確認する。
- [x] 実装・検証結果を振り返り欄へ記録する。

## 実装後の振り返り

- 2026-09-08: `menu_background.png` と既存のキャラクター立ち絵を再利用し、暗影背景・立ち絵主体の上半分・勝利章・一行の日本語試合時間へリザルト画面を再構成した。新規画像生成は行っていない。
- 2026-09-08: 勝者／相手ごとに独立したHP・平均スキル点ラベルを接続し、空白文字による二列の位置合わせを廃止した。HPは `現在値 / 100` で表示する。
- 2026-09-08: `C:\Godot\godot.exe --headless --path . --quit-after 3` と `C:\Godot\godot.exe --headless --path . --script res://tests/network/match_simulation_test.gd` を実行し、シーン／スクリプトエラーなし、`server-authoritative match simulation tests passed` を確認した。Windows環境の `user://logs` 書き込み・証明書ストア警告は継続して出力されるが、本変更とは無関係である。
