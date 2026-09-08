# タスクリスト

## フェーズ1: 入力処理の修正

- [x] マウスダウン時だけキャンバス内判定を適用する。
- [x] マウスアップ時に位置を問わず既存の採点・送信経路へ進める。

## フェーズ2: 検証

- [x] 変更箇所を確認し、外側での解放が早期 return されないことを検証する。
- [x] Godot のヘッドレス検証を実行し、エラーがないことを確認する。

## 実装後の振り返り

### 実装完了日

2026-09-09

### 計画と実績の差分

- 外側で離したマウスアップを有効な一筆書きの完了として扱うため、`challenge_trace_drawing` を追加した。
- これにより、キャンバス外から始めたクリックがマウスアップだけで採点されることも防止した。

### 検証結果

- `godot --headless --path . --quit-after 3` を実行し、スクリプトエラーなしで起動した。
- `godot --headless --path . --script res://tests/network/match_simulation_test.gd` を実行し、成功した。
- `godot --headless --path . --script res://tests/network/lobby_ready_ui_test.gd` を実行し、成功した。
