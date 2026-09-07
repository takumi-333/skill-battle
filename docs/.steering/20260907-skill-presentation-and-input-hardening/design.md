# 設計書

## データフロー

```text
server: スキル実体を生成
  ├─ reliable `receive_skill_presentation`（ID・種別・開始tick・初期表示値）
  └─ unreliable_ordered snapshot（正の状態）
                 ↓
client: 表示用演出状態を開始・毎フレーム進行
  └─ snapshotで最短経路補正、消滅・生成・権威状態を反映
```

演出イベントはダメージを含まず、クライアントがサーバー状態を変更する経路も持たない。イベントを失ってもsnapshotから演出状態を開始できるため、reliableイベントは即応性、snapshotは復旧と補正を担当する。

## スキル実体IDと表示更新

既存の`projectile_id`、`impact_id`に加え、魔法陣、衝撃波、分身、ハンマー回転へ単調増加IDを追加する。クライアントはIDごとに表示状態を持つ。

ハンマー回転は`presentation_angle`をクライアントのdeltaで進める。snapshotの`angle`との差は`wrapf(target - current, -PI, PI)`で最短角度に正規化してから小さく補正する。snapshotが停止・消滅を示したIDは表示状態を破棄する。

他の連続実体は既存のsnapshot補間を維持しつつ、IDで対応付ける。これにより、同じownerが次の演出を開始しても前の実体として補間しない。

## 移動入力の失効

`MatchSession`はslotごとに最後に受理したserver tickを保存する。固定tickでの経過が`INPUT_STALE_TICKS`を超えたslotは、`Vector2.ZERO`を使う。次の有効な入力を受ければ直ちに復帰する。

## なぞり妥当性

サーバーは開始tickをchallengeに保存する。提出時に、最小点数、連続点間の最大距離、最小軌跡長、最小経過tickを確認する。満たさない軌跡は`TraceEvaluator`の結果にかかわらず失敗として終了する。基準値は通常のマウス入力を妨げず、瞬間的な完全軌跡送信だけを拒否する値にする。

## テスト

- 移動入力失効後の停止と、次の入力での復帰を確認する。
- 演出IDとスキル演出イベントを生成するsnapshot／セッションテストを追加する。
- 角度境界をまたぐ最短角度補間をテストする。
- なぞりの早過ぎる・短過ぎる・不連続な軌跡が失敗することを確認する。
