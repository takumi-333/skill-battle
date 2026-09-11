# 設計書

## アーキテクチャ概要

Public Gateway は許可した HTTP ルートと入力だけを loopback の Lobby へ転送する狭い adapter である。Funnel はクライアント要求に `Tailscale-Ingress-Target` を、Serve は `Tailscale-Headers-Info` と `Tailscale-User-*` identity ヘッダーを追加するが、これらの値は API の入力として使わない。

```
Godot client
  -> Tailscale Funnel / Serve (+ Tailscale proxy metadata)
  -> Public Gateway (受理するが転送しない)
  -> 127.0.0.1:8000 Lobby (invite token のみ受け取る)
```

## コンポーネント設計

### Public Gateway

**責務**:

- 許可した公開 API ルート、ヘッダー、本文だけを受け付ける。
- Tailscale の ingress および identity ヘッダーを転送せず、upstream にプロキシ情報を渡さない。

**実装の要点**:

- Tailscale の ingress および identity ヘッダーを `PROXY_METADATA_HEADERS` に追加する。
- `forward()` が組み立てるヘッダーは変更しない。

## データフロー

### ルーム一覧取得

1. Godot が `Accept` と shared invite token を付けて `/v1/rooms` を要求する。
2. Funnel または Serve が Tailscale プロキシメタデータを付加する。
3. Gateway はヘッダー名を許可し、token だけを Lobby へ転送する。
4. Lobby が token を検証し、一覧を返す。

## エラーハンドリング戦略

- 未許可のクライアントヘッダーは従来どおり 400 にする。
- Tailscale プロキシメタデータの値は使用・記録・転送しない。
- token 値をテスト出力、ログ、ドキュメントに書かない。
- 未許可ヘッダーで拒否した場合は、原因切り分け用にヘッダー**名だけ**を Gateway のローカル stderr ログへ記録する。

## テスト戦略

### ユニットテスト

- Tailscale ingress および identity ヘッダー付きの POST を受理する。
- upstream に渡るヘッダーが token と Content-Type に限定される。
- 拒否ログにヘッダー値が含まれない。

### 統合確認

- Public Gateway を再起動後、Funnel 経由でトークンなしの API 呼び出しを行い、認証エラーまで進むことを確認する。

## 依存ライブラリ

新規依存なし。

## ディレクトリ構造

```
server/public_gateway/app.py
tests/network/test_public_gateway.py
docs/.steering/20260911-allow-funnel-ingress-header/
```

## 実装の順序

1. ingress ヘッダーを許可リストへ追加する。
2. 回帰テストを追加して実行する。
3. Windows 公開プロセスを再起動し、Funnel 経由の応答を確認する。

## セキュリティ考慮事項

- 許可範囲は Tailscale が付加する ingress および identity ヘッダー名に限定する。
- プロキシメタデータの値は未信頼として扱い、Lobby へ転送しない。

## パフォーマンス考慮事項

- ヘッダー名の集合判定のみで、リクエストごとの追加 I/O はない。
