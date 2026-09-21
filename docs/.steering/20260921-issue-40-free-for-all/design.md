# 設計

## 概要

モードを room/session/simulation/snapshot の共通データとして保持する。`duel` の既存値をデフォルトにし、`free_for_all` のみ 3 slot と複数敗北を有効にする。

```
Lobby room(match_mode) -> reservation(slot) -> MatchSession(mode)
                                           -> MatchSimulation(active slots)
                                           -> mode-aware snapshot -> client UI
```

## サーバーとシミュレーション

- `MatchProtocol` に mode の検証と `room_capacity(mode)` / `slots_for_mode(mode)` を置く。
- `MatchSession` は固定 `{1, 2}` の辞書をモードから初期化し、snapshot に `match_mode` と `room_capacity` を含める。
- `MatchSimulation` は有効 slot と `defeated` / `placement` をプレイヤー状態へ追加する。`_other()` の利用箇所を生存対戦者の検索へ置換する。
- ダメージは死亡者を無視する。FFA で死亡者が出たら順位を記録し、2 人以上が残れば match を続ける。最後の 1 人を勝者にする。duel は従来どおり即終了する。
- タイムアウトは生存者の HP を比較して勝者を決め、同率は `winner_id = 0` とする。

## Lobby とクライアント

- API request の `match_mode` は optional とし、省略時 `duel`。SQLite の room に保存し、slot 範囲と空席選択を mode に従わせる。
- `DedicatedClientConnection.create_room` がモードを送る。snapshot の mode/capacity を UI が利用できるようにする。
- UI 既存の 2 人レイアウトは互換性を保ち、ロビーの一覧テキスト・接続情報を mode aware にする。3 人 HUD/観戦 UI はスコープ外とする。

## テスト

GDScript の simulation test に mode、Ready、FFA の勝敗・同時撃破・時間切れを追加し、Python Lobby API test にモード別 slot を追加する。
