# タスクリスト

## フェーズ1: 着地イベントの状態化

- [x] 三叉震槌に安定したIDを付与し、Dedicated snapshotへ渡す。
- [x] ローカルとDedicated clientで、着地時のみ一度画面揺れを開始する。

## フェーズ2: 描画修正

- [x] ハンマーの前面に波紋・亀裂を描き、着地点から連続して見えるようにする。

## フェーズ3: 検証

- [x] 着地イベントと画面揺れの回帰テストを追加・更新する。
- [x] Godotヘッドレステストおよびメインシーン起動で確認する。

## 実装後の振り返り

- [x] 実装結果、検証結果、計画との差分を記録する。

### 実装完了日

2026-09-07

### 実装結果

- 波紋・亀裂をハンマー描画の後へ移し、ハンマーの不透明領域で欠けない前景演出に変更した。
- 三叉震槌の開始時に行っていた画面揺れを、着地して `released` になる時点へ移した。
- Dedicated server の三叉震槌状態へ `impact_id` を追加し、Dedicated client が `released` の遷移を一度だけ検知して画面揺れを再生するようにした。

### 検証結果

- `godot --headless --path . --script res://tests/network/match_simulation_test.gd` は成功した。
- `godot --headless --path . --script res://tests/network/lobby_ready_ui_test.gd` は成功した。終了直後にテスト環境の自己RPC警告が出るが、今回の着地処理には起因しない。
- `godot --headless --path . --editor --quit` と `godot --headless --path . --quit-after 3` は、プロジェクト由来のエラーなく終了した。証明書ストア、ログ、エディター設定の保存警告は実行環境の権限制約によるもの。

### 計画との差分

- 着地イベントを新規ネットワークメッセージにせず、既存の `trident_impacts` snapshot に安定IDを加え、`released` 遷移をクライアントで消費する方式にした。既存プロトコルへの変更を最小化しながら、重複スナップショットでの再発火を防げるためである。
