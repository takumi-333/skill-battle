# 設計書

## 方針

試合計算はDedicated Serverだけが実行する。クライアントはサーバーから受けた状態を表示するため、今回の補間は表示専用とし、HP・位置・命中・勝敗をクライアントが確定しない。

```text
client input (unreliable, sequence)
        ↓
MatchSession が最後の入力を保存
        ↓
Dedicated Server accumulator
  1/60秒ごとに MatchSession.step(FIXED_DELTA)
        ↓
MatchSimulation が正の状態を更新
        ↓
20Hz snapshot (unreliable_ordered)
  server_tick / input_acknowledgements / 受信者向け状態
        ↓
client snapshot buffer
  離散状態は即時反映、連続状態は補間して描画
```

## 固定tick

`DedicatedServer._process()` は経過時間をaccumulatorへ加える。1/60秒以上蓄積した分だけ、最大catch-up回数まで各roomの`MatchSession.step()`を呼ぶ。遅延が上限を超えた場合は余分な蓄積を破棄し、スパイラル状の負荷増大を防ぐ。snapshot送信は別の20Hz accumulatorで判定する。

`MatchSession` はslotごとの最終受理移動入力連番を保持し、snapshotへ公開する。入力の失効やクライアント予測は今回の範囲外とする。

## snapshot契約

状態snapshotはroot nodeの同じRPCパスで`unreliable_ordered`に統一する。イベントにより即時送信するsnapshotも同じ契約を用いる。最新の状態が届けば十分であり、欠落した旧snapshotを再送しない。

snapshotには以下を入れる。

- `server_tick` と `input_acknowledgements`
- room phase、Ready、時間、勝敗、状態文言
- 描画・HUDに必要なプレイヤー状態
- 受信者本人の課題（正解は除外）
- 生存中のスキル実体

他プレイヤーの課題問題文・入力済み文字・なぞり軌跡は送らない。相手の集中状態はプレイヤー状態で表現できる。

## クライアント補間

クライアントは最新2件の連続状態を保持する。サーバーtick差を使って補間比率を求め、プレイヤー位置・向き、スキル実体の連続値を補間して既存描画配列へ適用する。IDを持つ飛翔体・三叉震槌はIDごとに対応付け、片方にだけ存在する新規／終了実体は最新状態を採用する。

HUD、課題UI、Ready、phase、結果は補間せず、最新snapshotから直接更新する。補間用の状態はDedicated接続を離れると破棄する。

## 軽量化

完全な差分同期は、`unreliable_ordered`の欠落を検出するベースライン確認が必要になるため今回導入しない。代わりに、受信者ごとの課題フィルタリング、明示的なプレイヤー表示状態の構築、非活動エンティティを送らない既存配列の利用により安全に縮小する。

## テスト

- fixed tick accumulatorと入力確認番号を`MatchSession`／プロトコルテストで確認する。
- snapshotが正解と他者の課題詳細を含まないことを確認する。
- 補間ヘルパーを単体テストし、位置・向き・ID対応の挙動を確認する。
- 既存のGodotヘッドレステストとメインシーン起動を実行する。
