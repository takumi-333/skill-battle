# 要求内容

## 概要

公開対戦サーバーのステージングレビューで判明した4件を修正し、公開時の秘密・状態管理、UDP入室枠、Lobby状態同期、公開前チェックを安全かつ検証可能な状態にする。

## 背景

現在のステージングにはSQLiteの実行時ファイルが含まれ、公開用Lobbyの既定DB保存先もソースツリー内である。また、公開UDPのENet接続は認証前peerを上限まで保持でき、切断通知の再送は409応答で無限リトライする。公開前チェックもLobbyの停止を検出しない。

## 実装対象の機能

### 1. SQLite実行時データの隔離

- ステージング済みの`lobby.db`、`server/lobby/lobby.db-shm`、`server/lobby/lobby.db-wal`をGit管理から除外する。
- `.gitignore`は実行時DB本体とWAL/SHMを同時に無視する。
- 公開ランチャーは`SKILL_BATTLE_LOBBY_DB`を`.local-server`配下の専用ファイルへ設定し、既存`public.env`にも安全な既定値を補完する。
- 公開モードではソースツリーを既定DB保存先として使わない。

### 2. 未認証UDP peerの入室期限

- Dedicated Serverはpeer接続直後から入室期限を管理し、期限内に有効な`join_room`とconsume成功へ至らないpeerを切断する。
- ticket不正、consume失敗、MatchSession登録失敗のpeerも、拒否メッセージ送信後に接続を閉じる。
- 認証済みのpeerとconsume中peerを誤って切断しない。

### 3. 状態通知の冪等化と再送制御

- `disconnected`は、同じslotに対する遅延・重複通知でも安全な成功として扱い、新しい予約を削除しない。
- Dedicated Serverは状態通知の一時的な失敗を最大待機時間付き指数バックオフで再送し、恒久的な4xx応答で無限高速リトライしない。
- 重要な状態通知の順序を維持し、後続の心拍・状態更新が詰まらないようにする。

### 4. 公開前チェックの完全化

- `check-public-prerequisites.ps1`はLobby、Gateway、Dedicated ServerのPID状態を全て検査する。
- LobbyとGatewayのloopback `/healthz`を検査し、Gateway経由で`protected_api_ready=true`まで確認する。
- いずれかが停止・不健全なら成功表示や公開URL共有を行わない。

## 受け入れ条件

### SQLite実行時データの隔離

- [ ] 新規clone・公開起動後もSQLiteの本体/WAL/SHMがGitの追跡対象にならない。
- [ ] 公開LobbyのDBは`.local-server`配下に作成される。
- [ ] 既存`public.env`利用者は手作業なしで安全なDBパスを得る、または明確な移行エラーを受ける。

### 未認証UDP peerの入室期限

- [ ] tokenなしまたは無効tokenのpeerは短時間で切断され、ENet接続枠を保持しない。
- [ ] 有効ticketを持つpeerはconsumeとMatchSession登録の完了まで切断されない。
- [ ] 同一peerの重複joinと切断済みpeerのconsume完了は既存の安全な挙動を維持する。

### 状態通知の冪等化と再送制御

- [ ] 片方のpeerが接続済みの状態で同じslotの`disconnected`を2回受けても、2回とも安全に成功する。
- [ ] 重複した旧切断通知は、その後に発行された`RESERVED`予約を削除しない。
- [ ] 再送失敗が高頻度ループにならず、後続通知を永久に遮らない。

### 公開前チェックの完全化

- [ ] Lobby停止、Gateway停止、Dedicated停止、Lobby/Gateway health失敗の各ケースで前提チェックが失敗する。
- [ ] 3プロセスとGateway経由の保護API準備状態が正常なときだけ成功する。

## スコープ外

- shared invite tokenを個人別認証へ置き換えること。
- UDP経路全体のDDoS対策やENet通信のTLS化。
- Funnel / playit.ggの外部設定をスクリプトから自動変更すること。

## 参照ドキュメント

- `docs/specs/方式B公開対戦サーバー改修計画.md`
- `docs/specs/自宅PC公開対戦サーバー運用方針.md`
- `deploy/windows/PUBLIC_OPERATION.md`
- `deploy/windows/PUBLIC_DAILY_RUNBOOK.md`
