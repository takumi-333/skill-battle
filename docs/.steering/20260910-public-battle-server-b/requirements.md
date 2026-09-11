# 要件

- `docs/specs/方式B公開対戦サーバー改修計画.md` のフェーズ0〜6を、依存順と到達条件に従って実装する。
- Lobbyは4種の用途別secret、shared invite token、内部API認証、単一worker前提、SQLiteの原子的状態遷移を実装する。
- 予約・nonce・roomの状態を `AVAILABLE → RESERVED → CONNECTING → CONNECTED → RUNNING → CLOSED` に固定し、不変条件をテストで守る。
- Dedicated Serverはローカル署名検証後にLobbyのnonce consumeを行い、成功時だけpeerを登録する。公開モードのUDP待受はloopbackに限定する。
- Gatewayはloopback上で公開APIの4 endpointだけをallowlist方式でLobbyへ中継する。
- UIは既存のユーザー設定モーダル内にLobby HTTPS URLと招待tokenを追加し、`user://settings.cfg`へ安全に保存する。
- Windowsの公開用3プロセス管理、Funnel / playit.gg の権限境界、公開前確認と停止手順を追加する。
- 既存のローカルLobby／Dedicated Server経路、Godot RPC契約、ローカル対戦を回帰させる。
- 実装完了時にPythonテスト、Godotネットワークテスト、ヘッドレス起動、PowerShell構文検証を実行し、実施不能な外部確認は理由と手順を明記する。
