# タスクリスト

## フェーズ1: 対戦・Lobbyの回帰修正

- [x] 新規入室の遮断とセッション完全終了を分離し、結果画面の再戦・ロビー復帰を維持する。
- [x] Dedicated Server再起動時に非終端roomを閉じる内部reconcile APIと起動同期を実装する。
- [x] 結果操作と再起動reconcileのPython/Godot回帰テストを追加する。

## フェーズ2: ローカル開発と公開前チェックの修正

- [x] 開発用クライアント設定ファイルの生成・読込とloopback限定HTTP許可を実装する。
- [x] Funnel JSONの厳密なProxy target検査とPowerShellテストを実装する。

## フェーズ3: ドキュメントと検証

- [x] 公開手順書・オンライン対戦仕様を実装に合わせて更新する。
- [x] Python・Godot・PowerShellの回帰テスト、ヘッドレス起動、release exportを実行する。
- [x] tasklistの全完了を確認し、振り返りを記録する。

## 実装後の振り返り

### 実施日

2026-09-11

### 実装結果

- Dedicated Serverは試合終了時に新規入室だけを閉じ、接続済みの2人による再戦・ロビー復帰を継続できるようにした。
- Dedicated Server起動時の内部reconcileで、前回プロセスが残した非終端roomと予約を`CLOSED`へ遷移させるようにした。公開／Lobby consume必須モードでは、この同期が失敗したDedicated Serverは入室を受け付けず終了する。
- `start-local.ps1`はGit管理外かつrelease exportから除外される`local-client.env`を生成し、デバッグ版だけがloopback HTTPと招待tokenを読み込むようにした。
- Funnel JSONのProxy targetを厳密に検査し、Gateway以外または複数targetでは公開前確認を失敗させるようにした。
- `healthz`の公開手順書とオンライン対戦仕様を実装に同期した。

### 検証結果

- Python: `test_tokens.py`、`test_database.py`、`test_lobby_api.py`、`test_public_gateway.py`の14件が成功した。
- Godot: 試合シミュレーション、Dedicated RPC契約、ロビーUIテスト、エディタのヘッドレス起動が成功した。
- PowerShell: Funnel targetの単体テストとWindowsスクリプト13本の構文検証が成功した。
- Windows Client release export、ZIP内容の秘密設定不在確認、生成済み`SkillBattle.exe`のヘッドレス起動が成功した。

### 残る実環境確認

- Tailscale Funnel、playit.gg、別回線を通す実際の公開対戦はアカウント操作と外部状態変更が必要なため、この作業では実施していない。
