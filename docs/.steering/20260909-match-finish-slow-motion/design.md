# 設計

## 方針

勝敗の確定と表示のリザルト遷移を分離する。HP 0 のダメージを適用した時点で勝者は確定するが、直ちに `result` へは遷移せず、同期された中間 phase `finish` に入る。`finish` はゲームロジックを停止して最終状態を保持し、クライアントだけが演出用の時間をスロー倍率で進める。

```text
match
  └─ HP 0: 勝者・最終 HP を確定、ゲームロジックを停止
       ↓
finish（2.0 秒、入力不可、対戦画面のまま視覚演出を 0.20 倍速で進める）
       ↓
result（既存リザルト画面・再戦／ロビー復帰）
```

`finish` をサーバーの phase として同期するため、両クライアントがネットワーク到着時刻の差ではなく、サーバーから配信される残り演出時間を基準に同じ状態を表示できる。

## サーバー権威と phase

### `MatchSimulation`

- HP 0 のダメージ時に、従来どおり `match_over`、`winner_id`、最終 HP を確定する。
- `match_over` 後は simulation の tick を進めず、新規のダメージや寿命更新を発生させない。
- `match_over` は勝敗が確定済みであることを示す値として維持し、表示画面の phase は `MatchSession` が管理する。

### `MatchSession`

- `FINISH_DURATION` と `finish_remaining` を持たせる。
- `simulation.state.match_over` を検出したら `phase = "finish"`、`finish_remaining = FINISH_DURATION` とする。
- `finish` 中は `submit_input` と `submit_event` を拒否し、`step()` は simulation を更新せず `finish_remaining` だけを固定 tick で減算する。
- `finish_remaining` が 0 になった時だけ `phase = "result"` にする。
- snapshot に phase と `finish_remaining` を含める。`result` 専用の再戦・ロビー復帰要求は `finish` 中に受け付けない。

### ローカル／デバッグ対戦

- `MatchPrototype` にも同じ `finish` phase と残り時間を持たせる。
- HP 0 のローカル勝敗確定関数は直ちに `show_result()` を呼ばず、`finish` を開始する。
- `finish` 用の処理を `match_over` による早期 return より先に置き、演出終了時に一度だけ `show_result()` を呼ぶ。

## クライアントの視覚演出

- `finish` を受信しても `apply_screen_state("result")` は呼ばず、`screen == "match"` を維持する。`result` を受信して初めて既存の `show_result()` を実行する。
- `finish` 開始時に最終 snapshot の表示状態を保持する。以後の snapshot は勝敗情報と `finish_remaining` を更新しても、最終被弾直後の可視状態を巻き戻さない。
- `finish_visual_delta = delta * FINISH_TIME_SCALE` を一箇所で算出する。`character_animation_elapsed`、被弾白点滅用タイマー、画面揺れ、算術士フラッシュなど、表示専用の時間値にだけこれを使う。
- server-authoritative の位置、HP、勝敗、当たり判定、スキル生成にはこの倍率を適用しない。これにより見た目は遅くなる一方、対戦結果の同期や公平性は変化しない。
- 現在の最終 snapshot は server 側が停止すると `hit_time` を更新しないため、クライアント側に「決着被弾の残り白点滅時間」を独立して保持する。これを `finish_visual_delta` で減らし、白点滅が静止し続けないようにする。

## UI・音声

- この初期実装では新規の固定 UI を追加しない。既存の対戦 HUD とワールド描画を見せ続けるため、`UIシーン部品化と実行時接続方針.md` の画面可視性方針を保てる。
- 入力の遮断はオーバーレイではなく phase 判定で保証する。
- BGM は決着時に即停止せず、`result` 遷移時に既存の停止・フェード処理を呼ぶ。スローモーション音声は今回の対象外とする。

## 仕様・テスト更新

- 初期対戦仕様の試合フローを `HP 0 で勝敗確定 → 決着演出 → リザルト` に更新する。
- オンライン対戦アーキテクチャに `finish` phase、入力停止、snapshot の残り演出時間を追記する。
- `MatchSession` テストで、HP 0 後に `finish` へ入り入力が拒否され、期間終了後に `result` となることを確認する。
- UI テストで `finish` snapshot 中は対戦画面が維持され、`result` snapshot でリザルトへ遷移することを確認する。
- ローカル対戦の phase 遷移と、最終被弾白点滅タイマーがスロー倍率で減ることをテストまたは検証用の観測点で確認する。
- Godot headless 起動と既存のネットワーク関連テストを実行する。

## 変更候補ファイル

```text
docs/specs/スキル対戦ゲーム初期対戦仕様.md
docs/specs/オンライン対戦アーキテクチャとサーバー責務.md
scripts/network/match_session.gd
scripts/network/match_protocol.gd
scripts/match_prototype.gd
tests/network/match_simulation_test.gd
tests/network/lobby_ready_ui_test.gd
```
