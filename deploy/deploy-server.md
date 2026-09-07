# 専用サーバーの配備手順

## Windows でのローカル動作確認

開発PCが Windows の場合、WSL2 へファイルを移さずに確認できます。通常は、次のファイルをダブルクリックするだけでLobby APIとDedicated Serverが起動します。

```text
deploy\windows\start-local.bat
```

初回起動時はPython仮想環境とLobbyの依存関係を準備し、`.local-server\local.env`へローカル専用の秘密値を生成します。Dedicated Serverにはローカル用のUDP 17000を使います。その後ブラウザで`http://127.0.0.1:8000/admin`を開きます。秘密値はURLフラグメントからブラウザの一時セッションへ渡されるため、手入力は不要です。`.local-server/`はGit管理されず、共有・コミットしてはいけません。

起動済みのときにもう一度ダブルクリックしても重複起動しません。終了する場合は、次のファイルをダブルクリックします。PIDと開始時刻が一致するランチャー起動プロセスだけが終了します。

```text
deploy\windows\stop-local.bat
```

`管理者として実行`で起動したプロセスは、通常権限のランチャーから停止できません。起動・停止とも通常権限で実行してください。すでに別の権限で起動したDedicated Serverがある場合は、その起動元のターミナルまたはタスクマネージャーから終了してから、`start-local.bat`を実行します。

ランチャーは`GODOT_CONSOLE`環境変数、`C:\Godot\godot_console.exe`、PATHの順でGodot Consoleを検出します。見つからない場合は、Godotの`godot_console.exe`をインストールするか、環境変数`GODOT_CONSOLE`へ実行ファイルの絶対パスを設定してから、もう一度ダブルクリックしてください。

ネットワーク接続がない初回や、ランチャーの問題を調べる場合は、従来どおり個別に起動できます。Lobby API と Dedicated Server には、同じランダムな秘密値を設定します。秘密値はリポジトリへ保存・コミットしないでください。

最初の PowerShell で Lobby API を起動します。

```powershell
$env:SKILL_BATTLE_TOKEN_SECRET = "開発用のランダムな秘密値"
Set-Location server/lobby
py -m venv .venv
.\.venv\Scripts\pip install -r requirements.txt
.\.venv\Scripts\uvicorn app:app --host 127.0.0.1 --port 8000
```

別の PowerShell をリポジトリのルートで開き、同じ秘密値を設定して、Godot から Dedicated Server のシーンを直接起動します。

```powershell
$env:SKILL_BATTLE_TOKEN_SECRET = "開発用のランダムな秘密値"
godot --headless --path . --scene res://scenes/server_main.tscn
```

`godot` コマンドが見つからない場合は、Godot の実行ファイルへのフルパスを指定します。PowerShell でカレントディレクトリにある実行ファイルを起動する場合は、`./` ではなく `.\ファイル名.exe` の形式を使います。

```powershell
& "C:\Godot\godot_console.exe" --headless --path . --scene res://scenes/server_main.tscn
```

`./skill-battle-server` は Linux 向けにエクスポート済みの実行ファイルの例です。Windows 上でそのファイルは存在しないため、上記の `godot --headless` を使います。Windows 用にエクスポートした場合は、`.\skill-battle-server.exe` と拡張子を含めて起動します。

Windows で Dedicated Server を起動する場合は、`godot.exe` ではなく `godot_console.exe` を使ってください。`godot_console.exe` は PowerShell の `Ctrl+C` を受け取れるコンソール版です。停止できなくなった場合は、UDP 7000 を使っている PID を確認し、そのプロセスだけを終了します。

```powershell
Get-NetUDPEndpoint -LocalPort 7000 | Select-Object OwningProcess
Stop-Process -Id <表示されたPID>
```

Lobby API は既定で対戦サーバーの接続先として `127.0.0.1` を返します。同じ Windows PC 上のクライアント 2 個で確認する場合は変更不要です。WSL2 を使う場合だけ、Uvicorn を起動する前に、Windows から到達できる WSL2 のアドレスを `SKILL_BATTLE_SERVER_ADDRESS` に設定してください。

