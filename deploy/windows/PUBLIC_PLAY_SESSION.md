# 公開対戦を始める手順（Windows ホストPC）

この手順は、ホストPCで Lobby・Public Gateway・Godot Dedicated Server を動かし、ホスト本人と友人 1 人が Windows クライアントで対戦するためのものです。友人は Godot、Tailscale、playit.gg を入れません。初回設定後の毎回の開始・終了には、[日常運用手順](PUBLIC_DAILY_RUNBOOK.md) を使います。

> **役割の分離**
>
> - **Tailscale Funnel**: Lobby の HTTPS API だけを公開する。
> - **playit.gg**: Godot の ENet / UDP 対戦通信だけを `127.0.0.1:7000` へ中継する。
> - **配布クライアント**: ホストと友人で同じ `SkillBattle.exe` を使う。URL と招待トークンは配布 ZIP へ入れない。

`Lobby :8000`、Gateway `:8080`、Dedicated Server UDP `:7000` はホストPC内でだけ待ち受けます。ルーターのポート開放、DMZ、UPnP は不要かつ禁止です。

## 0. 用意するもの

- このリポジトリ、Godot 4.7 の実行ファイル、Python Launcher (`py.exe`) があるホストPC。
- Tailscale にログイン済みで、host PC が tailnet に接続済みであること。
- playit.gg agent がホストPCで起動でき、playit.gg にログイン済みであること。
- 友人へ渡す Windows クライアント ZIP。

ホストPCは Dedicated Server を `start-public.ps1` から Godot headless で起動するため、**サーバー稼働中は Godot とこのリポジトリを保持する必要があります**。一方、ホストがゲームを遊ぶためのクライアントは友人と同じ配布済み `SkillBattle.exe` を使います。ソースから Godot エディタでクライアントを起動する必要はありません。

## 1. playit.gg の UDP tunnel を作る

1. ホストPCで playit.gg agent を起動し、agent が接続済みと表示されるまで待ちます。対戦中は agent を終了させません。
2. playit.gg の dashboard で **Add Tunnel** を選び、agent をホストPCに指定します。
3. tunnel type は **Custom UDP**（UI 表記が異なる場合は UDP 専用の Custom tunnel）を選びます。
4. local address を **`127.0.0.1`**、local port を **`7000`** にします。TCP や複数 port の tunnel は追加しません。
5. Proxy Protocol は **Off / Disabled** にします。Godot ENet は Proxy Protocol を解釈しません。
6. 作成された外部の **hostname** と **UDP port** を控えます。例えば、表示が `example.playit.gg:24567` なら、hostname は `example.playit.gg`、port は `24567` です。

ここでは友人へ playit.gg の hostname やポートを直接送信しません。Lobby が安全に予約を発行してクライアントへ渡します。

## 2. 公開サーバー設定を初期化する

通常の（管理者ではない）PowerShell をリポジトリ直下で開きます。初回だけ次を実行します。

```powershell
.\deploy\windows\start-public.ps1
```

初回は `.local-server\public.env` を作った後、公開 UDP 接続先が未設定なのでエラーで止まります。これは正常です。作成されたファイルを開きます。

```powershell
notepad .\.local-server\public.env
```

次の 2 行だけを、手順 1 で控えた値へ変更します。値は例です。

```text
SKILL_BATTLE_SERVER_ADDRESS=example.playit.gg
SKILL_BATTLE_SERVER_PORT=24567
```

`SKILL_BATTLE_SERVER_ADDRESS` には `https://`、`udp://`、`:24567` を付けません。`SKILL_BATTLE_PLAYIT_FORWARD_TARGET=127.0.0.1:7000`、4 種類の secret、その他の行は変更・共有しません。

## 3. ローカルの公開サービスを起動する

同じ通常 PowerShell で実行します。

```powershell
.\deploy\windows\start-public.ps1
.\deploy\windows\status-public.ps1
```

`status-public.ps1` の `lobby`、`gateway`、`dedicated` がすべて `running` になることを確認します。初回は Python 仮想環境と依存関係のセットアップに少し時間がかかることがあります。

この時点ではまだ Lobby はインターネット公開されていません。

## 4. Tailscale Funnel で Gateway だけを公開する

**管理者として** PowerShell を開き、リポジトリ直下で実行します。

```powershell
.\deploy\windows\configure-funnel.ps1
tailscale funnel status
```

