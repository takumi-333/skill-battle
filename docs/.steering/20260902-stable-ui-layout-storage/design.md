# 設計

- 保存先を `res://resources/ui_layout_overrides.cfg` とする。
- 調整対象の親画面、Control種別、表示テキスト、初期位置・サイズから安定キーを生成する。
- 旧 `user://ui_layout_overrides.cfg` は移行用に読み込み、現在のNodePathが一致する値を新しいキーへコピーする。
- Ctrl+SはGit管理対象の保存先へ書き込み、次回起動時に同じキーで復元する。
