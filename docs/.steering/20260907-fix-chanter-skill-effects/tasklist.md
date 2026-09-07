# タスクリスト

- [x] 魔法陣の出現遷移で位置補間を行わないよう修正する。
- [x] 詠唱士スキル2の弾が初期16方向を保持するよう修正する。
- [x] 両方の回帰を検証する自動テストを追加する。
- [x] Godotテストとヘッドレス起動を実行し、検証結果を記録する。

## 検証結果

- `godot --headless --path . --script res://tests/network/match_simulation_test.gd`: 成功。魔法陣出現時の補間位置と、詠唱士スキル2弾の放射方向を検証。
- `godot --headless --path . --script res://tests/network/lobby_ready_ui_test.gd`: 成功。
- `godot --headless --path . --quit-after 3`: 成功。起動時のスクリプトエラーなし。
- `user://logs` の書き込みとWindows証明書ストアに関する環境警告は出たが、全コマンドの終了コードは0だった。

## 振り返り

- 非表示状態のプレースホルダー座標を、可視化開始時の位置補間に使わない。
- 弾の初期方向と発射時に狙い直す方向を区別し、大技の放射弾には後者を適用しない。
