# タスクリスト

## フェーズ1: 原因の記録と実装

- [x] Funnel 経由だけで 400 になる原因を再現・記録する。
- [x] Gateway の許可リストに Tailscale ingress ヘッダーを追加する。
- [x] ingress ヘッダーを受理し、upstream へ転送しない回帰テストを追加する。
- [x] Tailscale Serve の identity ヘッダーも受理し、upstream へ転送しない回帰テストを拡張する。
- [x] 拒否したヘッダー名だけを Gateway のローカルログへ記録する診断を追加する。
- [x] `Tailscale-Headers-Info` をプロキシメタデータとして受理する。

## フェーズ2: 検証と反映

- [x] Public Gateway の Python テストを実行する。
- [x] Windows 公開プロセスを再起動して変更を反映する。
- [x] Funnel 経由の API が 400 ではなく認証処理まで到達することを確認する。

## フェーズ3: 振り返り

- [x] 実装後の振り返りを記録する。

---

## 実装後の振り返り

### 実装完了日

2026-09-11

### 計画と実績の差分

- 当初は Funnel の `Tailscale-Ingress-Target` だけを許可したが、同じ tailnet から `*.ts.net` へ接続する Serve 経路では `Tailscale-Headers-Info` と `Tailscale-User-*` も付加されることが実機ログで判明した。
- Gateway は Tailscale のプロキシメタデータを受理するだけで、Lobby へは転送しない方式を維持した。
- 拒否時にヘッダー名だけをローカルログへ出す診断を追加し、header value や invite token は記録しない。

### 学んだこと

- Tailscale の同一 tailnet アクセスは Funnel と同じ URL でも Serve 経路になるため、公開経路とローカル確認経路の両方を考慮する必要がある。
- 許可リスト型の reverse proxy には、値を使わないプロキシ付加ヘッダーを明示的に受理し、upstream へ渡さない境界が有効である。

### 次回への改善提案

- 新しい proxy を追加する際は、拒否ログのヘッダー名を先に確認してから、必要最小限の名前だけを許可リストと回帰テストへ追加する。
