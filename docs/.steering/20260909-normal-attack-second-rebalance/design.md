# 設計書

## アーキテクチャ概要

通常攻撃の基礎値は Dedicated Server の `MatchSimulation` とローカル／デバッグ対戦の `match_prototype.gd` に別々に定義される。両方の値を同期し、キャラクター仕様書も同じ数値へ更新する。

```text
キャラクター選択
  → normal_damage を設定（3 / 1 / 2）
  → 既存の算術士バフ計算
  → ダメージを適用

基本クールダウン 5秒
  → 算術士のみ 5 ÷ 妨害ポイント係数
```

## 変更箇所

### `scripts/network/match_simulation.gd`

- `NORMAL_COOLDOWN` を `5.0` にする。
- キャラクター基礎ダメージ配列を `[3, 1, 2]` にする。

### `scripts/match_prototype.gd`

- `ATTACK_COOLDOWN` を `5.0` にする。
- キャラクター別の `normal_damage` 初期値を打鍵士3、算術士1、詠唱者2にする。

### キャラクター仕様書

- 3キャラクターの通常攻撃ダメージとクールダウンを更新する。

## テスト戦略

- 対象設定を静的検索し、全経路が指定値になっていることを確認する。
- Godot のheadless起動でスクリプトの読み込みエラーを確認する。

## 実装の順序

1. Dedicated Server を更新する。
2. ローカル／デバッグ対戦を更新する。
3. 仕様書を更新する。
4. 静的確認とGodot実行確認を行う。
