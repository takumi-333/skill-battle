# Windows公開対戦の運用

日常的な起動・停止は、短い [公開対戦サーバー 日常運用手順](PUBLIC_DAILY_RUNBOOK.md) を使います。この文書は初回設定、公開境界、停止時のセキュリティ原則を定める詳細な運用方針です。

`start-public.ps1`、`stop-public.ps1`、`status-public.ps1` は標準ユーザーで管理するLobby、Public Gateway、Dedicated Serverだけを対象にします。初回の `start-public.ps1` は `.local-server/public.env` を作成してcurrent userだけにACLを限定します。playit.ggで発行された外部UDPのホスト名とポートを設定するまで、起動は意図的に失敗します。`public.env`、PID、ログ、SQLite DBをGitへ追加したり共有したりしないでください。

## 公開開始

1. `start-public.ps1` を標準ユーザーのPowerShellで実行する。
2. playit.gg agentを起動し、UDP tunnelの転送先が **`127.0.0.1:7000`** だけであることをdashboardで確認する。agent／tunnelの起動・停止はこのリポジトリのスクリプト管理外である。
3. 管理者PowerShellで `configure-funnel.ps1` を実行する。この操作は `HTTPS :443`（必要なら8443/10000）を **`http://127.0.0.1:8080`** だけへ向ける。Lobbyの8000番へ向けてはならない。
4. `check-public-prerequisites.ps1` と `status-public.ps1` を実行し、Funnel targetが`127.0.0.1:8080`であること、3プロセスが稼働中であること、Lobby/Gateway双方のloopback `/healthz`が200でGateway経由の`protected_api_ready`が`true`であることを確認する。外部回線でGatewayの`/healthz`、招待token付きの作成・一覧・参加を確認する。

Funnelは公開reverse proxyであって認証境界ではありません。URL・shared invite tokenを知る第三者を想定し、tokenは必要な友人だけに送ります。`/admin`、`/admin/api/*`、`/internal/*`、`:8000`、SQLiteファイルは公開対象外です。

## 停止・障害対応

公開を止める順序は必ず次のとおりです。

1. **HTTP ingressを止める:** 管理者PowerShellで `stop-funnel.ps1` を実行する。
2. **UDP ingressを止める:** playit.gg dashboardまたはagent側で対象tunnelを停止する。
3. 両方がOFFと確認してから、標準ユーザーで `stop-public.ps1 -IngressAlreadyDisabled` を実行する。これはGateway、Dedicated Server、Lobbyを停止するだけで、tunnelを停止しない。

`tailscale funnel --bg` は再起動後も設定を保持し得ます。3プロセスが停止しているだけで公開停止と見なさず、毎回Funnelとplayit.ggを確認してください。不審なアクセス、秘密値漏えい、公開先の異常を検知した場合は、まず上の1と2でingressを遮断します。続いて`public.env`の4 secretをすべて新しい暗号学的乱数へ置換し、Funnel URLとplayit.gg tunnel、共有先を見直してから再公開します。旧shared invite tokenと旧internal tokenはローテーション後に拒否されます。
