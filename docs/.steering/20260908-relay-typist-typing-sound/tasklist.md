# タスクリスト

## フェーズ1: 実装

- [x] 打鍵音の送信処理を、ホストとクライアントのいずれからも相手へ届けられるよう修正する。
- [x] Dedicated Server が受理済みタイピング入力の打鍵音を対戦相手だけへ中継する。

## フェーズ2: 検証

- [x] RPC 契約テストを実行する。
- [x] サーバー権威シミュレーションテストを実行する。
- [x] Godot をヘッドレス起動してエラーを確認する。

## 実装後の振り返り

- 2026-09-08: `receive_typist_typing_key_sound` を両者で `any_peer` RPC とし、通常のホスト／クライアント対戦では入力者から相手へ、Dedicated Server 対戦では受理済みの `challenge_character` から相手 peer へ打鍵音を中継するようにした。
- 2026-09-08: `C:\Godot\godot.exe --headless --path . --script res://tests/network/rpc_contract_test.gd`、`match_simulation_test.gd`、`--quit-after 3` が成功した。`user://logs` 書き込みおよびWindows証明書ストアの警告は実行環境由来で、テスト・起動は完了している。
