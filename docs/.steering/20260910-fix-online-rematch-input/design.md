# 設計書

## アーキテクチャ概要

Dedicated Server をラウンド境界の唯一の決定者とする。Server が `round_id` を増やして snapshot に含め、Client はその値の変化により送信側の連番を初期化する。

```text
MatchSession._start_countdown()
  ├─ round_id を加算
  ├─ 入力・イベント受理連番を -1 に初期化
  └─ snapshot(round_id)
          ↓
MatchPrototype が新しい round_id を検知
  └─ DedicatedClientConnection の送信連番・押下状態を初期化
```

## コンポーネント設計

### MatchSession

- 試合開始カウントダウンのたびにラウンドIDと受理連番を初期化する。
- snapshot にラウンドIDを追加する。

### DedicatedClientConnection / MatchPrototype

- `reset_match_sequences()` は入力・イベント送信連番を0へ戻す。
- snapshot のラウンドIDが前回より新しい場合だけ呼ぶ。結果・古いsnapshotで誤って戻さない。
- 押下状態も戻し、再戦開始時に押下済みキーが単発イベントを妨げないようにする。

## テスト戦略

- `MatchSession` の再戦テストで、再戦前に高い連番を受理させる。
- 再戦後に連番1の移動・イベントを送信し、受理と位置更新を確認する。
- snapshot の `round_id` 増加を確認する。

## 実装の順序

1. Server のラウンドIDと連番初期化を追加する。
2. Client のsnapshot同期時の送信状態初期化を追加する。
3. 再戦回帰テストを追加し、Godot headlessで検証する。
