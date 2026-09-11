# 設計

`deploy/windows/local-common.ps1` を新設して、開発用環境の生成・読込・移行を `start-local.ps1` から分離する。

- 開発用設定は `.local-server/local.env` のみを使用する。
- 正式な開発用値は `SKILL_BATTLE_SERVER_ADDRESS=127.0.0.1`、`SKILL_BATTLE_SERVER_PORT=17000`、`SKILL_BATTLE_SERVER_LISTEN_PORT=17000`、`SKILL_BATTLE_PUBLIC_MODE=0`、ローカル専用 SQLite DB とする。
- playit 用の宛先、公開モード、localhost 以外の接続先、または 17000 以外のポートを含む旧 `local.env` を公開設定混入として検出する。その場合はローカル用の4種類の秘密値を再生成し、ローカル設定だけでファイルを再作成する。
- 正常な既存ローカル設定は秘密値を維持し、固定値だけを検証・補正する。
- `public-common.ps1` と `public.env` は変更せず、テストで内容が不変であることを確認する。

この方式により、ローカルと公開の起動を切り替えても環境ファイルの手編集は不要になる。

クライアント起動時は、デバッグビルドかつ保存済み Lobby URL が loopback HTTP の場合、`local-client.env` のURLとトークンを優先する。これにより、ランチャー移行時のトークン更新後も HTTP の許可状態と認証情報が同期する。HTTPS の保存済み設定は公開対戦テスト用として維持する。
