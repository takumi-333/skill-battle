# 設計書

## アーキテクチャ概要

Funnel から Gateway に届くヘッダーは入力としては受け付けるが、Gateway は必要な認証 token と POST の固定 content type だけを loopback upstream へ再構成して渡す。

```text
External client / Funnel
  └─ browser + X-Forwarded-* headers
       └─ Public Gateway
            ├─ healthz: fixed route, inbound headers are ignored
            └─ v1 API: accepted headers are validated; only token/content type is rebuilt
                 └─ Lobby 127.0.0.1:8000
```

## コンポーネント設計

### 1. Gateway middleware

**責務**:

- 公開 route、query、body size、POST content type を制限する。
- reverse proxy が付与する forwarded headers を受け付けても downstream に渡さない。

**実装の要点**:

- `/healthz` は外部到達確認専用で、リクエストヘッダーを upstream に再送しない。
- `/v1/*` は既存の allowlist に forwarded header 名を追加するだけで、forward 関数の固定ヘッダー構築は変更しない。

## エラーハンドリング戦略

- `X-Forwarded-*` はエラーにせず無視する。
- 許可されない `/v1/*` ヘッダー、path、query、body、content type は既存の HTTP 400/404/413/415 を維持する。

## テスト戦略

- forwarded headers 付きの `/v1/rooms` が通過し、upstream へ token 以外のヘッダーを渡さない。
- ブラウザ標準ヘッダーと forwarded headers 付き `/healthz` が成功する。
- 既存の reject テストを、未知の独自ヘッダーを対象に置換する。

## ディレクトリ構造

```text
server/public_gateway/app.py
tests/network/test_public_gateway.py
docs/.steering/20260911-fix-funnel-forwarded-headers/
```

## 実装の順序

1. Gateway の入力 allowlist を Funnel の reverse-proxy ヘッダーに対応させる。
2. healthz の browser compatibility と upstream header discard のテストを追加する。
3. Python 回帰テストを実行し、公開プロセス再起動手順を案内する。

## セキュリティ考慮事項

- 外部から届いた `X-Forwarded-*` を信頼・転送しない。
- Gateway は loopback の固定 upstream URL と、再構成した最小ヘッダーだけを使用する。

## パフォーマンス考慮事項

- 既存の固定サイズ request body 読込と一定回数のヘッダー検査だけを使う。
