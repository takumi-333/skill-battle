# 方式B公開対戦サーバー改修計画

最終更新: 2026-09-10

## 1. 目的

`自宅PC公開対戦サーバー運用方針.md`で採用した方式Bを、安全に実装・公開できる状態へ改修する。

ホストPCでLobby API、公開用Gateway、Godot Dedicated Serverを動かす。友人はTailscaleやplayit.ggを導入せず、ゲーム本体にLobby HTTPS URLと招待アクセストークンを設定して参加する。

```text
友人のゲームクライアント
  ├─ HTTPS :443 → Tailscale Funnel → 127.0.0.1:8080 Public Gateway → 127.0.0.1:8000 Lobby API
  └─ ENet / UDP → playit.gg agent → 127.0.0.1:7000 Dedicated Server
                                                              ホストPC
```

Funnelの外部HTTPS待受は`:443`（またはFunnelが許可する`:8443` / `:10000`）であり、`:8080`はホストPC内のGateway待受である。Lobby APIとGatewayはloopbackでのみ待ち受け、Funnelが外部公開する対象はGatewayだけとする。Lobby APIの`:8000`を直接公開してはならない。

## 2. セキュリティ境界と前提

- Funnelは公開インターネットからGatewayへ到達させるreverse proxyであり、認証境界ではない。URLを知る第三者からのアクセスも想定し、GatewayとLobbyで認証・入力制限を行う。
- 公開APIの入口は、全友人で共有する1個のローテーション可能な招待アクセストークン（shared invite token）とする。友人ごとの個別tokenは今回の対象外である。
- `SKILL_BATTLE_PUBLIC_ACCESS_TOKEN`、`SKILL_BATTLE_ADMIN_TOKEN`、`SKILL_BATTLE_INTERNAL_API_TOKEN`、`SKILL_BATTLE_TOKEN_SECRET`は用途を分離する。起動時に4値が十分な長さの暗号学的乱数であること、および値の重複がないことを検査し、満たさなければ起動を失敗させる。
- UDP経路はTLS化しない。参加tokenの一回限りの消費は、正規clientが使った後のreplayを防ぐが、盗聴者が正規clientより先に使うfirst-use raceを防ぐものではない。この残余リスクは少人数の友人対戦では受容する。admin token・internal token・恒久的な秘密値はUDPやクライアントへ配布しない。
- Lobbyは単一のプロセス・単一のuvicorn workerで動かす。メモリ内レート制限とプロセス内lockを複数worker間で共有しないためである。

## 3. 到達条件

改修完了時は、次を満たす。

1. 友人は追加のネットワークソフトなしで、ゲームにHTTPS URLとshared invite tokenを入力して接続できる。
2. 外部から到達するHTTP経路は、`/healthz`、認証済みのルーム一覧・作成・参加予約だけである。
3. `/admin`、`/admin/api/*`、`/internal/*`、SQLite DB、Lobbyの`:8000`は外部公開されない。
4. Dedicated Serverは、正しい署名・期限・room/slotを持ち、Lobby上で未消費のnonceに対応する参加tokenを一度だけ受理する。
5. ルーム・予約・nonceの状態遷移が原子的であり、TTL、切断、試合開始・終了によりLobbyとDedicated Serverの状態が矛盾しない。
6. Windowsで3プロセスを標準ユーザー権限で管理できる。またFunnel / playit.ggの権限境界と、公開を先に遮断する停止手順が明文化され、秘密値をGit・ログ・コマンドラインに残さない。

## 4. 状態機械と不変条件

Lobbyはnonceだけでなく、予約とルームの状態を管理する。状態と遷移を次に固定する。

```text
AVAILABLE
  └─ reserve → RESERVED
                 └─ consume → CONNECTING
                                └─ Dedicated Serverがpeer登録成功を通知 → CONNECTED
                                                                             └─ match start → RUNNING
                                                                                                └─ finish / abort → CLOSED
```

