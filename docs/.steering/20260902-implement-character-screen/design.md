# 実装設計

- 既存の `scripts/match_prototype.gd` にキャラクター画面の生成・更新・入力処理を追加する。
- `UIScreenManager` の画面名に `character` を追加し、メニューバックグラウンドではなくキャラクター背景を表示する。
- 背景、キャラクター選択、説明、3つの候補スクロール領域、選択中表示、SAVE、ホーム戻りを `Control` ノードとしてコード生成する。
- 既存の `character_names()` と `get_character_texture()` の3キャラクター識別子に合わせる。
- スキル候補は現段階のプレースホルダーアイコンを使い、キャラクターごとの選択状態を辞書で保持する。SAVE押下時に保存済み状態へ反映し、同キャラクターへ戻った際に復元する。
- 背景は `TextureRect` の `EXPAND_IGNORE_SIZE` + `KEEP_ASPECT_COVERED` で画面全体を覆い、既存UIと同じ1280x720基準座標でレイアウトする。