```bash
$env:SKILL_BATTLE_SERVER_ADDRESS = "WSL2の到達可能なIPアドレス"
```

`curl http://localhost:8000/healthz` で API の応答を確認します。その後、Windows 上でクライアントを 2 プロセス起動し、ルーム作成、一覧更新、参加、準備完了、試合開始を確認してください。VM へ配備する前に、切断・無効トークン・期限切れトークンも確認します。

## OCI VM への配備

1. OCI VM に非 root ユーザー `skill-battle` を作成します。
2. Linux ARM64 向けにエクスポートした Dedicated Server を `/opt/skill-battle/server/current` へ配置します。
3. Lobby API を `/opt/skill-battle/lobby` へ配置し、Python 仮想環境を作成して `requirements.txt` をインストールします。
4. Dedicated Server と Lobby API で共通の `SKILL_BATTLE_TOKEN_SECRET` を生成します。加えて、管理画面専用の `SKILL_BATTLE_ADMIN_TOKEN` と、Dedicated Serverの内部観測用`SKILL_BATTLE_INTERNAL_API_TOKEN`を生成します。秘密値をリポジトリに入れてはいけません。
5. `/etc/skill-battle/server.env`には`SKILL_BATTLE_TOKEN_SECRET`、`SKILL_BATTLE_INTERNAL_API_TOKEN`、`SKILL_BATTLE_LOBBY_INTERNAL_URL=http://127.0.0.1:8000`を、`/etc/skill-battle/lobby.env`には`SKILL_BATTLE_TOKEN_SECRET`、`SKILL_BATTLE_ADMIN_TOKEN`、`SKILL_BATTLE_INTERNAL_API_TOKEN`を保存します。両ファイルの所有者はroot、権限は`640`にします。
6. `deploy/systemd/skill-battle-server.service` と `deploy/systemd/skill-battle-lobby.service` を `/etc/systemd/system/` に配置します。続けて `systemctl daemon-reload`、`systemctl enable --now skill-battle-server skill-battle-lobby` を実行します。これ以降はOS起動時と異常終了時に2サービスが自動的に起動するため、日常的な起動コマンドや環境変数設定は不要です。
7. `deploy/bin/skill-battle-control`を`/usr/local/sbin/skill-battle-control`へroot所有・`0750`で配置し、`deploy/sudoers.d/skill-battle-control`を`/etc/sudoers.d/skill-battle-control`へroot所有・`0440`で配置します。`visudo -cf /etc/sudoers.d/skill-battle-control`で構文を確認します。Lobbyプロセスはrootにせず、この固定操作だけを管理UIから実行できます。
8. Caddy を TCP 443 で稼働させ、[Caddyfile](Caddyfile) を使って Lobby API をリバースプロキシします。`/internal/*`はCaddyから公開せず、Dedicated Serverだけがloopbackで内部APIへ通知します。
9. OCI のセキュリティルールと VM の UFW の両方で、UDP 7000、TCP 443、管理者の送信元 IP に限定した TCP 22 のみを許可します。

次のコマンドでサービス状態とログを確認します。

```bash
systemctl status skill-battle-server skill-battle-lobby
journalctl -u skill-battle-server -u skill-battle-lobby --since "10 minutes ago"
curl https://<ドメインまたはVMのアドレス>/healthz
```

## ブラウザでの運用

`https://<ドメイン>/admin`を開き、`SKILL_BATTLE_ADMIN_TOKEN`を入力して接続します。画面からLobby/Dedicated Serverのsystemd状態、PID、直近ログ、Dedicated Serverの心拍（ルーム数・接続数・受理入力／イベント数）、入室・試合イベント・切断の履歴を確認できます。開始・停止・再起動は、この2サービスだけに限定されています。

管理トークンはブラウザを閉じると失われるセッション保存です。共有端末では操作後にタブを閉じ、トークンをブラウザへ保存しないでください。`/admin`を公開する場合は、CaddyまたはOCI側でも管理者IPへのアクセス制限を設定することを推奨します。

ARM64 版の実行、TLS、公開ファイアウォール、別ネットワークにある PC 2 台からの接続は OCI VM 上で確認してください。これらは Windows や WSL2 のローカル確認では検証できません。
