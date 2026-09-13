# 自宅PC公開対戦サーバー運用方針

最終更新: 2026-09-10

## 1. 目的と結論

OCIのVMは利用しない前提とし、遊ぶ時間だけ開発者のWindows PCでSkill BattleのLobby APIとGodot Dedicated Serverを稼働させる。同じPCではホスト本人のGodotクライアントも起動し、インターネット越しの友人1人と2人対戦する。

ルーターのポート開放、固定グローバルIP、家庭内ネットワークへの直接受信を必要としない。CGNAT環境でも利用できる可能性がある。

本運用では、**方式B（LobbyはTailscale Funnel、対戦UDPはplayit.gg）を採用方針とする**。友人は追加ソフトを導入せず、ゲーム本体と招待アクセストークンだけで参加する。
方式AのTailscale限定対戦は、公開前の切り分けと、公開トンネルが使えない場合の代替手段に位置付ける。

方式Bは実装で安全性を補う前提であり、現行実装をそのまま公開する方針ではない。本書5章の公開前提条件を満たす実装・検証が完了するまで、実際のFunnel・playit.gg公開は開始しない。

「無料」はサービス利用料を指す。
ホストPCの電気代・回線使用量・PCの故障や停止に伴うコストは発生する。
PCを落とす、スリープさせる、またはホスト回線が切れると、その時点で対戦は切断される。

## 2. ホストPCの適性と想定規模

提示されたTakumiPC（Ryzen 7 7735HS、RAM 16 GB、Radeon内蔵GPU、空きストレージ約322 GB）は、次の同時起動に十分な構成である。

```text
FastAPI Lobby API 1プロセス       （軽量）
Godot Dedicated Server 1プロセス （headless）
ホスト本人のGodotクライアント 1本
Tailscale（必要時は公開用Gateway）
```

Dedicated Serverは描画をしないため、主な負荷はホスト本人が操作するGodotクライアントである。初期仕様の上限である1ルーム2人、かつ1ルームだけの対戦であれば、CPU・メモリは余裕を見込める。内蔵GPUと表示上の2 GBは共有メモリ型であり、4K・高画質配信・ブラウザの大量タブ・録画を同時に行わない限り、このゲームの2人対戦に専用GPUは必要ない。

運用上の上限はPC性能よりホスト側の**上り回線品質**で決まる。初回は「1ルーム・ホストと友人の2人だけ」「配信・録画なし」で開始し、試合中のFPS、CPU/GPU使用率、メモリ使用量、送受信量をWindowsのタスクマネージャーで確認する。プレイ中にCPUまたはGPUが継続して90%前後、メモリ逼迫、操作遅延が出る場合は、他アプリを閉じてから再試験する。

## 3. 現行実装との対応

現行のオンライン対戦は次の3プロセスで構成される。

```text
Godot client A/B
  ├─ Lobby API: HTTPS または Tailscale内HTTP
  │    FastAPI : 127.0.0.1:8000 / SQLite
  └─ Dedicated Server: ENet / UDP
       Godot headless : UDP 7000（設定で変更可能）
```

Lobby APIが発行する`server_address`と`server_port`をクライアントがそのままENet接続先として使う。したがって自宅PC運用では、Lobbyの環境変数`SKILL_BATTLE_SERVER_ADDRESS`と`SKILL_BATTLE_SERVER_PORT`を、実際に外部から到達できる値へ設定する。

- 方式Aでは、ホストPCのTailscale IPまたはMagicDNS名とUDP 7000を返す。
- 方式Bでは、playit.ggから割り当てられたホスト名と公開UDPポートを返す。
- `SKILL_BATTLE_LOBBY_INTERNAL_URL`は常に`http://127.0.0.1:8000`とし、Dedicated ServerからLobbyへの監視通知を外部トンネルへ流さない。
- Lobby APIのUvicornは常に`127.0.0.1:8000`で待受する。`0.0.0.0`への変更、ルーターのポート開放、UPnPの有効化は行わない。

