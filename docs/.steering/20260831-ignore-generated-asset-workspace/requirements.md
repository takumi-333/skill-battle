# 生成アセット作業領域の除外 要求

## 目的

AI生成や画像変換の過程で作られる大量の中間ファイルを、Gitの変更一覧とGodotのFileSystem／インポート対象から除外する。今後のキャラクター、UI、エフェクトなどのアセット制作でも同じ運用を使えるようにする。

## 要求

- `assets/generated/`、`assets/manifests/`、`assets/motions/`、`assets/specs/`を生成パイプラインの共通作業領域とする。
- raw画像、透過処理後画像、個別フレーム、候補シート、検査レポート、manifest、motion spec、asset specをGit管理対象外にする。
- 上記4ディレクトリをGodotのスキャン／インポート対象外にする。
- 除外設定そのものはリポジトリに残し、別環境でも同じ挙動にする。
- 採用済みランタイム素材と生成ツールは除外しない。
- 正式に残す仕様は`docs/specs/`へ、実行用素材は`assets/characters/`へ配置する。
- 既存の生成候補ファイルは削除せず、設定追加後もローカルで参照できる状態を保つ。

## 完了条件

- `git status` に`assets/generated/`内の既存生成物が表示されない。
- `assets/generated/.gdignore`、`assets/manifests/.gdignore`、`assets/motions/.gdignore`、`assets/specs/.gdignore`が存在する。
- 既存の採用素材とツールがignoreされていない。
