# タスクリスト

- [x] 400 応答の Gateway ログから拒否ヘッダーを特定する。
- [x] `tailscale-funnel-request` をプロキシメタデータとして許可する。
- [x] Gateway テストで Funnel ヘッダーを受理し、上流へ転送しないことを確認する。
- [x] Python テストを実行し、結果を記録する。

## 実装後の振り返り

- 原因: Tailscale Funnel が付与する `tailscale-funnel-request` がプロキシメタデータ allowlist に未登録で、Gateway が 400 を返していた。
- 変更: このヘッダー名だけをプロキシメタデータとして受理し、既存どおり上流 Lobby には転送しない。
- 検証: `server/lobby/.venv/Scripts/python.exe -m pytest tests/network/test_public_gateway.py`（5 passed）。
- 次: ホストPCで Public Gateway を再起動してから、外部回線のクライアントで接続を再確認する。
