# タスクリスト

- [x] Dedicated Server の切断・再戦合意状態を修正し、snapshot に公開する。
- [x] クライアントのリザルト UI を snapshot の再戦合意状態に同期する。
- [x] ネットワーク単体テストと UI テストを追加・更新する。
- [x] Godot headless テストと起動確認を実行する。
- [x] 実装・検証結果をステアリング文書へ記録し、issue をアーカイブする。

## 実装後の検証

- 2026-09-08: `tests/network/rpc_contract_test.gd`、`tests/network/match_simulation_test.gd`、`tests/network/lobby_ready_ui_test.gd` を Godot headless で実行し、すべて成功した。
- 2026-09-08: `godot --headless --path . --quit-after 3` を実行し、スクリプトエラーなく起動した。
- 実行環境により `user://logs` の書き込みと Windows のルート証明書ストア読み取りに関する警告は出力されたが、テストの成否およびゲームの起動には影響しなかった。