- `consume`はSQLiteトランザクション内で、`nonce`が未使用かつ未期限切れ、room/slotが一致し、予約状態が`RESERVED`の場合だけ実行する。成功時は`nonce.used_at = now`と予約状態`CONNECTING`への変更を同時に確定する。
- `CONNECTING`には短いleaseを持たせる。Dedicated Serverから`connected`通知がない、または接続前に切断された場合だけ、定義した回収手順で予約を解放できる。nonceを未使用へ戻してはならない。
- `CONNECTED`以降の切断・試合終了処理はDedicated Serverの内部通知に基づく。`RUNNING`は予約TTLや接続前leaseで`AVAILABLE`へ戻してはならず、`CLOSED`へのみ遷移できる。`CLOSED`は再び待機・進行中にならない。
- crash recovery時も、`CONNECTING`のlease切れだけを回収対象とする。`RUNNING`の予約を時間だけで解放しない。

必ず満たす不変条件:

1. 一つのslotを同時に複数peerへ割り当てない。
2. 消費済みnonceは再び未使用にならない。
3. `RUNNING`中のslotはTTLやdisconnectだけで解放されない。
4. `CLOSED` roomは再び待機・進行中にならない。
5. Dedicated Serverが認証完了していないpeerを`MatchSession`のplayerとして数えない。

## 5. 改修計画

### フェーズ0: 現状固定とテスト基盤

対象: `tests/network/`、`server/lobby/`、`scripts/network/`

1. 既存のPythonテスト、Godotネットワークテスト、Godotヘッドレス起動を実行し、改修前の基準を記録する。
2. 現行の認証不足、token再利用、同時予約、room status不整合を再現する失敗テストを追加する。
3. 既存のローカル対戦・ローカルLobby利用が改修後も動くことを回帰条件として固定する。

完了条件:

- 以降の改修で直すべき挙動をテストが失敗として検出する。
- 既存の試合シミュレーション・RPC契約テストが実行可能である。

### フェーズ1A: Lobby API、認証、SQLiteトランザクション

対象: `server/lobby/app.py`、`database.py`、`tokens.py`、Pythonテスト、起動設定

1. 4種の秘密値について、起動時の設定漏れ・長さ・重複検査を追加する。設定漏れ時はfail closed（protected APIは503）とする。
2. `SKILL_BATTLE_PUBLIC_ACCESS_TOKEN`を追加し、`/v1/*`で`X-Skill-Battle-Access-Token`を必須にする。管理token・内部tokenとの兼用を禁止する。
3. `/internal/rooms/{room_id}/status`を含む全`/internal/*`へ`SKILL_BATTLE_INTERNAL_API_TOKEN`認証を適用する。
4. 公開APIにメモリ内レート制限を追加する。ルーム一覧、作成、参加を別々に制限し、有効なshared invite tokenを主キーにする。429には`Retry-After`を付与し、tokenやURLをログに出さない。
5. Lobbyを`1 process / uvicorn workers = 1`で起動する設定とする。`LobbyDatabase`の状態変更はプロセス内lockと`BEGIN IMMEDIATE`、明示的な`COMMIT` / `ROLLBACK`で保護し、`SQLITE_BUSY`を安全に処理する。

完了条件:

- 不正な公開・内部tokenは401、設定漏れは503、上限超過は`Retry-After`付き429となる。
- 単一worker以外でのLobby起動を公開用設定が許さない。
- token・URLをログに出さない。

### フェーズ1B: Room / Reservation / Nonce状態機械

対象: `server/lobby/database.py`、`app.py`、`tokens.py`、Python統合・競合テスト

1. room、reservation、nonceのSQLite schemaとAPI契約に、`AVAILABLE`、`RESERVED`、`CONNECTING`、`CONNECTED`、`RUNNING`、`CLOSED`を反映する。
2. 参加token発行時にランダムnonceをSQLiteへ未使用で保存する。
3. Dedicated Server専用の内部`consume` APIを追加する。`nonce unused AND not expired AND room_id一致 AND slot一致 AND reservation = RESERVED`の場合だけ、`nonce.used_at = now`と`reservation = CONNECTING`を単一の`BEGIN IMMEDIATE`トランザクションで確定する。
4. `connected`、`disconnected`、`running`、`closed`の内部状態通知と、`CONNECTING` leaseの回収規則を定義・実装する。`RUNNING`をTTLや予約回収で公開可能へ戻す経路を作らない。
5. reserve、consume、切断、期限切れ、match start、finish、Dedicated Server crashの順序を変えた競合テストを追加する。

