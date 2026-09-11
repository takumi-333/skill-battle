# タスクリスト

- [x] 方針2のID索引変更と専用テストを、当該差分だけ安全に巻き戻す。
- [x] 十六夜用のコンパクトな発動プレゼンテーション、個別弾プレゼンテーション抑止、スナップショット除外を実装する。
- [x] クライアント側で十六夜の視覚弾を生成・更新・描画する。
- [x] サーバー側の発動・スナップショット除外と、クライアント側の視覚弾生成をテストする。
- [x] Godotテストとヘッドレス起動を実行し、検証結果を記録する。

## 検証結果

- 2026-09-11: `godot --headless --path . --script res://tests/network/match_simulation_test.gd` が成功し、十六夜のイベント化・スナップショット除外・上限時の実弾数を確認した。
- 2026-09-11: `godot --headless --path . --script res://tests/network/lobby_ready_ui_test.gd` が成功し、クライアント側のイベント再生と重複受信の抑止を確認した。既存のローカル保存領域に関する警告・アサートは発生したが、テストは `online lobby ready UI tests passed` を出力した。
- 2026-09-11: `godot --headless --path . --script res://tests/network/dedicated_rpc_contract_test.gd` が成功した。
- 2026-09-11: `godot --headless --path . --quit-after 3` が成功し、起動時のスクリプトエラーはなかった。
- 2026-09-11: `git diff --check` で空白エラーがないことを確認した。
