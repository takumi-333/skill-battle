# タスクリスト

## フェーズ1: Gateway のヘッダー処理

- [x] Funnel の forwarded headers を受け付け、upstream に渡さないようにする。
- [x] `/healthz` がブラウザ標準ヘッダーを無視して応答するようにする。

## フェーズ2: 回帰テスト

- [x] forwarded headers が API upstream へ渡らないことをテストする。
- [x] browser headers 付き healthz の成功と未知 API ヘッダーの拒否をテストする。

## フェーズ3: 検証と記録

- [x] Gateway の Python 回帰テストを実行する。
- [x] tasklist の全完了を確認し、振り返りを記録する。

---

## 実装後の振り返り

### 実装完了日

2026-09-11

### 計画と実績の差分

- 公開実機で `request header is not allowed` が確認された。Tailscale Funnel の proxy ヘッダーとブラウザ標準ヘッダーを、経路別のテストへ明示的に追加した。
- 実行中の公開プロセスへは干渉せず、反映は運用手順に沿った停止・再起動で行う。

### 学んだこと

- reverse proxy が付与する `X-Forwarded-*` は入力として受け付けても、固定 loopback upstream へ転送しなければ信頼境界を拡大しない。
- 外部公開用の health check はブラウザからの到達確認を想定し、ブラウザ固有ヘッダーで拒否しない設計が必要である。

### 次回への改善提案

- 公開 proxy を追加する際は、実際の reverse-proxy ヘッダー付き統合確認をリリース前のチェック項目に含める。
