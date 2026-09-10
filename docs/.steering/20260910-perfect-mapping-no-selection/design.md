# 設計

`perfect_mapping_effects` に `no_selection: true`、`tile_count: 0` の状態を追加する。通常と同じ1.2秒間の座標平面演出で、選択タイルの代わりに空の選択枠・収束する円環・交差線を描画する。更新処理は選択なし状態でコピー技を発動しない。
