# 設計書

## アーキテクチャ概要

課題状態を試合全体の単一 Dictionary から slot をキーとする Dictionary へ変更する。サーバーは課題ごとに判定し、snapshot は各課題を `challenges` として送る。クライアントは自分の slot の課題だけを既存 ChallengeLayer へ投影する。

```text
MatchSimulation
  state["challenges"][slot] ── snapshot ──> client
       │                                  └─ local slot のみ ChallengeLayer に反映
       └─ miss_sequence 増加 ─────────────────> 差分検出して赤点滅・揺れ
```

## コンポーネント設計

### MatchSimulation / MatchProtocol

**責務**:

- slot ごとの課題の開始、入力、時間経過、終了、中断を処理する。
- 正答は snapshot から除外しつつ、課題を slot ごとに送る。

**実装の要点**:

- `focused` は開始した本人だけの開始制約とする。
- ミス時に課題内の `miss_sequence` を増加し、UI向けの確定イベントとして扱う。
- ダメージは対象 slot の課題だけを中断判定する。

### MatchPrototype

**責務**:

- `challenges[local_player_id]` を ChallengeLayer に反映する。
- 受信済みミス世代番号との差分で既存の演出状態を更新する。

**実装の要点**:

- 固定UIノードとレイアウトは変更しない。
- snapshot に自分の課題がなければ ChallengeLayer を閉じる。
- 旧形式の単一 `challenge` は互換読み取りを設けず、新しい Dedicated Server 契約へ統一する。

## テスト戦略

### ユニットテスト

- 同時に2人が課題を開始し、各自が完了できること。
- 片方だけを被弾中断しても、もう片方の課題が維持されること。
- ミス時に `miss_sequence` と時間ペナルティが更新されること。

### UIテスト

- 同時課題 snapshot でローカル課題の文字列とパネル表示が正しく反映されること。
- `miss_sequence` の増加で赤点滅・揺れ状態が開始し、同一 snapshot では再実行しないこと。

## 実装の順序

1. サーバー課題状態と snapshot 契約を slot 単位に変更する。
2. Dedicated Client の snapshot 反映とミス演出差分検出を変更する。
3. サーバー・UIテストを追加し、Godot 実行で確認する。
