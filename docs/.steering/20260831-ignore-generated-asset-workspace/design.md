# 生成アセット作業領域の除外 設計

## 配置規約

```text
assets/
├─ characters/       採用済みランタイム素材（Git管理・Godot読込）
├─ generated/        生成途中のローカル作業領域（Git除外・Godot除外）
├─ manifests/        生成履歴・レビュー情報（Git除外・Godot除外）
├─ motions/          生成用motion spec（Git除外・Godot除外）
└─ specs/            生成用asset spec（Git除外・Godot除外）
```

4ディレクトリには、生成器の出力、透過処理・pixelization後の中間画像、候補シート、build／validationレポート、生成用のmanifest／motion spec／asset specを集約する。成果物を採用するときだけ、検査済み画像を`assets/characters/`などのランタイム用ディレクトリへコピーする。正式な仕様として残す必要があるものは`docs/specs/`へ移す。

## 除外方式

- `.gitignore`で4ディレクトリの内容を除外する。
- 各ディレクトリの`.gdignore`を例外としてGit管理し、Godotにディレクトリ全体を無視させる。
- `.gdignore`以外の生成物は削除しない。既存の候補や将来の再レビュー用データもローカルに残せる。
- manifest、motion spec、asset specも生成単位の作業記録としてローカルに保持する。正式なプロジェクト仕様だけを`docs/specs/`へ昇格する。

## 運用上の注意

生成ツールの出力先は必ず`assets/generated/<asset-id>/`以下にする。`assets/characters/`へ直接生成せず、`promote_sprite.py`などの明示的な昇格処理だけが採用素材を書き込む。
