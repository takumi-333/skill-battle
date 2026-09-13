# タスクリスト

- [x] 詠唱士用なぞりウィンドウとキャンバスのレイアウトを拡大する。
- [x] ローカル・オンライン用の図形座標とサイズを中央配置・拡大後の値へそろえる。
- [x] 関連テストを更新し、Godot のヘッドレス検証を実行する。

## 検証結果

- `godot --headless --path . --script res://tests/network/match_simulation_test.gd`: 成功。
- `godot --headless --path . --quit-after 3`: 起動成功。`user://logs` への書き込みと Windows 証明書ストアの既存環境エラーのみを出力した。
- `git diff --check`: 成功。
