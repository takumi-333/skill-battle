# 設計

Dedicated Server は `challenge_character` を `MatchSession.submit_event()` で受理した後、送信元と異なる同一ルームの peer に `receive_typist_typing_key_sound` RPC を送る。このイベントは既存のサーバー権威のタイピング入力を利用するため、新しいクライアント起点イベントや状態同期は追加しない。

```text
入力者 ── challenge_character ──> Dedicated Server
入力者 <── ローカル再生
Dedicated Server ── 打鍵音 RPC ──> 対戦相手
```

ホスト／クライアント経路は、クライアント入力時にも既存の authority RPC を呼べるようにする。受信側はローカル入力による再生を行わず、RPC受信時だけ再生する。

## 検証

- RPC 契約テストでクライアントと Dedicated Server の RPC 宣言一致を確認する。
- サーバー権威のシミュレーションテストを実行する。
- Godot をヘッドレス起動してスクリプトの読み込みを確認する。
