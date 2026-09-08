# タスクリスト

- [x] 改善イメージ、既存HUD、対戦中の名前・HP描画経路を確認し、固定ノードとデータ接続を確定する。
- [x] `hud.tscn` を自分・相手の上部HPバーと右端タイマーのレイアウトへ更新する。
- [x] `MatchPrototype` を更新し、両者のHP、`MM:SS` 残り時間、本人・相手の頭上名を接続して頭上HPバーを廃止する。
- [x] Godotヘッドレス起動と関連自動テストを実行し、エラーがないことを確認する。
- [x] 実装・検証結果を振り返り欄へ記録する。

## 実装後の振り返り

- 2026-09-08: `hud.tscn` に固定の相手HPバーを追加し、自分用HPバーと数値ラベルを左上、相手用バーをタイマー左、`MM:SS` タイマーを右上へ再配置した。右下のスキルアイコンクラスターは変更していない。
- 2026-09-08: `MatchPrototype` はローカル操作プレイヤーと相手のHPを個別に更新し、フィールド上のHPバーを削除した。頭上には本人の `あなた` と、相手の同期済み表示名（未設定時はキャラクター名）のみを描画する。
- 2026-09-08: `C:\Godot\godot.exe --headless --path . --quit-after 3` と `C:\Godot\godot.exe --headless --path . --script res://tests/network/match_simulation_test.gd` を実行し、シーン／スクリプトエラーなし、`server-authoritative match simulation tests passed` を確認した。Windows環境の `user://logs` 書き込み・証明書ストア警告は継続して出力されるが、本変更とは無関係である。
