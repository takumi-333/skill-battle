# 設計

`scenes/ui/cpu_battle_screen.tscn` に旧デバッグ画面と同様の中央フレーム、左右の名前・立ち絵・キャラクター切り替え、下部の対戦開始、左上の戻るを固定部品として配置する。CPUレベル選択はCPU側の立ち絵の下に配置し、操作対象選択ボタンは置かない。

立ち絵のテクスチャは `update_cpu_selection_labels()` から既存の `get_idle_texture()` で切り替える。CPU対戦のルールやAIは変更しない。既存の `docs/specs/画面一覧仕様書/CPU対戦ロビー.md` の画面要素だけを更新する。
