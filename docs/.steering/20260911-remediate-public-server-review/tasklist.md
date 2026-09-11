# タスクリスト

## フェーズ1: SQLite実行時データの隔離

- [x] 追跡済みの`lobby.db`、`server/lobby/lobby.db-wal`、`server/lobby/lobby.db-shm`をGit indexから除外する。
- [x] `.gitignore`をDB本体・WAL・SHMを含む実行時ファイル規則へ更新する。
- [x] `public.env`へpublic DBパスを追加・既存設定へ補完し、`.local-server`配下へ保存する。
- [x] 公開LobbyがソースツリーへDBを作成しないことを検証する。

## フェーズ2: 未認証UDP peerの接続枠保護

- [x] Dedicated Serverへ未認証peer期限、consume中状態、拒否後切断を実装する。
- [x] peer切断・consume完了・session登録の後始末を整理する。
- [x] tokenなし、無効token、consume timeout、正常joinのGodot回帰テストを追加する。

## フェーズ3: 状態通知の冪等化と再送制御

- [x] Lobbyの`disconnected`遷移を、新規予約を壊さない冪等操作へ変更する。
- [x] Dedicated Serverの状態通知に最大待機時間付き指数バックオフ、4xxの停止処理、再送待機中のキュー分離を実装する。
- [x] 重複切断、応答取りこぼし、後続心拍・状態通知の回帰テストを追加する。

## フェーズ4: 公開前チェックの完全化

- [x] `check-public-prerequisites.ps1`へLobby PID状態とLobby/Gateway health確認を追加する。
- [x] Gateway経由の`protected_api_ready=true`確認を追加する。
- [x] Lobby/Gateway/Dedicatedの停止・不健全ケースをPowerShellテストで検証する。
- [x] 日常運用手順の成功条件を3プロセス・health確認と一致させる。

## フェーズ5: 総合検証

- [x] PythonのLobby/Gateway/DBテストを実行する。
- [x] GodotのnetworkテストとDedicated Server headless起動を実行する。
- [x] PowerShell構文・単体テストを実行する。
- [x] 実行時DB・WAL・SHMがステージング対象外であることを確認する。

## 実装後の振り返り

- 未認証ENet peerは8秒で切断し、妥当なチケットのconsume中だけHTTP timeoutを越える短い猶予を付与する。拒否応答は送信機会を残してから切断する。
- `room_status`はroomごとの順序を維持し、通信失敗と408/429/5xxだけを最大10秒の指数バックオフで再送する。恒久的な4xxは再送せず警告にする。
- SQLite実行時データはGit indexから除外し、public起動時のDBを`.local-server/public-lobby.db`に固定した。既存`public.env`は不足するDB設定を補完する。
- 実サービスのpublic launcher loopback統合は、保護された既存`.local-server/public.env`へsandboxからアクセスできないため実行していない。PowerShellの単体テストでは同等の一時設定でDB設定移行とhealth判定を確認した。
