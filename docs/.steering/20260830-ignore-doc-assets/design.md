# 実装方針

- `docs/.gdignore`を追加し、Godotに`docs/`以下をスキャンさせない。
- `.gitignore`に`*.import`を追加し、プロジェクト内の生成済みimportメタデータを追跡対象外にする。
- 既に追跡されている`docs/**/*.import`はインデックスから削除する。作業ツリーの画像やMarkdownは残す。
