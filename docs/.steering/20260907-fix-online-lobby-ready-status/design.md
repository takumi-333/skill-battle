# 設計書

## アーキテクチャ概要

準備状態の正は Dedicated Server の `MatchSession.ready` とする。クライアントは可視のローカル準備ボタンから `set_room_ready` RPC を要求し、サーバーが返す snapshot だけでチェック表示を更新する。

```text
PlayerOneReady / PlayerTwoReady
             ↓
toggle_local_lobby_ready()
             ↓
DedicatedClientConnection.set_ready()
             ↓ RPC
DedicatedServer → MatchSession.ready → snapshot
             ↓
_on_dedicated_snapshot_received() → refresh_lobby_label() → LobbyStatusIcon
```

## コンポーネント設計

### `scripts/match_prototype.gd`

**責務**:

- ロビーの固定ボタンを実行時に一度だけ接続する。
- 現在のローカル slot に対応する可視ボタンをマウス補助処理の対象にする。
- snapshot で更新された `p1_ready` / `p2_ready` を既存のロビー表示へ反映する。

**実装の要点**:

- `PlayerOneReady` と `PlayerTwoReady` の両方を `toggle_local_lobby_ready` に接続する。
- `get_local_lobby_ready_button()` が `local_player_id` からローカル準備ボタンを一意に選び、マウス補助処理と表示更新で共有する。旧プレイヤーホスト方式には影響させない。
- クライアント側で楽観的にチェック状態を変更せず、サーバー snapshot を正とする。

### `scripts/network/match_session.gd`

既存の `set_ready()` は slot ごとの状態を保存し、2人とも準備済みなら試合開始する。今回の修正では変更しない。

## データフロー

1. クライアントが自分の slot に表示された準備完了ボタンを押す。
2. クライアントが Dedicated Server に `set_room_ready(next_ready)` を送信する。
3. Dedicated Server が `MatchSession.ready` を更新して room 内へ snapshot を配信する。
4. クライアントが snapshot の `ready` から両方のチェック表示と文言を更新する。
5. 両方の値が `true` ならサーバーが `phase = "match"` の snapshot を配信し、クライアントが試合画面へ遷移する。

## テスト戦略

- `MatchSession` の両 slot の準備完了で開始する既存の契約を自動テストに追加する。
- ロビーシーンを初期化し、両準備ボタンのシグナル接続と slot ごとのローカルボタン選択を自動テストする。
- Godot ヘッドレスで GDScript のパースおよびテストスクリプトを実行する。
- 可能ならローカルの Dedicated Server とクライアント2台で、slot 1 / slot 2 のチェックと試合開始を手動確認する。

## 依存ライブラリ

追加なし。

## 変更ファイル

```text
scripts/match_prototype.gd
tests/network/match_simulation_test.gd
tests/network/lobby_ready_ui_test.gd
docs/.steering/20260907-fix-online-lobby-ready-status/
```

## 実装の順序

1. 両準備ボタンとマウス補助処理をローカル slot 共通にする。
2. `MatchSession` の ready-to-start 契約をテストする。
3. Godot ヘッドレスでパースとテストを確認する。
