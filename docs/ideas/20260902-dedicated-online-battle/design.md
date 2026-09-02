# 設計書

## アーキテクチャ概要

PC版クライアント、ロビーAPI、Godot専用対戦サーバーを分離する。VMには小規模試遊向けにロビーAPIと専用サーバーを同居させるが、通信経路とプロセスは分ける。クライアントはロビーAPIにHTTPSで問い合わせ、試合中だけ専用サーバーへENet/UDPで接続する。

```text
PCクライアント A ─HTTPS─┐
                           ├─ Lobby API (TCP 443) ─ SQLite
PCクライアント B ─HTTPS─┘          │
                                     │ ルーム作成・参加予約
PCクライアント A ──────── UDP 7000 ─┤
                                     └─ Godot Dedicated Server
PCクライアント B ──────── UDP 7000 ─   └─ MatchSession × 最大10
```

### 固定する初期値

| 項目 | 初期値 | 理由 |
| --- | --- | --- |
| VM | OCI Ampere A1、2 OCPU、12GB RAM | Always Free上限を専用サーバーに集中させる。 |
| 対戦サーバー | 1プロセス、UDP 7000 | ENetを継続する。 |
| ルーム定員 | 2人 | 初期対戦仕様に合わせる。 |
| 同時ルーム上限 | 10 | まず20人で計測するための安全な開始値。 |
| シミュレーション | 60 tick/秒 | 現行のリアルタイム操作に合わせ、サーバーで固定する。 |
| 状態送信 | 20回/秒、unreliable | 現行の `STATE_SYNC_INTERVAL = 0.05` を踏襲する。 |
| ロビーAPI | Python 3 + FastAPI + SQLite | 小規模で導入・バックアップが単純であり、ゲームプロセスと障害を分離できる。 |

## コンポーネント設計

### 1. `MatchSimulation` と `MatchSession`

**責務**:

- `MatchState` を保持し、移動、攻撃、課題、ダメージ、勝敗をtickごとに更新する。
- ENet peer ID と `{room_id, player_slot}` を対応付け、ルーム内の2人だけへ結果を送る。
- 切断、入力タイムアウト、満室、試合終了を処理してロビーへイベントを通知する。

**実装の要点**:

- `match_prototype.gd` に混在している `update_player`、攻撃・課題・勝敗の状態更新を、UIに依存しない `scripts/network/match_simulation.gd` へ移す。`Input`、`Control`、`draw_*` はここに置かない。
- `scripts/network/dedicated_server.gd` はENetサーバーを一度だけ開始し、RPCを受けてroom IDから `MatchSession` を引く。各ルームで別の `ENetMultiplayerPeer` を作らない。
- 参加直後にトークンを含む `join_room` RPCを送る。認証済みで空席のときだけslotを確定する。サーバーが割り当てるslot以外の入力は破棄する。
- 移動は正規化して上限速度を越えないようにし、アクションには連番を付けて同一入力の連打・再送を防ぐ。課題回答、ロビー準備、試合結果はreliable、定期入力と状態スナップショットはunreliableにする。

### 2. PCクライアントのネットワーク表示

**責務**:

- ロビーAPIからルーム一覧・参加トークン・接続先を受け取る。
- 自身の入力を送信し、サーバースナップショットを補間して表示する。
- 作成、参加、満室、接続失敗、切断、試合終了をUIで案内する。

**実装の要点**:

- 現行の `start_host()` はデバッグ用ローカルホストとして残し、通常のオンライン画面では呼ばない。新たに `DedicatedClientConnection` を用意して、ロビーの接続情報で `create_client()` を実行する。
- 現在はホストのローカル入力を `MatchPrototype` が直接試合処理しているため、オンライン時は両プレイヤーを同じ `send_input` 経路に統一する。
- `receive_network_state` の補間表示は維持しつつ、状態の作成・判定をクライアントから除く。クライアント独自の勝敗・採点確定を禁止する。
- HTTP通信はGodotの `HTTPRequest` を使い、API失敗時は再試行可能なエラー文と「一覧へ戻る」を表示する。

### 3. Lobby API

**責務**:

- ルームの作成、公開一覧、参加予約、状態更新、期限切れ削除を行う。
- 専用サーバーからのルーム開始・終了通知を受け、表示上の人数と状態を整合させる。
- 参加者用の短命・一回限りトークンを発行する。

**API初期案**:

| メソッド | パス | 用途 |
| --- | --- | --- |
| `POST` | `/v1/rooms` | ルーム名を受け、`room_id` と作成者用参加トークンを返す。 |
| `GET` | `/v1/rooms` | `open` のルーム名・人数・作成時刻を返す。秘密値は返さない。 |
| `POST` | `/v1/rooms/{room_id}/join` | 空席を原子的に予約し、参加トークンとUDP接続先を返す。 |
| `POST` | `/v1/internal/rooms/{room_id}/event` | 専用サーバーのみが開始・切断・終了を通知する。 |
| `GET` | `/healthz` | systemd監視と更新確認用。 |

**実装の要点**:

- SQLiteのトランザクションで定員確認と予約を一度に行う。予約は60秒で失効させ、接続されなければ空席へ戻す。
- トークンは署名付き、10分有効、`room_id`・割当slot・用途を含める。署名鍵は `/etc/skill-battle/server.env` にだけ置く。
- ルーム一覧はIPアドレスやトークンを返さない。ルーム名は文字数・制御文字を検証し、APIにはIPごとのレート制限を設定する。

## データフロー

### ルーム作成から試合開始

