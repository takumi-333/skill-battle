# 設計書

## アーキテクチャ概要

公開運用の状態ファイルを`.local-server`へ集約し、ENet接続を「transport接続」「Lobby consume中」「認証済みsession参加済み」の3段階に分ける。Lobby状態通知は少なくとも1回配送を前提に冪等化し、Dedicated Server側では再送を遅延・上限付きにする。

```text
public.env / public-lobby.db
  └─ .local-server（current user ACL）

UDP peer connected
  └─ join deadline
       ├─ invalid ticket / consume failure → reject → disconnect
       ├─ consume pending → bounded timeout
       └─ consume success + MatchSession.join → authenticated peer

Dedicated status queue
  └─ transient failure → exponential delayed retry
       └─ Lobby idempotent transition → success
```

## コンポーネント設計

### 1. 公開用SQLite保存先とGit管理

**責務**:

- `public-common.ps1`がpublic用DBの絶対パスを`.local-server`配下に決定し、子プロセス環境へ渡す。
- `app.py`はpublic起動時にその明示設定を利用する。
- `.gitignore`はDB本体・`-wal`・`-shm`を同じ規則で除外する。

**実装の要点**:

- 既存`public.env`へ不足キーを補完する移行処理を用意し、旧設定を壊さない。
- DBパスはcurrent-user ACLを持つ`.local-server`外へ向けない。
- 追跡済みバイナリはignoreだけでは残るため、Git indexから明示的に除外する。

### 2. Dedicated Server入室期限

**責務**:

- `peer_connected`時に未認証peerの期限を登録する。
- `_process`で期限切れpeerを切断し、`join_room`の各失敗経路も接続を閉じる。
- consume成功後にだけ期限管理から外し、`peer_rooms`へ登録する。

**実装の要点**:

- consume中はHTTPRequestのtimeoutより少し長い期限を持たせ、正常な遅延を誤遮断しない。
- reject RPCを送る猶予は短く固定し、無認証接続を保持し続けない。
- 切断ハンドラは期限管理とpending requestの後始末を常に行う。

### 3. Lobby状態通知

**責務**:

- `disconnected`は対象slotが既に削除済み、別の新規予約、またはCLOSEDであっても、既存状態を破壊せず成功扱いにする。
- Dedicated Serverはネットワークエラー、429、5xxだけを遅延再送し、認証・契約違反などの4xxは診断して破棄する。

**実装の要点**:

- 重複切断で`RESERVED`行をDELETE対象に含めない。旧通知が新しい予約を消せないことをSQL条件で守る。
- 各キュー要素に試行回数と次回実行時刻を持たせ、再送間隔を上限付き指数バックオフにする。診断ログは値ではなく種別・HTTPコードだけにする。
- 状態通知の順序を保ちつつ、再送待機中の1件が心拍や別roomの通知を無期限に先頭で占有しないキュー構成にする。

### 4. 公開前チェック

**責務**:

- 3プロセスの管理状態とLoopback HTTP連鎖を確認してから公開準備成功を表示する。

**実装の要点**:

- `public-lobby`のPID状態、`127.0.0.1:8000/healthz`、`127.0.0.1:8080/healthz`を確認する。
- Gatewayの応答JSONで`ok=true`と`protected_api_ready=true`を確認し、Lobby停止をGatewayの502としても検出する。
- Funnel / playit.ggの外部状態確認という既存の責務境界は維持する。

## テスト戦略

### Python

- DBの重複切断、旧切断通知と新規予約の競合、公開DBパス設定をテストする。
- Gatewayを含むloopback統合でLobby停止時の健康確認失敗を確認する。

### Godot

- 未認証peerの期限切れ、invalid ticket、consume timeout、正常consumeの状態遷移をヘッドレスで検証する。
- 状態通知の再送判定とバックオフが4xxで高速ループしないことを検証する。

### PowerShell

- public configのDBパス補完とACL対象を検証する。
- `check-public-prerequisites.ps1`の各プロセス停止・health失敗ケースをモック可能な関数へ分離して検証する。

## 実装の順序

1. DB実行時ファイルをGit indexから除外し、公開DBパスを`.local-server`へ移す。
2. Lobbyの切断遷移を冪等化し、Python回帰テストを追加する。
3. Dedicated Serverの未認証peer期限と状態通知バックオフを実装し、Godot回帰テストを追加する。
4. 公開前チェックへLobby PID・health・Gateway準備状態を追加し、PowerShellテストを拡張する。
5. 全自動テスト、headless Dedicated起動、Windows公開ランチャーのloopback統合を検証し、運用手順を更新する。

## セキュリティ考慮事項

- Runtime DB、WAL、SHM、secretをGit・配布物・ログに含めない。
- 未認証UDP peerは入室期限を超えて接続枠を占有できない。
- 状態通知の冪等化はtrusted internal APIだけに限定し、公開APIの認可範囲を広げない。
