# 設計

## アーキテクチャ概要

Dedicated Server の `MatchSession` を開始演出の権威とし、ローカル対戦は同じ時間配分を `MatchPrototype` で進める。固定表示部品は `scenes/ui/match_start_prompt.tscn` に置き、`MatchPrototype` は表示文字列と可視性だけを更新する。

```text
Lobby / 対戦開始
  -> countdown (READY: 操作無効)
  -> match (FIGHT: 操作・90秒計時開始)
  -> result
```

## コンポーネント設計

### MatchSimulation / MatchState / MatchPrototype

- フィールド矩形を 1680 x 774 px、開始位置をその範囲に収まる対称位置へ統一する。
- 試合時間は既存どおり 90 秒を単一の定数として維持する。
- ローカルの countdown では READY を表示し、終了時に `begin_match()` が FIGHT を表示して試合へ遷移する。

### MatchSession / MatchProtocol

- `start()` は直ちに `match` へ遷移せず、READY 用の `countdown` phase と残り時間を設定する。
- `step()` は countdown を進め、READY 完了時に `match` へ遷移する。入力・イベントは `match` phase 以外で拒否する。
- snapshot に countdown の残り時間を含め、クライアントはこれを利用して同じ開始表示を行う。

### 開始表示 UI

- シーンに中央配置の暗幕とラベルを定義する。
- `READY` は countdown phase、`FIGHT` は match phase に入った直後だけ短時間表示する。
- 表示部品は入力を遮断しない。入力の無効化は phase 判定で保証する。

## テスト戦略

- `MatchSimulation` テストで 90 秒・縮小後の開始位置と境界を確認する。
- `MatchSession` テストで READY 中の入力拒否、遷移後の入力受付、snapshot の countdown 状態を確認する。
- UI テストで Dedicated Server snapshot の READY / FIGHT 表示を確認する。

## 変更ファイル

```text
docs/specs/スキル対戦ゲーム初期対戦仕様.md
scenes/main.tscn
scenes/ui/match_start_prompt.tscn
scripts/match_state.gd
scripts/match_prototype.gd
scripts/network/match_protocol.gd
scripts/network/match_session.gd
scripts/network/match_simulation.gd
tests/network/match_simulation_test.gd
tests/network/lobby_ready_ui_test.gd
```
