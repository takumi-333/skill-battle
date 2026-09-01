# 設計書

## アーキテクチャ概要

既存の `MatchPrototype._draw()` の通常攻撃描画を差し替える。ゲーム状態の `attack_time` を唯一のタイムラインとし、通信同期済みの `facing` と `visual_id` から描画内容を決める。

```text
attack_time + facing + visual_id
  -> weapon texture / particle texture の選択
  -> pivot基準の武器回転
  -> 先端付近への粒子クラスター描画
```

## コンポーネント設計

### 攻撃演出テクスチャ

- `assets/effects/` に武器・粒子PNGを配置する。
- `visual_id` によって該当素材を返すヘルパーを追加する。

### 描画

- `draw_normal_attack_effect` を、武器回転と粒子描画を行う実装へ置換する。
- 武器のpivotは人物の手元付近に固定し、画像の柄尻を基準に配置する。
- 0〜1の攻撃進捗で、左側開始角度から右側終了角度へ補間する。
- 粒子は複数の進捗位置へ半透明で描画する。実体のゲーム状態を増やさない。

## テスト戦略

- Godot headless import/parseでGDScriptエラーがないことを確認する。
- 通常攻撃の既存ヒットエリアが残ることをコード上で確認する。
- 可能ならGodotを起動して画面上で3キャラの攻撃表示を確認する。
