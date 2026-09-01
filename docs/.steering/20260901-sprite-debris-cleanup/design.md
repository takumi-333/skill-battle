# 設計

## 処理位置

`pixelize_frame.py`で64×64px・二値alpha・固定パレットへ正規化した直後に、`cleanup_frame_artifacts.py`を実行する。cleanupで前景bboxが変わった場合は、cleanup済み画像を`pixelize_frame.py`へ再入力して目標高さ・パレット・二値alphaを再確定する。その後`--check-only`を実行し、組版後は`validate_sprite.py`が各セルを再検査する。

## 検出アルゴリズム

1. alpha閾値以上の画素から8近傍連結成分を作る。
2. 面積最大の成分を本体成分とする。
3. 各成分と本体成分の矩形間Chebyshev距離を計算する。
4. `max_component_gap`を超える成分、または本体bboxより完全に上側にある小成分を不要片候補とする。`min_component_area`未満の成分は本体から離れている場合だけ候補にする。上側成分は`max_above_primary_area`以下に限り自動削除し、面積が大きい成分は自動削除せず安全エラーにする。
5. 候補の除去画素数が`max_removed_pixels`を超える場合は出力を作成せず失敗する。
6. 出力後に同じ検査を再実行し、残留候補があれば失敗する。

## 設定

asset specの`artifact_cleanup`に以下を追加する。

```json
{
  "enabled": true,
  "alpha_threshold": 8,
  "min_component_area": 2,
  "max_component_gap": 8,
  "max_auto_remove_area": 12,
  "remove_above_primary": true,
  "max_above_primary_area": 32,
  "max_removed_pixels": 64
}
```

`max_component_gap`は本体からの距離であり、杖や髪など近接した正当な分離成分を保持する。大きく離れた成分は面積にかかわらず自動削除せず、レビュー可能なエラーとする。

## レポート

`cleanup_frame_artifacts.py`は入力・出力、成分数、保持成分、除去候補、除去画素数、残留候補、判定をJSONで出力する。`validate_sprite.py`は各セルの`artifact_cleanup`結果をvalidation reportへ含める。
