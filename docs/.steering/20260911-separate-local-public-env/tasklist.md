# タスクリスト

- [x] 開発用環境設定モジュールを追加し、既存・混入設定の移行規則を実装する。
- [x] 開発用ランチャーを新モジュールへ接続し、ローカル設定だけを子プロセスへ渡す。
- [x] 移行・秘密値維持・公開設定非変更を検証する PowerShell テストを追加する。
- [x] 開発／公開の設定分離を運用ドキュメントへ明記する。
- [x] PowerShell テストと Godot の静的／実行可能な検証を行い、結果を記録する。
- [x] デバッグクライアントが保存済みの loopback HTTP 設定を最新ローカル設定へ更新するよう修正し、回帰テストを追加する。

## 作業後の振り返り

- `tests/windows/local_common_test.ps1`: 公開設定混入の旧 `local.env` を移行し、秘密値の再生成、再起動時の秘密値維持、`public.env` 非変更、ローカルクライアント設定を確認して成功。
- `tests/windows/public_common_test.ps1`: 公開用の既存回帰テストに成功。
- `deploy/windows/restart-local.ps1`: 実際の旧 `local.env` を移行して Lobby と Dedicated Server を再起動。`/healthz` は `protected_api_ready: true`、Godot Dedicated Server は UDP 17000 の待受ログを出力した。
- `tests/network/lobby_ready_ui_test.gd`: 保存済みloopback URLの古いトークンを`local-client.env`の最新値で置換し、HTTPS設定を保持する回帰ケースを追加。Godot headlessで成功。
