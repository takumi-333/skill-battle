# Windows クライアントの配布と友人対戦

この手順で、ホストは自分の Windows PC 上で公開対戦サーバーとクライアントを起動し、友人は Godot・Tailscale・playit.gg を導入せずに Windows クライアントだけで参加できます。対象は 1 ルーム・最大 2 人の短時間対戦です。実際の画面操作を含む開始手順は [公開対戦を始める手順](PUBLIC_PLAY_SESSION.md) を参照してください。

公開経路とセキュリティ条件は [PUBLIC_OPERATION.md](PUBLIC_OPERATION.md) および [自宅PC公開対戦サーバー運用方針](../../docs/specs/自宅PC公開対戦サーバー運用方針.md) が正です。公開用の `public.env`、管理トークン、内部 API トークン、署名用トークンを友人へ渡したり、ZIP に入れたりしてはいけません。

## ホスト: 初回準備

1. playit.gg で UDP tunnel を 1 本だけ作成し、転送先を `127.0.0.1:7000` にします。Proxy Protocol は無効にします。割り当てられた公開ホスト名と UDP ポートを控えます。
2. `deploy/windows/start-public.ps1` を一度実行して `.local-server/public.env` を生成します。起動前に `SKILL_BATTLE_SERVER_ADDRESS` と `SKILL_BATTLE_SERVER_PORT` へ手順 1 の値を設定します。`public.env` の 4 種類の secret はそのまま保持し、共有しません。
3. `deploy/windows/start-public.ps1` を実行して、Lobby、Public Gateway、Dedicated Server を起動します。
4. 管理者 PowerShell で `deploy/windows/configure-funnel.ps1` を実行し、Funnel の転送先が `127.0.0.1:8080` だけになっていることを確認します。公開された **HTTPS URL** を控えます。
5. `deploy/windows/check-public-prerequisites.ps1` と `deploy/windows/status-public.ps1` を実行してから、別回線で `/healthz` を確認します。

Funnel の URL を取得するための Tailscale 操作や、playit.gg agent/tunnel の開始・停止はこのリポジトリのスクリプト管理外です。URL を得たら、次のコマンドは共有してよい値だけを表示します。

```powershell
.\deploy\windows\show-client-invite.ps1 -LobbyUrl 'https://your-public-funnel-url'
```

表示された **Lobby HTTPS URL** と **Shared invite token** を、配布 ZIP とは別のチャネルで友人へ送ります。ホスト本人も同じ 2 値を自分のクライアント設定へ入力します。

## ホスト: 配布 ZIP を作る

Godot 4 の Windows export templates をインストールした開発 PC で、リポジトリ直下から次を実行します。

```powershell
.\deploy\windows\build-client-release.ps1
```

コマンドは `build/releases/` に、時刻付きの `SkillBattle-Windows-x64-*.zip` と SHA-256 ファイルを作ります。ZIP には `SkillBattle.exe` と `START_HERE.txt` だけが入り、サーバー設定と token は含まれません。必要なら ZIP の SHA-256 を別チャネルで友人に渡して、受信ファイルを確認してもらいます。

コード署名はしていないため、初回は Windows SmartScreen が警告することがあります。ファイルの入手元とハッシュを確認してから、信頼できる相手の PC でだけ実行してください。

## 友人: 初回接続

1. 受け取った ZIP を任意のフォルダへ完全に展開します。ZIP の中から直接実行しません。
2. `SkillBattle.exe` を起動します。
3. ホーム画面の歯車アイコン（ユーザー設定）を開き、ユーザー名、Lobby HTTPS URL、招待アクセストークンを入力して **保存** します。入力内容はその Windows ユーザーの `user://settings.cfg` に保存されます。
4. **オンライン対戦** を開きます。どちらかが **ルームを作成** し、もう一方が **ルームに参加** から一覧を更新して同じルームを選びます。
5. 両者がロビーに入ったら Ready にして試合を開始します。

URL または token が漏れた疑いがある場合は、まず Funnel と playit.gg の ingress を停止します。その後 `public.env` の shared invite token を安全な乱数へローテーションし、必要なら他の secret も運用手順に従って再生成してから、友人へ新しい値を送ります。

## 終了手順

試合終了後は先に `stop-funnel.ps1` で HTTPS ingress を止め、playit.gg の UDP tunnel を停止します。両方の停止を確認してから、`stop-public.ps1 -IngressAlreadyDisabled` でローカルの 3 プロセスを停止します。詳細は [PUBLIC_OPERATION.md](PUBLIC_OPERATION.md) を参照してください。
