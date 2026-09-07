# タスクリスト

## フェーズ1: 契約と固定tick

- [x] 現行のDedicated Server、セッション、クライアントの通信契約と既存変更を確認する。
- [x] 固定60Hz accumulator、catch-up上限、server tickをDedicated Serverへ実装する。
- [x] `MatchSession` と `MatchProtocol` に入力確認番号・受信者別snapshotを実装する。

## フェーズ2: クライアント状態同期

- [x] root RPCのsnapshot転送を`unreliable_ordered`へ統一する。
- [x] Dedicated snapshotの離散状態反映と補間バッファを実装する。
- [x] プレイヤーとスキル実体の補間を既存描画状態へ接続する。

## フェーズ3: テスト・仕様更新

- [x] プロトコル、固定tick、補間、受信者別課題snapshotの自動テストを追加・更新する。
- [x] オンライン対戦アーキテクチャ仕様を実装内容へ更新する。
- [x] Godotヘッドレステスト、Pythonテスト、Dedicated Server／メインシーンのヘッドレス起動を実行する。

## 実装後の振り返り

### 実装完了日

2026-09-07

### 計画と実績の差分

- 状態送信頻度は20Hzのままとした。固定60Hzシミュレーション、`unreliable_ordered`、表示補間により、通信量を3倍にせずに見た目の連続性を改善するためである。
- 完全な差分同期は導入せず、受信者本人の課題だけを送ることと、プレイヤー状態からサーバー専用フィールドを除外する軽量化を実装した。欠落し得る状態snapshotで安全な差分同期には、受信確認を使うベースライン管理が必要なためである。
- 入力確認番号はsnapshotへ追加した。入力履歴の再生による完全なクライアント予測は、固定tickと確認番号を基盤として次の段階で導入できる。

### 検証結果

- `tests/network/match_simulation_test.gd` と `tests/network/lobby_ready_ui_test.gd` をGodotヘッドレスで実行し、成功した。
- Dedicated ServerをUDP 17001、検証用tokenでヘッドレス起動し、固定tick版として待受開始できることを確認した。
- 通常のメインシーンをヘッドレス起動してパースを確認した。
- Pythonのtoken／SQLiteテストを、pytest未導入のため各テストを独立した一時DBで直接実行して成功した。
- Godotのログ保存先とWindows証明書ストアの警告は実行環境由来であり、テスト・パース・Dedicated Server起動の成功を妨げなかった。

### 学んだこと

- 継続的な状態同期では、古い状態を保証するreliable転送よりも、最新状態を優先する`unreliable_ordered`と補間の組み合わせが適する。
- snapshotの軽量化は、差分同期より先に受信者別の情報削減を行うと、欠落時の復旧契約を増やさず安全に進められる。