完了条件:

- 同じ参加tokenの2回目のconsumeは失敗する。
- 同じルームへの競合予約で同じslotを複数発行しない。
- `RUNNING` roomは90秒超でも空室として再公開されない。
- 状態機械の不変条件をテストで検証する。

### フェーズ2: Dedicated Serverの入室認証と状態同期

対象: `scripts/network/dedicated_server.gd`、`match_session.gd`、Godotネットワークテスト

1. `join_room`を「署名・期限・room/slotのローカル検証」の後に「Lobbyへのnonce consume要求」を行う二段階処理へ変える。
2. `peer_id`ごとに`HTTPRequest` Nodeを生成し、`pending_consume_requests: peer_id -> HTTPRequest`として保持する。同一peerの重複joinを拒否し、完了時・切断時・失敗時にNodeを解放する。1 Nodeを並行requestに共有しない。
3. 各consume requestに有限のtimeout（1～数秒）を設定する。timeout、HTTP失敗、内部認証失敗、consume拒否ではfail closedとし、peerをplayerへ登録しない。
4. HMACはhex文字列を比較せず、`PackedByteArray`のdigestを`Crypto.constant_time_compare()`で比較する。
5. Lobbyでconsume成功後にpeerを登録できたときだけ`connected`を通知する。接続前失敗・切断、全員切断、試合開始、試合終了・abortでは定義済みの内部状態通知を送る。
6. `MatchSession.join`を待機状態だけに限定し、result状態への新規参加を拒否する。`MatchSession.start`自身で両者Readyを確認し、直接RPCによる未準備開始を防ぐ。
7. 公開モードの`ENetMultiplayerPeer`は`set_bind_ip("127.0.0.1")`でloopbackにbindする。LAN対戦を許す開発モードだけwildcard bindを明示的に許可する。

完了条件:

- 未消費tokenだけで1回入室でき、再利用・期限切れ・通信失敗では入室できない。
- ほぼ同時の複数joinでも各peerのconsumeが独立して処理される。
- Ready未完了、result状態への参加、未認証peerのplayer計上をDedicated Server側で拒否する。
- 90秒超の試合でもLobby一覧が進行中ルームを空室として再公開しない。

### フェーズ3: Public Gateway

対象: `server/public_gateway/`（新設）、Gatewayテスト、依存パッケージ

Gatewayは汎用reverse proxyではなく、次の4 endpointだけを実装するadapterとする。`room_id`はUUID等の厳密な型・正規表現で検証する。

| method | exact path | query | body |
| --- | --- | --- | --- |
| GET | `/healthz` | なし | なし |
| GET | `/v1/rooms` | 仕様で使用するものだけ | なし |
| POST | `/v1/rooms` | なし | JSONのみ |
| POST | `/v1/rooms/{room_id}/join` | なし | JSONのみ |

1. `127.0.0.1:8080`で待ち受ける別ASGIアプリを追加する。
2. method、exact path、query、room_id、request header、bodyをallowlistで検査する。使用しないquery、許可外header、許可外method/pathは拒否する。
3. POSTは`application/json`だけを受け付け、実際に読み取ったbody byte数で上限を適用する。
4. upstreamは`http://127.0.0.1:8000`に固定する。redirectは追跡せず、connect/read/writeに有限のtimeoutを設定する。
5. クライアント由来の`Host`、`Connection`、`Forwarded`、`X-Forwarded-*`などhop-by-hop・転送系headerをLobbyへ渡さない。必要な`Content-Type`とaccess tokenだけを新規に構成して渡す。
6. upstream内部例外や詳細を外部へ返さず、安全な502等へ変換する。
7. Funnelは`HTTPS :443 → 127.0.0.1:8080`だけへ向ける。公開開始前に`tailscale funnel status`を確認し、targetが`127.0.0.1:8080`以外なら公開開始を拒否する。

