# 要求

- Tailscale Funnel が付与する `tailscale-funnel-request` ヘッダーを受け取っても、公開 Lobby API が 400 を返さないこと。
- このヘッダーは公開 Gateway から Lobby へ転送しないこと。
- 未許可ヘッダーを拒否する既存の制限は維持すること。

# 受け入れ条件

- `GET /v1/rooms` および公開 API の POST で `Tailscale-Funnel-Request` を含むリクエストが Gateway を通過する。
- Gateway が上流へ送るヘッダーに `Tailscale-Funnel-Request` は含まれない。
- Gateway の Python テストが成功する。