ホスト本人のクライアントも、友人と同じLobbyが返す接続先を使う。一方だけを`localhost`にすると、同じルームでも接続先が分かれてしまうため不可とする。方式Aでは、ホストPC自身からもMagicDNS名またはTailscale IPのUDP 7000へ接続できることを最初の疎通試験で確認する。

既存のローカル起動設定はUDP 17000を開発用に使う。公開検証用には開発用の`.local-server/local.env`を共有・流用せず、秘密値を分離した専用の起動設定を用意する。

## 4. 接続方式

| 方式 | 対象 | 接続構成 | 公開範囲 | 推奨度 |
| --- | --- | --- | --- | --- |
| A: Tailscale限定 | 公開前の切り分け・障害時の代替 | Lobby、UDP 7000ともTailscaleネットワーク内で接続 | 招待済みの参加者だけ | 代替 |
| B: 公開トンネル | 通常の友人対戦 | LobbyはFunnelのHTTPS、対戦UDPはplayit.gg | 必要な公開APIと対戦UDP入口 | **採用** |

### 4.1 方式A: Tailscale限定（切り分け・代替）

```text
友人のPC（Tailscale） ──暗号化オーバーレイ── ホストPC（Tailscale）
      ├─ Lobby API    → Tailscale Serve → 127.0.0.1:8000
      └─ ENet / UDP   → ホストのTailscale名:7000
```

参加者をホストのtailnetへ個別に招待し、LobbyはTailscale Serveで`127.0.0.1:8000`から共有する。Tailscale Personalは個人利用で無料枠があり、2026-09-10時点で最大6ユーザーである。アクセスはtailnetポリシーで、参加者端末からホストPCのServe用HTTPSと`UDP 7000`だけを許可する。管理用ポートやWindowsのファイル共有、RDPは許可しない。

この方式では、Lobby APIのHTTPはTailscaleトンネル内を通るため、インターネット上へ平文で公開されない。ただし接続先名を安定させるためMagicDNSを有効にすること、またクライアント配布物に秘密値を含めないことは必須である。

### 4.2 方式B: 公開トンネル（採用方針）

```text
Godot client A/B
  ├─ HTTPS → Tailscale Funnel → 127.0.0.1:8000 (FastAPI Lobby)
  └─ ENet/UDP → playit.gg relay/agent → UDP 7000 (Dedicated Server)
                                      ホストPC
```

- Funnelは`https://<node>.<tailnet>.ts.net`で**公開用Gatewayだけ**を公開する。FunnelはTCPプロキシであり、UDP対戦通信には使わない。公開可能なポートは443、8443、10000に限定されるため、ローカル8000番を直接Funnelへ指定せず、別のloopbackポートに置くGatewayを指定する。
- playit.ggはカスタムUDPトンネルを使用し、ローカルUDP 7000へ転送する。トンネル設定のProxy Protocolは**無効**にする。Godot/ENetはProxy Protocolを解釈しないためである。
- 友人に渡すのはFunnel URLとゲーム配布物だけであり、管理URL・Tailscale管理画面・playit.gg agentの認証情報は渡さない。
- playit.ggの無料枠、割当先、帯域・接続数制限は変更され得る。開始ごとにダッシュボード上の公開ホスト名・UDPポート・地域を確認し、実際の外部回線から疎通試験を行う。無料枠でのカスタムUDPが利用不可になった場合は、方式Aへ戻るか有料プランまたはVMを検討する。

Funnelは暗号化HTTPSを提供するが、ENet/UDPそのものにTLSはない。playit.gg経由のUDPを「クライアントからDedicated Serverまでのエンドツーエンド暗号化」とは扱わない。ENet上にはログイン情報、管理トークン、恒久的な個人情報、再利用可能な秘密値を絶対に送らない。

## 5. 公開前提条件（方式BのGo/No-Go）

方式Bを実際に公開する前に、以下を全て満たす。未達の間は、実装・ローカル検証または方式Aでの切り分けに留める。

