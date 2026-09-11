# 要求内容

## 概要

Tailscale Funnel を経由した正規の公開リクエストが、Gateway のヘッダー allowlist により拒否されないようにする。

## 背景

公開 Gateway は upstream へ転送するヘッダーを固定している一方、Funnel の HTTP reverse proxy は `X-Forwarded-*` を付与する。既存実装はこれらを入力時点で拒否するため、外部から `/healthz` とゲーム API に到達できても 400 `request header is not allowed` となる。

## 実装対象の機能

### 1. Forwarded ヘッダーの安全な破棄

- Tailscale が付与する forwarded headers を受け付ける。
- これらを Lobby upstream へは転送せず、認可・接続先・応答内容に利用しない。

### 2. ブラウザによる healthz 確認

- `/healthz` は公開到達性の診断専用として、ブラウザ標準ヘッダーが付いていても応答する。
- `/v1/*` の path、query、body、認証 token、content-type 制限は維持する。

### 3. 回帰検証

- Funnel 由来の forwarded headers が安全に無視されることをテストする。
- ブラウザ標準ヘッダー付き `/healthz` が upstream へ不要なヘッダーを渡さず成功することをテストする。

## 受け入れ条件

- [ ] 外部 Funnel 経由の `/healthz` が `request header is not allowed` にならない。
- [ ] `X-Forwarded-*` は Lobby upstream へ転送されない。
- [ ] 非公開 path、query、過大 body、不正 content-type は引き続き拒否される。
- [ ] Python 回帰テストが成功する。

## スコープ外

- Funnel の target、Tailscale policy、Windows Firewall の変更。
- Lobby の API 仕様・認可仕様の変更。
- 公開 API の path 追加。

## 参照ドキュメント

- `docs/specs/自宅PC公開対戦サーバー運用方針.md`
- `deploy/windows/PUBLIC_OPERATION.md`
- `deploy/windows/PUBLIC_PLAY_SESSION.md`
