# 公開対戦サーバー 日常運用手順（Windows）

この手順は、初回設定済みのホスト PC で「今日サーバーを開く」「遊び終わったので閉じる」を安全かつ短時間で行うためのものです。

- 初回の playit.gg tunnel 作成、`public.env` の設定、Funnel の有効化、配布 ZIP の作成は済んでいる前提です。未設定なら [公開対戦を始める手順](PUBLIC_PLAY_SESSION.md) を先に行います。
- 日常の起動・停止でクライアント ZIP を作り直す必要はありません。ZIP の再作成が必要なのは、クライアントのコードや素材を変更して配布版を更新するときだけです。
- `public.env`、その中の token、`.local-server` のログ全体は共有しません。

## 迷ったときの全体像

```text
開始: playit.gg を On → ローカル3プロセスを起動 → Funnel を On → 動作確認
終了: Funnel を Off → playit.gg を Off → ローカル3プロセスを停止
```

`Lobby :8000` と Gateway `:8080`、Dedicated Server UDP `:7000` はホスト PC 内だけで待ち受けます。ルーターのポート開放は不要です。

## 毎回の開始手順

### 1. playit.gg を確認する

playit.gg agent を起動し、dashboard で次を確認します。

- agent が **Connected**
- UDP tunnel が 1 本だけで **On**
- local address が `127.0.0.1`
- local port が `7000`
- Proxy Protocol が **Off**

前回の停止で tunnel を Off にした場合は、このタイミングで **On** に戻します。agent が起動していても tunnel が Off のままでは対戦接続できません。

### 2. 通常の PowerShell でローカルサーバーを起動する

管理者ではない PowerShell を開き、次を実行します。PowerShell を新しく開くたびに `ExecutionPolicy` の行も実行します。

```powershell
Set-Location 'C:\Users\st184\Downloads\DevGames\battle-game'
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

.\deploy\windows\start-public.ps1
.\deploy\windows\status-public.ps1
```

`status-public.ps1` の `lobby`、`gateway`、`dedicated` がすべて `running` なら成功です。

### 3. 管理者 PowerShell で Funnel を有効にする

**管理者として実行した PowerShell** を別に開き、次を実行します。

```powershell
Set-Location 'C:\Users\st184\Downloads\DevGames\battle-game'
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

.\deploy\windows\configure-funnel.ps1
tailscale funnel status
```

`tailscale funnel status` には、次のように **`http://127.0.0.1:8080` だけ**が転送先として表示されなければなりません。

```text
https://<node>.<tailnet>.ts.net (Funnel on)
|-- / proxy http://127.0.0.1:8080
```

`:8000` を公開先に設定してはいけません。

### 4. 通常の PowerShell で最終確認する

手順 2 の通常 PowerShell へ戻り、実行します。

```powershell
.\deploy\windows\check-public-prerequisites.ps1
.\deploy\windows\status-public.ps1
```

`Local checks passed:` が出て、Lobby・Public Gateway・Dedicated Serverの3プロセス、Lobby/Gateway双方のloopback health、Gateway経由の`protected_api_ready=true`がすべて確認できれば、ローカル側の公開準備は完了です。可能ならスマートフォンを Wi-Fi から切ったモバイル回線で、次を開いて `{"ok":true,"protected_api_ready":true}` を確認します。

```text
https://<node>.<tailnet>.ts.net/healthz
```

## 対戦を始める前の確認

- ホストと参加者は配布済みの `SkillBattle.exe` を起動します。
- ユーザー設定には、公開 HTTPS URL と shared invite token を入力済みなら、そのまま使えます。
- URL または token を忘れた場合だけ、通常 PowerShell で次を実行します。表示された 2 値だけを参加者へ渡します。

```powershell
.\deploy\windows\show-client-invite.ps1 -LobbyUrl 'https://<node>.<tailnet>.ts.net'
```

`public.env` 全体や、admin/internal/signing 用の値は渡しません。

## 毎回の終了手順

公開を止める順番は必ず守ります。**ローカルサーバーを先に停止してはいけません。**

### 1. 管理者 PowerShell で Funnel を止める

```powershell
Set-Location 'C:\Users\st184\Downloads\DevGames\battle-game'
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

.\deploy\windows\stop-funnel.ps1
tailscale funnel status
```

`No serve config` と表示されれば Funnel は既に Off です。`stop-funnel.ps1` が `handler does not exist` で終了しても、直後の `tailscale funnel status` が `No serve config` なら停止済みなので次へ進めます。

### 2. playit.gg の UDP tunnel を止める

playit.gg dashboard で対象 UDP tunnel を **Off** にします。agent 自体を終了しても構いませんが、tunnel が Off であることを確認します。

### 3. 通常の PowerShell でローカルプロセスを止める

```powershell
Set-Location 'C:\Users\st184\Downloads\DevGames\battle-game'
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

.\deploy\windows\stop-public.ps1 -IngressAlreadyDisabled
.\deploy\windows\status-public.ps1
```

`lobby`、`gateway`、`dedicated` がすべて `stopped` なら終了です。

## よくある確認だけ

| 状況 | すること |
| --- | --- |
| `start-public.ps1` が PID 再利用やポート使用中で止まる | `status-public.ps1` を確認する。古いローカルサーバーが残っている場合は、公開中でなければ終了手順を最初から行ってから再開する。 |
| `/healthz` が外部回線で開けない | playit.gg ではなく、Funnel の設定を確認する。`tailscale funnel status` の転送先は `127.0.0.1:8080` のみであること。 |
| ルーム作成・一覧で `ロビー API エラー (401)` | クライアント設定の shared invite token を、`show-client-invite.ps1` で表示した値と照合して保存し直す。 |
| ルーム参加後に接続できない | playit.gg の tunnel が On、UDP、`127.0.0.1:7000`、Proxy Protocol Off であることを確認する。 |

Gateway の 400 ヘッダー診断が必要な場合は、token 値を出さずに次の行だけを確認できます。

```powershell
Select-String .\.local-server\public-gateway.stderr.log `
  -Pattern 'rejected public gateway request header names:' |
  Select-Object -Last 1
```

通常はこの確認は不要です。ログ全体は秘密情報を含む可能性があるため、共有しないでください。

## 定期的な更新が必要なもの

- **毎回必要**: playit.gg tunnel On/Off、3 ローカルプロセスの起動/停止、Funnel On/Off。
- **通常は不要**: `public.env` の編集、クライアント ZIP の作成、URL／token の再入力。
- **URL または token が漏れた疑いがある場合**: まず終了手順で ingress を止めてから、詳細手順の「不審なアクセスや token 漏えい」の対応を行います。