完了条件:

- Gateway経由で認証済みの作成・一覧・参加予約が成功する。
- `/admin`、`/internal/*`、未定義path、余分なquery、許可外header、巨大body、外部upstream指定がGatewayで拒否される。
- Lobbyを停止した場合、Gatewayは内部詳細を漏らさないエラーを返す。

### フェーズ4: クライアント設定UI

対象: `scenes/ui/home_screen.tscn`、`scripts/match_prototype.gd`、`scripts/network/dedicated_client_connection.gd`

1. 既存のユーザー設定モーダルへ、Lobby HTTPS URLとshared invite tokenの固定入力欄を追加する。
2. tokenはpassword表示とし、ログ・デバッグ表示・画面タイトルには出さない。値を`user://settings.cfg`へ保存し、起動時に読み込む。
3. `DedicatedClientConnection`が全Lobby APIリクエストへ`X-Skill-Battle-Access-Token`を送るようにする。
4. URLはHTTPSだけを受け付ける。ただし既存ローカル開発URLを使う開発モードは明示設定時だけ許可する。
5. UIの固定部品はシーンに定義し、スクリプトは値の検証・保存・接続への適用だけを担当する。

完了条件:

- 友人は共有されたURLとtokenを設定し、再起動後も接続できる。
- tokenを空欄・不正URLのままオンライン接続しようとすると、ネットワーク要求前に分かるエラーを表示する。
- 既存のユーザー名設定と画面遷移が壊れない。

### フェーズ5A: Windows公開用3プロセスの管理

対象: `deploy/windows/`、`deploy/`、`docs/specs/`

1. 標準ユーザーで実行する`start-public.ps1`、`stop-public.ps1`、`status-public.ps1`を追加する。これらが管理するのはLobby、Gateway、Dedicated Serverの3プロセスだけである。
2. `.local-server/public.env`を初回に生成し、次の値を分離して保存する。秘密値をコマンドライン引数で子processへ渡さず、親processが環境変数として読み込み、必要な子processへ渡す。

   | 設定 | 用途 |
   | --- | --- |
   | `SKILL_BATTLE_TOKEN_SECRET` | LobbyとDedicated Server間の参加token署名 |
   | `SKILL_BATTLE_ADMIN_TOKEN` | 管理API専用 |
   | `SKILL_BATTLE_INTERNAL_API_TOKEN` | Dedicated Serverの内部API専用 |
   | `SKILL_BATTLE_PUBLIC_ACCESS_TOKEN` | 友人全員で共有する招待アクセストークン |
   | `SKILL_BATTLE_SERVER_ADDRESS` / `PORT` | playit.ggが割り当てた公開UDP接続先 |

3. `.local-server/`、`public.env`、PID、stateファイルをGit管理・配布対象外にし、Windows ACLでcurrent userだけが読み書きできるようにする。
4. 起動スクリプトはPIDと開始時刻を記録し、同一プロセスだけを停止できるようにする。URL・秘密値の設定漏れ、8000/8080/UDPポート競合、Gateway/Lobby health check失敗を起動時に検出する。

完了条件:

- Windowsの標準ユーザー権限で公開用3プロセスを起動・停止・状態確認できる。
- `.local-server/`配下の秘密値と状態ファイルはcurrent user以外から読めず、Gitにも含まれない。
- 実アカウントを使う外部確認手順が、秘密値を表示せず実行できる。

### フェーズ5B: Tunnel権限境界と停止手順

対象: `deploy/windows/`、運用方針書、公開前チェック

