# タスクリスト

- [x] 試合時間の定義と初期表示を150秒へ統一する。
- [x] 対戦仕様と運用仕様の試合時間を150秒へ更新する。
- [x] ネットワークテストとGodotヘッドレス起動で変更を検証する。

## 検証結果

- `godot --headless --path . --script res://tests/network/match_simulation_test.gd`: 成功（server-authoritative match simulation tests passed）。
- `godot --headless --path . --quit-after 3`: 起動成功。既存環境により `user://logs` の書き込みとWindows証明書ストア読み取りのエラーが出力されたが、スクリプトエラーはない。
- `git diff --check`: 成功。
