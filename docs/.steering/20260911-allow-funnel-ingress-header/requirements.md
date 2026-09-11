# 要求内容

## 概要

Tailscale Funnel 経由の公開 Lobby API 要求が HTTP 400 で拒否される問題を解消する。

## 背景

同じ `GET /v1/rooms` は loopback の Public Gateway では認証エラーまで到達する一方、Tailscale 経由では `request header is not allowed` を返す。Funnel は `Tailscale-Ingress-Target` を、同じ tailnet の Serve 経路は `Tailscale-User-*` identity ヘッダーを付加するが、Gateway の入力許可リストに存在しないためである。

## 実装対象の機能

### 1. Funnel ingress ヘッダーの受理

- `Tailscale-Ingress-Target`、`Tailscale-Headers-Info`、`Tailscale-User-*` を Public Gateway が受理するプロキシメタデータヘッダーに追加する。
- これらのヘッダーは Lobby への転送ヘッダーには含めない。

### 2. 回帰防止

- Tailscale の ingress ヘッダーを含む通常の公開 API 要求が upstream へ到達することを自動テストで確認する。
- 未許可ヘッダーの診断ログにはヘッダー名だけを出し、token などの値を出さない。

## 受け入れ条件

### Funnel ingress ヘッダーの受理

- [x] `GET /v1/rooms` に Funnel または Serve の Tailscale メタデータヘッダーを付けても Gateway が 400 を返さない。
- [x] Lobby へ転送するヘッダーは共有 invite token と必要な Content-Type だけである。

### 回帰防止

- [x] Public Gateway の Python テストが通る。
- [x] 再起動後、Funnel 経由でトークンなしの `GET /v1/rooms` が 400 ではなく認証エラー 401 になる。

## スコープ外

- invite token の表示、共有、ローテーション。
- Lobby API のルートや認証仕様の変更。
- クライアント ZIP の再ビルド（Gateway のみの変更のため不要）。

## 参照ドキュメント

- `deploy/windows/PUBLIC_OPERATION.md`
- `server/public_gateway/app.py`
- `tests/network/test_public_gateway.py`