```text
1. クライアントAは POST /v1/rooms を呼び、room_id と作成者トークンを得る。
2. クライアントAは UDP 7000へ接続し、join_room(room_id, token) を送る。
3. クライアントBは GET /v1/rooms で一覧を取得し、POST /join で空席を予約する。
4. クライアントBも join_room を送る。専用サーバーはトークンを検証してslot 2へ割り当てる。
5. 両者がキャラクター選択・準備完了を送る。MatchSessionが60Hzで試合を開始する。
6. 各クライアントは入力を送信し、サーバーは20Hzの状態を当該ルームだけへ送信する。
7. 試合終了・切断時、サーバーはルームをclosedにしてLobby APIへ通知する。
```

## VM構築・配備設計

1. OCIでホームリージョンを選び、Always Free対応のUbuntu Arm VMを2 OCPU・12GBで作成する。ブート・ブロックボリューム合計を200GB以内にする。
2. VCNのセキュリティリスト／Network Security Groupで、UDP 7000、TCP 443、管理元固定IPからのTCP 22だけを受信許可する。OSのUFWにも同じ規則を設定する。
3. 管理用の非rootユーザーとSSH鍵を作り、パスワードSSHとrootログインを無効化する。OSの自動セキュリティ更新を有効にする。
4. CIまたは管理PCでGodotのLinux Dedicated Server用ビルドを作成し、成果物をVMの `/opt/skill-battle/server/releases/<version>/` にアップロードする。リポジトリ全体・開発用鍵は置かない。
5. `/opt/skill-battle/lobby/` にFastAPIをvenvで配置し、SQLite DBは `/var/lib/skill-battle/lobby.db` に置く。DBは毎日バックアップする。
6. Caddyを443で稼働させ、APIだけをリバースプロキシする。ドメインを使わない試遊では自己署名証明書の指紋をクライアントへ安全に配布する。一般公開前は独自ドメインとLet's Encryptを必須にする。
7. `skill-battle-server.service` と `skill-battle-lobby.service` を `Restart=on-failure` で有効化し、`journalctl` と `/healthz` で確認する。

## エラーハンドリング戦略

- API不達: 接続情報を生成せず、再試行・一覧に戻る操作を表示する。
- UDP接続失敗: 10秒でタイムアウトし、予約を明示的に取り消すか自然失効させる。
- 無効／期限切れトークン: slotを割り当てず、クライアントを切断してロビー再参加へ戻す。
- 切断: 試合中は即時敗北扱い、待機中はroomをopenへ戻すか、作成者切断ならclosedにする。
- サーバー再起動: 進行中roomを復元しない。API側の予約を失効し、クライアントに「サーバー再起動」を表示する。

## テスト戦略

### ユニットテスト

- `MatchSimulation` の移動上限、攻撃命中、集中中断、課題採点、勝敗、入力連番の検証。
- トークンの署名、有効期限、room/slot不一致、SQLiteの満室競合、予約期限切れの検証。

### 統合テスト

- ローカルで専用サーバー1つとクライアント2つを起動し、作成・参加・90秒試合・切断を確認する。
- VMで異なるネットワークのPC 2台から、一覧→参加→試合→結果へ進めることを確認する。
- 疑似クライアント20人（10ルーム）で、CPU、メモリ、tick遅延、パケット損失、各ルームの独立性を測る。

## 依存ライブラリ

Godot側は既存のENet高レベルマルチプレイヤーAPIを継続して使う。ロビーAPIにはPython 3、FastAPI、Uvicorn、SQLite（標準ライブラリ）を追加する。CaddyはVMのTLS終端にのみ使用する。

## ディレクトリ構造

```text
scripts/network/
  match_simulation.gd
  match_session.gd
  dedicated_server.gd
  dedicated_client_connection.gd
scenes/server_main.tscn
server/lobby/
  app.py
  database.py
  tokens.py
  requirements.txt
deploy/
  systemd/skill-battle-server.service
  systemd/skill-battle-lobby.service
  Caddyfile
  provision-oci.md
  deploy-server.md
tests/network/
```

## 実装の順序

1. 現行試合ロジックをUIから分離し、ローカル専用サーバー＋クライアント2つで同じ試合を再現する。
2. 専用サーバーに複数 `MatchSession` と参加トークン検証を実装し、クライアントの通常導線を切り替える。
3. ロビーAPI、ルーム一覧UI、トークン予約、切断処理を実装する。
4. Linux用成果物、OCI構築手順、systemd、監視・ログを追加する。
5. VM上の外部接続・負荷試験を実施し、上限値を実測で調整する。

## セキュリティ考慮事項

- クライアントが送る位置、HP、スコア、勝敗を信頼しない。
- UDPはTLSで暗号化されないため、ログイン情報や恒久的な個人情報をENet RPCに載せない。初期は匿名の短命参加トークンのみを使う。
- APIはHTTPS、管理SSHは鍵認証と送信元IP制限、秘密値はVM上の権限を絞った環境ファイルに置く。
- RPC入力の型、長さ、頻度、プレイヤーslotを検証する。なぞり座標数など可変長入力には上限を設ける。

## パフォーマンス考慮事項

- ルームごとの状態を分離し、同一roomのスナップショットだけを配信する。
- 入力は小さい構造体、状態は20Hzの差分または必要最小限のスナップショットとし、描画やUI処理をサーバーに含めない。
- 10ルームから計測を始め、CPUが80%を継続して超える、tick遅延、250ms超の同期遅延が出る場合は定員を下げる。無料枠での実用上限は実測値を採用する。

## 将来の拡張性

ルーム管理と試合シミュレーションを分離するため、将来はLobby APIを別VM／DBへ移し、専用サーバーを複数台に増やせる。Web版は現行ENetを流用せず、WebRTCまたはWebSocket専用の接続層を別途設計する。
