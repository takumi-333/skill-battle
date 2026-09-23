# 設計書

## アーキテクチャ概要

サーバー権威の判定を維持する。クライアントはマウス軌跡を記録・描画し、必要なら512点以内へ形状を保って間引いてから一度送信する。Dedicated Server はサイズ・型などの通信境界を検証した後、入力時間・点数・長さ・隣接距離の足切りを行わず、共有 `TraceEvaluator` で採点する。合格時の効果とクールダウンは現行 `MatchSimulation` の経路で決定する。

```text
Client: 軌跡を記録・描画
  └─ 512点以内の同じ軌跡を reliable event で送信
       ↓
MatchProtocol: 型・最大payload検証
       ↓
MatchSimulation: TraceEvaluatorで形状採点
  ├─ 合格 → 現行の成功・cooldown・_spawn_skill経路
  └─ 不合格 → 現行の失敗・cooldown経路 + 参加者向け結果通知
       ↓
Client: 成功は従来表示 / 不合格は赤表示・揺れ・ミス音後に閉じる
```

## コンポーネント設計

### MatchSimulation / MatchProtocol

**責務**:
- 提出された軌跡をサーバー上で採点し、成功時の効果を決定する。
- イベントの型・最大サイズとシーケンスを検証する。

**実装の要点**:
- `_valid_trace_submission` の経過時間、点数、長さ、点間距離の足切りを削除する。必要な通信境界検証は `MatchProtocol.valid_event` に残す。
- 不合格判定は既存 `TraceEvaluator` の `ng` と既存合格点を用いる。小技・大技・スキル3で既存のスキルID解決と発動効果を変更しない。
- 不合格時のクールダウン、集中解除、課題終了は `_end_challenge` を通し、現行の状態遷移を維持する。

### 軌跡送信とDedicated参加者UI

**責務**:
- サーバーへ送る軌跡をプロトコル上限に収める。
- サーバーが確定した結果を課題UIへ一度だけ反映する。

**実装の要点**:
- 入力点配列を上限内へ保つサンプリング／間引きをクライアント側に追加する。角や曲率を保ち、表示配列と送信配列を一致させる。
- 不合格結果は `receive_skill_presentation` のreliable通知へ `kind = "challenge_result"` として追加し、`owner_slot` とchallenge IDを含める。Dedicated Server は `owner_slot` に対応するpeerだけに転送する。20Hz unreliable snapshotだけに短い表示機会を依存させない。
- 結果通知には challenge/result ID と成功・失敗を含め、現行課題と一致する通知だけを一度適用する。通知欠落・重複・遅延で別の課題を閉じたり演出を重ねたりしない。
- 不合格時は既存 `trigger_challenge_miss_feedback`、ミス音、短時間表示後の課題終了を再利用する。シーン固定部品は増やさず、UI状態の実行時接続を既存の課題UI部品で行う。

## データフロー

### Dedicated対戦での失敗

1. 参加者がマウスを離し、整形済み軌跡を一度送信する。
2. サーバーは通信形式を検証し、`TraceEvaluator` の結果で成否を決める。
3. 不合格なら従来どおりスキルを出さず、失敗クールダウンを適用する。
4. サーバーがownerだけに送ったreliable結果通知を参加者クライアントがchallenge IDで照合し、赤表示・揺れ・ミス音を一度再生する。
5. 表示時間後に課題UIを閉じる。challenge消失snapshotが先着しても、失敗表示時間を保つ。

### Dedicated対戦での成功

1. サーバーが形状を合格と判定する。
2. 現行成功処理で課題を終了し、スキル効果・cooldownを一度だけ更新する。
3. 現行のスキルpresentation/snapshot経路を使って効果を表示する。

## エラーハンドリング戦略

- 不正な型、過大payload、誤ったイベント順序はプロトコル境界で拒否する。
- クライアント側の軌跡整形は上限内で完了し、上限超過をプレイヤー操作の失敗条件にしない。
- 形状採点による不合格は通常のゲーム結果として明示し、サーバー状態は既存失敗経路で確定する。
- 予期しないchallenge IDの通知は無視し、古い結果で現在のoverlayを変更しない。

## テスト戦略

### ユニットテスト

- 旧4条件に届かなくても、軌跡評価が合格なら成功すること。
- 旧4条件に届かなくても、形状評価が不合格なら不発動・失敗cooldownになること。
- 旧条件を満たす既存成功入力で、詠唱者各tierの効果数・skill ID・cooldownが変わらないこと。
- 512点超のローカル軌跡を整形した結果が上限内で、形状・始終点・鋭角を許容誤差内で保つこと。
- 型違い／最大点超過イベントが引き続きprotocolで拒否されること。

### 統合テスト

- slot 1 / slot 2 の成功と失敗を Dedicated `MatchSession` 経由で確認する。
- recipient向け不合格結果が一度だけ配送・表示され、overlay非表示snapshotとの競合で赤表示が消えないこと。
- スキル成功時に既存presentationとsnapshotから一度だけ演出され、失敗時は演出実体が生成されないこと。
- Dedicated以外のローカル・host経路でも、現行の赤NG・成功効果が維持されること。

## ディレクトリ構造

```text
scripts/network/match_simulation.gd      # 判定前の不可視足切りを除去
scripts/network/match_protocol.gd        # 既存の型・payload上限を維持
scripts/match_prototype.gd               # 軌跡上限整形と結果表示の接続
scripts/network/match_session.gd         # challenge結果presentationの収集
scripts/network/dedicated_server.gd      # owner_slotに応じたreliable結果通知の宛先制御
tests/network/match_simulation_test.gd   # サーバー採点・発動回帰
tests/network/lobby_ready_ui_test.gd     # 参加者表示・通知回帰
docs/specs/...                           # 実装後に仕様を反映
```

## 実装の順序

1. 成否判定と効果生成の現状をテストで固定し、4条件だけが原因の失敗を再現する。
2. サーバーの4つの足切りを削除し、TraceEvaluatorと現行スキル発動経路のみを使う。
3. クライアントの512点上限処理を追加し、描画と送信の軌跡を同一にする。
4. Dedicated失敗結果のrecipient専用reliable通知を追加し、課題UIの赤NG・揺れ・ミス音・終了遅延を接続する。
5. slot別成功／失敗、各tier、protocol上限、UI通知順序をテストし、Godot実行ログを確認する。
6. 詠唱者スキル仕様とオンライン通信仕様を実装へ合わせる。

## セキュリティ考慮事項

- サーバー権威の採点、成功閾値、効果生成、cooldownを維持する。
- 即時の正解軌跡送信に対する時間based anti-cheat はなくなる。これは不可視条件でプレイヤーを失敗させない要求との明示的なトレードオフである。
- RPCのイベント型、sequence、最大軌跡点数などのresource境界検証は維持し、クライアント採点結果を権威として受け取らない。

## パフォーマンス考慮事項

- 送信配列を512点以内に保ち、既存ネットワーク上限と採点処理量を維持する。
- 過大なローカル配列を毎フレーム複製せず、サンプリングを入力時に行うか、提出時に一度だけ整形する。
