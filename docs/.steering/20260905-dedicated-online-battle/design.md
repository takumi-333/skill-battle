# 設計書

## 境界

`scripts/network/` は UI を参照しない共有試合・通信層、`server/lobby/` は HTTP/SQLite、`scenes/server_main.tscn` はヘッドレス専用入口とする。クライアントはロビー API の予約情報を使って UDP サーバーへ接続し、位置・HP・勝敗は送信しない。

## データフロー

1. クライアントが Lobby API でルームを作成または予約する。
2. API が room ID、slot、期限付き HMAC トークン、ENet 接続先を返す。
3. クライアントは `join_room` RPC でトークンを提出する。
4. Dedicated Server は token の room/slot/期限を検証し、`MatchSession` に peer を登録する。
5. 入力は 60 Hz シミュレーションに投入し、20 Hz の room 限定スナップショットを返す。

## 互換性

初期移行では既存クライアントの画面・演出を保つため、スナップショットは既存の `receive_network_state` が扱うプレイヤー情報を含める。複雑なキャラクタースキルの完全なサーバー判定は、共有ルールへ段階移行できるよう新しいサーバー境界に閉じ込める。