1. `configure-funnel.ps1`とFunnelのstart/stopは、必要時に管理者権限で実行する操作として3プロセス管理から分離する。`tailscale funnel --bg`は設定を持続させ得るため、3プロセス停止だけを公開停止と見なさない。
2. playit.gg agentの起動・停止責務、Funnelの設定・状態確認責務、必要な権限を手順書へ明記する。
3. `stop-public.ps1`がどこまで自動管理するかを明記する。少なくとも障害時の手順は、`HTTP ingress: Funnel OFF`、`UDP ingress: playit.gg tunnel OFF`、Gateway停止、Dedicated Server停止、Lobby停止の順で公開経路を遮断する。
4. 公開前にはFunnelのtargetが`127.0.0.1:8080`であること、playit.ggのUDP転送先が`127.0.0.1:7000`であることを確認する。異常時はまずトンネルを停止する。
5. Funnel / playit.ggの設定、公開前チェック、停止順、秘密値漏えい時のローテーション手順を運用方針書へ反映する。

完了条件:

- 標準ユーザーで管理する3プロセスと、管理者権限を要し得るFunnel操作の境界が明確である。
- 「3プロセスを停止したのにFunnelが公開を継続する」状態をstatus・停止手順で検出できる。
- HTTP / UDPのingressを先に遮断する手順が確認済みである。

### フェーズ6: 総合検証と公開開始判定

1. Pythonの単体・統合テストを実行する。
2. Godotのネットワーク契約テストとヘッドレス起動を実行する。
3. PowerShellスクリプトの構文検証とローカル3プロセス起動を実行する。
4. ホスト以外の回線で、Funnel経由のLobby作成・一覧・参加、playit.gg経由のENet入室、90秒試合、切断、停止を確認する。
5. 外部URLから`/admin`、`/internal/*`、Lobbyの`:8000`が到達不能であることを確認する。
6. Funnel target、playit.gg転送先、HTTP / UDP ingressの停止を確認する。
7. すべての公開用秘密値を一度ローテーションし、古いshared invite tokenとinternal tokenが拒否されることを確認する。

公開開始は、次のsecurity gateをすべて満たしたときだけ行う。

1. nonce消費を含む予約状態機械が原子的に実装・検証済みである。
2. `RUNNING`中にTTLや切断だけでroomを再公開しない。
3. Dedicated Serverの並行consumeとHTTP timeoutが安全に処理される。
4. Gatewayがpathだけでなくmethod、query、header、body、upstreamをallowlist方式で制限する。
5. Funnelが`127.0.0.1:8080`以外をtargetにしていないことを公開開始時に検証する。
6. Funnel / playit.ggを先に遮断でき、Windowsの権限境界を含む停止手順が確認済みである。

## 6. 非対象と残る制約

- playit.gg経由のENet/UDPはTLS化しない。ゲーム通信に個人情報や恒久的な秘密値を載せない。
- shared invite tokenは少規模な友人対戦の入口であり、アカウント認証、不正共有、UDP token盗聴後のfirst-use raceを完全には防がない。漏えい時は値を再生成して再配布する。
- 自宅回線に対するDDoS、停電、Windows Update、トンネル事業者の障害は防げない。
- 複数ルーム・多数参加・常時公開・ランキングなどへ拡張するときは、個別アカウント認証、分散rate limit、別DB、監視、ホスティングを含む別設計を行う。

## 7. 実装の依存順

```text
フェーズ0
  → フェーズ1A（Lobby認証・SQLite transaction）
    → フェーズ1B（状態機械）
      → フェーズ2（Dedicated Server）
        → フェーズ3（Gateway）
          → フェーズ4（クライアント設定）
          → フェーズ5A（Windows 3プロセス管理）
            → フェーズ5B（Tunnel権限・停止手順）
              → フェーズ6（外部統合確認）
```

フェーズ1Aから3までは、方式Bを安全に公開するための必須改修である。フェーズ4から5Bにより、友人が追加ソフトなしで使える導線、ホストが安全に起動・停止する導線、トンネルの公開制御を完成させる。

## 8. 関連文書

- [自宅PC公開対戦サーバー運用方針](自宅PC公開対戦サーバー運用方針.md)
- [オンライン対戦アーキテクチャとサーバー責務](オンライン対戦アーキテクチャとサーバー責務.md)
- [サーバー運用管理ダッシュボード仕様](サーバー運用管理ダッシュボード.md)
- [UIシーン部品化と実行時接続方針](../design/UIシーン部品化と実行時接続方針.md)
