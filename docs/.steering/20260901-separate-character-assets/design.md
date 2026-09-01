# キャラクター実行用アセットの分離 — 設計

実行中の素材はファイル名の接尾辞で分類する。

| 用途 | 配置先 | Godot利用箇所 |
| --- | --- | --- |
| キャラクター選択用の待機立ち絵 (`*_idle.png`) | `assets/characters/portraits/` | 選択UIのプレビュー |
| 戦闘用8方向シート (`*_pixel_8dir.png`) | `assets/characters/sprites/` | 戦闘中のキャラクター表示 |

`match_prototype.gd` の明示的な `preload()` パスを新しい配置先に更新する。対応する `.import` ファイルも移動し、`source_file` を更新して既存UIDを保つ。`assets/characters/old/` はGodotスキャン対象外の旧版退避領域であり、本作業では内容を変更しない。
