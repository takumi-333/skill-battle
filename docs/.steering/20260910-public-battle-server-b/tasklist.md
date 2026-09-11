# タスクリスト

## フェーズ0: 現状固定とテスト基盤

- [x] Python・Godot既存テストとヘッドレス起動の基準を実行し記録する（Python環境はpytest未導入、Godotのsimulation/RPC契約は成功。UIテストは既存のcharacter-skill persistence assertionとuser:// log書込み警告を出すが終了コード0）。
- [x] 認証、nonce再利用、同時予約、状態不整合を検出するテストを追加する。

## フェーズ1: Lobbyの認証・原子的状態機械

- [x] 4 secretのfail-closed設定検査、公開／内部認証、公開APIレート制限を実装する。
- [x] room、reservation、nonce schemaと `BEGIN IMMEDIATE` の原子的遷移を実装する。
- [x] consume・connected・disconnected・running・closed・lease回収を実装する。
- [x] Lobby単体・競合テストを追加し通す。

## フェーズ2: Dedicated Server認証と同期

- [x] peerごとのconsume request、timeout、constant-time HMAC比較、公開loopback bindを実装する。
- [x] Lobbyへの状態通知とMatchSessionの参加／開始制約を実装する。
- [x] Godotネットワーク契約と専用サーバー起動を検証する。

## フェーズ3: Public Gateway

- [x] Gateway ASGIアプリ、endpoint／入力／header／body allowlist、固定upstreamを実装する。
- [x] GatewayテストとFunnel target検査用の運用部品を追加する。

## フェーズ4: クライアント設定UI

- [x] Lobby HTTPS URLとshared invite tokenの固定入力欄、保存、事前検証を実装する。
- [x] DedicatedClientConnectionの認証headerとURL検証を実装する。

## フェーズ5: Windows公開運用

- [x] 公開用3プロセスのstart／stop／status、secret生成、ACL、PID・health・port検査を実装する。
- [x] Funnel設定・公開前確認・停止／ローテーション手順を追加する。

## フェーズ6: 総合検証と振り返り

- [x] Pythonテスト、Godotテスト・ヘッドレス起動、PowerShell構文検証を実行する（Python 12件、Godot simulation/RPC/UI、公開モードDedicated起動、main headless、PowerShell構文、Lobby+Gateway実プロセス統合を確認）。
- [x] 実環境でのみ可能な公開確認の手順と未実施理由を記録する（`deploy/windows/PUBLIC_OPERATION.md`。Funnel / playit.gg / 別回線は実アカウントと外部公開操作を要するため未実施）。
- [x] tasklistを実績と振り返りで更新する。

## 実装後の振り返り

### 実装完了日

2026-09-11

### 計画と実績の差分

- Gatewayはモックだけで終えず、一時的なloopback Lobby／Gatewayプロセスを起動して、認証済み作成・一覧と`/admin`遮断を確認した。
- Godotの`user://`は実行環境で書込み不可だったため、既存のキャラクター保存テストは書込み可否を検出して安全にskipするよう修正した。公開設定の静的UI・URL検証は同じテストで確認した。
- Funnel / playit.gg / 別回線を使う外部公開は、ユーザーの実アカウントと状態変更を必要とするため実行していない。

### 学んだこと

- nonce消費、予約状態、Dedicated Serverのpeer登録を別々に成功扱いにすると状態がずれるため、consume後の失敗も`disconnected`通知とlease回収へ明示的に接続する必要がある。
- 3プロセス停止と外部ingress停止は別責務であり、停止コマンドがFunnel / playit.ggを暗黙に管理しないことを明示する必要がある。

### 次回への改善提案

- 初回公開時は`check-public-prerequisites.ps1`の後、外部回線で90秒試合、切断、secretローテーションを実施し、結果を運用記録へ残す。
- 実機のGodot実行環境で`user://settings.cfg`へのURL・token保存と再起動後の接続を確認する。