1. `/internal/*`は全経路で認証済みDedicated Serverからしか実行できないこと。特に現行の`POST /internal/rooms/{room_id}/status`は認証依存がなく、第三者がルーム状態を書き換えられる。`require_internal`を適用し、回帰テストを追加するまで公開しない。
2. 公開用GatewayをLobby APIとは別のloopbackポートに置き、外部へは`/healthz`と必要な`/v1/*`だけを転送すること。`/admin`、`/admin/api/*`、`/internal/*`はGatewayで明示的に404/403とする。現行のFastAPI `:8000`を直接Funnelに指定すると、トークン認証の有無にかかわらず管理・内部の経路名まで公開されるため不可とする。
3. Lobby APIの作成・一覧・参加APIに、参加許可の仕組みを導入すること。少なくとも招待コードまたは参加者ごとの短期アクセストークンを要求し、コードをログ・画面・URLへ残さない。公開URLだけではルームを列挙・作成・予約できない状態にする。
4. APIにレート制限、同時ルーム上限、リクエストサイズ上限、異常な失敗回数の記録を実装すること。これらがない現状では、誰でもルーム作成・予約を繰り返せる。
5. Lobby発行のENet参加トークンを一回使用で失効させること。現行は60秒の署名付きトークンで、期限中の再利用を防止しない。トークンの短命化だけでは盗聴・競合接続に対して十分ではない。
6. Dedicated Serverのトークン署名比較を定時間比較に統一すること。また、実施済みの入力検証・ルーム人数上限・payload上限に回帰テストを追加すること。
7. `SKILL_BATTLE_TOKEN_SECRET`、`SKILL_BATTLE_ADMIN_TOKEN`、`SKILL_BATTLE_INTERNAL_API_TOKEN`をそれぞれ48バイト以上のCSPRNGで生成し、公開設定・リポジトリ・配布物・スクリーンショット・ログに含めないこと。管理トークンと内部トークンは用途を兼用しない。
8. `/admin`と`/admin/api/*`をFunnelで公開しないこと。運用管理はホストPC自身、またはTailscale内の管理端末からだけ行う。管理画面のトークン認証があっても、公開面を増やさない。
9. Windows Defender Firewallで、Lobbyの直接受信を許可しないこと。Dedicated Serverはplayit.gg経由の検証でのみ必要な受信規則を最小化し、方式AではTailscaleのアドレス範囲・UDP 7000に限定すること。Windowsの「パブリックネットワークで許可」は選択しない。

## 6. ホストPCのセキュリティ基準

### 6.1 アカウント・ソフトウェア

- ホストPCは日常利用アカウントとは別の標準WindowsユーザーでDedicated Server、Lobby、トンネルagentを実行する。管理者権限で常駐起動しない。
- Windows、ブラウザ、Tailscale、playit.gg agent、Python依存関係、Godotを更新し、再起動保留状態で公開しない。
- Tailscaleとplayit.ggのアカウントは、多要素認証を有効にする。参加者の端末を個別に把握し、不要になった端末・招待は直ちに削除する。
- agentの実行ファイルは公式配布元から取得し、公開前に署名または提供元のハッシュを確認する。未知の「トンネル補助ツール」は併用しない。

### 6.2 ネットワークと秘密情報

- ルーターではポート転送、DMZ、UPnPを設定しない。家庭内の他端末へアクセスできるネットワーク共有やリモートデスクトップを公開しない。
- Lobby DB、`.env`相当の設定、`.local-server/`、ログのアクセス権をサーバー実行ユーザーと管理者だけに限定する。バックアップは暗号化し、同じPCだけにしかない状態を避ける。
- ルーム名、IP、エラー本文、トークンをログへそのまま書かない。ログの保持期間を決め、問題調査後に削除する。
- ホストPCをスリープさせない運用にする一方、画面ロック・ディスク暗号化・強固なWindowsログインを有効にする。共有PCでは運用しない。

### 6.3 可用性と濫用対策