表示された `https://<node>.<tailnet>.ts.net` が Lobby URL です。status の転送先は **`http://127.0.0.1:8080` だけ**でなければなりません。`:8000`、`/admin`、`/internal` を Funnel へ公開してはいけません。

次を実行して、ローカルの最終確認をします。

```powershell
.\deploy\windows\check-public-prerequisites.ps1
.\deploy\windows\status-public.ps1
```

可能ならスマートフォンのモバイル回線など、ホスト宅とは別回線のブラウザで次を開きます。

```text
https://<node>.<tailnet>.ts.net/healthz
```

`{"ok":true,"protected_api_ready":true}` が返れば HTTPS 経路と公開APIのsecret設定は利用可能です。DNS/証明書の反映には数分かかることがあります。

## 5. クライアントを用意し、招待情報を渡す

### 配布 ZIP を作る

通常 PowerShell で次を実行します。

```powershell
.\deploy\windows\build-client-release.ps1
```

出力された `build\releases\SkillBattle-Windows-x64-*.zip` をホスト本人と友人の両方で使います。すでに生成済みなら、同じ ZIP を使えます。

### Lobby URL と招待トークンを表示する

手順 4 の URL を使って、次を実行します。

```powershell
.\deploy\windows\show-client-invite.ps1 -LobbyUrl 'https://<node>.<tailnet>.ts.net'
```

表示される **Lobby HTTPS URL** と **Shared invite token** だけを、友人へ ZIP と別のチャット・メッセージで送ります。`public.env` 全体、管理 token、internal token、署名用 secret は絶対に送信しません。

### ホストと友人のクライアント操作

両者とも次を行います。

1. ZIP を完全に展開し、`SkillBattle.exe` を起動する。
2. ホーム画面右上の歯車を開く。
3. ユーザー名、Lobby HTTPS URL、Shared invite token を入力して **保存** する。
4. **オンライン対戦** を開く。
5. どちらか一方が **ルームを作成** し、もう一方は **ルームに参加** → **一覧を更新** → そのルームを選ぶ。
6. 両者がロビーへ入ったら Ready にする。

最初の一回は、ホストと友人が別回線で 90 秒程度の試合を行い、ルーム作成・一覧参加・Ready・切断を確認してください。

## 6. 終了する

公開を止める順番は必ず守ります。

1. 管理者 PowerShell で Funnel を止める。

   ```powershell
   .\deploy\windows\stop-funnel.ps1
   ```

2. playit.gg dashboard または agent から UDP tunnel を無効にする。
3. 両方の ingress が止まったことを確認してから、通常 PowerShell でローカルプロセスを止める。

   ```powershell
   .\deploy\windows\stop-public.ps1 -IngressAlreadyDisabled
   ```

## 困ったとき

| 症状 | 確認すること |
| --- | --- |
| `start-public.ps1` が設定不足で停止する | `.local-server\public.env` の hostname と UDP port を確認する。host 名に URL scheme や port を混ぜない。 |
| `status-public.ps1` で `gateway` または `dedicated` が stopped | `start-public.ps1` を再実行する。`.local-server` のログは token を含む可能性があるため共有しない。 |
| `healthz` が外部回線で開けない | `tailscale funnel status` の target が `127.0.0.1:8080` か、Funnel の権限・MagicDNS・HTTPS を確認する。 |
| ルーム一覧を取得できない | クライアントの Lobby URL と shared invite token を保存し直す。URL は `https://` で始まる必要がある。 |
| ルーム参加後に対戦サーバーへ接続できない | playit.gg agent/tunnel が有効か、protocol が UDP、local target が `127.0.0.1:7000`、Proxy Protocol が Off、`public.env` の hostname/port が割当値と一致するかを確認する。 |

不審なアクセスや token 漏えいの疑いがある場合は、まず Funnel と playit.gg tunnel を止めます。その後、`public.env` の secrets をすべて安全な乱数へローテーションし、原因を確認するまで再公開しません。

## 公式参照

- [Tailscale Funnel command](https://tailscale.com/docs/reference/tailscale-cli/funnel) — `funnel status`、HTTPS port、停止方法。
- [Tailscale Funnel requirements](https://tailscale.com/docs/features/tailscale-funnel) — Funnel 権限、MagicDNS、HTTPS 証明書。
- [playit.gg](https://playit.gg/docs) — agent と custom UDP tunnel の概要。
- [playit.gg Proxy Protocol](https://playit.gg/support/what-is-proxy-protocol/) — Godot ENet には Proxy Protocol を設定しない理由。
