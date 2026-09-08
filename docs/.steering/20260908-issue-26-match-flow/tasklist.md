# タスクリスト

## フェーズ1: 設計と基盤

- [x] 既存の対戦開始・フィールド・UI構成と仕様を確認する。
- [x] 対戦仕様を新しいフィールド寸法、90 秒、READY / FIGHT フローへ更新する。
- [x] ローカルとサーバー権威シミュレーションのフィールド寸法・開始位置を統一する。

## フェーズ2: 開始フローとUI

- [x] Dedicated Server の開始 phase・snapshot を READY 待機と FIGHT 開始に対応させる。
- [x] ローカル対戦の開始フローを READY 待機と FIGHT 開始に対応させる。
- [x] シーン定義の開始表示 UI を追加し、ローカル・オンライン snapshot へ接続する。

## フェーズ3: 検証

- [x] 対戦シミュレーション・セッション・UI テストを追加または更新する。
- [x] Godot headless テストと起動確認を実行し、検出された問題を修正する。

## フェーズ4: 記録

- [x] すべてのタスク完了を確認し、振り返りと自動実行メモリを更新する。

## 実装後の振り返り

- 2026-09-08: 対戦フィールドを 1680 x 774 px、開始位置を P1 `(200, 260)`・P2 `(1480, 260)` に統一した。試合時間はローカル・Dedicated Server とも既存の 90 秒設定を維持し、仕様にも明記した。
- 2026-09-08: 開始時は 1 秒の `READY` phase を経由し、`FIGHT` と同時に試合 phase と計時を開始するようにした。Dedicated Server は countdown と残り時間を snapshot で同期し、この間の入力・イベントを拒否する。
- 2026-09-08: `scenes/ui/match_start_prompt.tscn` を追加し、ローカル・オンライン双方で固定UIとして開始表示を行うようにした。
- 2026-09-08: `tests/network/match_simulation_test.gd`、`tests/network/lobby_ready_ui_test.gd`、`tests/network/rpc_contract_test.gd` と `godot --headless --path . --quit-after 3` が成功した。`user://logs` と Windows 証明書ストアの警告は環境由来で、テスト・起動の成否には影響しなかった。