- 自宅回線・PCはDDoS耐性を保証できない。回線遅延、トンネル障害、停電、Windows Update、PC再起動で試合が中断する前提を参加者へ明示する。
- 1回のテストは参加者を少数（まず2人）に限定し、使わない時間はトンネルとDedicated Serverを停止する。常時公開しない。
- CPU、メモリ、回線使用量、Dedicated Serverの心拍・拒否イベント、Windowsイベントログを確認する。異常な接続、急な遅延、未知の管理アクセスがあれば直ちに停止する。

## 7. 運用手順

### 7.1 導入順序

1. 現行のWindowsローカル起動で、同一PC上の2クライアントによる作成・参加・試合・切断を確認する。
2. 方式Aを構築し、ホスト本人のクライアントと、招待した友人の別回線からLobbyとUDPの双方を確認する。ここで接続先設定、Windows Firewall、遅延を検証する。
3. 方式Bが必要な場合だけ、5章の公開前提条件を実装・テスト・レビューする。
4. GatewayだけをFunnelへ公開し、`/healthz`と認証済みゲーム導線を外部回線から確認する。`/admin`と`/internal/*`が外部から404/403になることも確認する。
5. playit.ggのUDPトンネルを1本だけ作成し、Dedicated Serverのローカル待受と公開先の組を確認する。Lobbyが返す接続先を割当済みのホスト名・ポートに設定する。
6. ホスト以外の回線から、作成、一覧、参加、150秒の試合、切断、サーバー停止後の失敗表示までを確認する。

### 7.2 起動時チェック

- Windows Updateの再起動待ちがない。
- ホストPCの日時が正しい（短期トークンの有効期限に影響する）。
- Lobbyは`127.0.0.1:8000`、Dedicated Serverは意図したUDPポートだけで待受している。
- 3種類の秘密値が設定済みで、開発用と公開用で異なる。
- Tailscale/playit.gg agentが意図したアカウント・端末・トンネルに接続している。
- Lobbyが返す`server_address`と`server_port`が、外部から実際に使う値と一致している。
- 管理画面、内部API、ローカルDBが外部URLから見えない。

### 7.3 停止・インシデント対応

通常停止は、参加者へ告知してから次の順で行う。

1. Funnelとplayit.ggのトンネルを無効化する。
2. Dedicated Serverを停止する。
3. Lobby APIを停止する。
4. 必要に応じてWindows Firewallの限定規則を無効化する。

不審なアクセス、秘密値の露出、未知のルーム操作、回線逼迫を検知した場合は、最初にトンネルを無効化する。次に3種類の秘密値を全て再生成し、Tailscale/playit.ggのセッション・agent認証・参加端末を見直す。原因が分かるまで再公開しない。

## 8. 規模拡大時の見直し

本方針の対象は「遊ぶ時だけ起動する、ホスト本人と友人1人の2人対戦」である。常時公開、3人以上の同時利用、配信との同時運用、ランキング等の永続サービスを始める場合は、本方針のまま拡張しない。回線品質、トンネル規約・料金、運用負荷、バックアップ先をあらためて評価して、別のホスティング方針を決める。

## 9. 参照資料

- [方式B公開対戦サーバー改修計画](方式B公開対戦サーバー改修計画.md) — 方式Bを安全に実現するための改修順・受け入れ条件・公開開始判定。
- [Tailscale Funnel公式ドキュメント](https://tailscale.com/docs/features/tailscale-funnel) — 公開HTTPS、必要条件、許可ポート、帯域制限。
- [Tailscale Serve公式ドキュメント](https://tailscale.com/docs/features/tailscale-serve) — tailnet限定のHTTPS共有とアクセス制御。
- [Tailscale料金・Personalプラン](https://tailscale.com/pricing) — 個人利用の無料枠とユーザー上限は開始時に再確認する。
- [playit.gg公式サイト](https://playit.gg/) — ポート開放なしのカスタムTCP/UDPトンネルと無料枠の案内。
- [playit.gg: Proxy Protocol](https://playit.gg/support/what-is-proxy-protocol/) — UDPトンネルでProxy Protocolを使う場合の仕様。
- [オンライン対戦アーキテクチャとサーバー責務](オンライン対戦アーキテクチャとサーバー責務.md) — 本プロジェクトの通信契約と既知の実装境界。
