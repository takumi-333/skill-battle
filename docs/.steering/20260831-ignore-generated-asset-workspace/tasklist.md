# 生成アセット作業領域の除外 タスクリスト

## Phase 1: 除外設定

- [x] `.gitignore`に`assets/generated/`の生成物除外を追加する
- [x] `assets/generated/.gdignore`を追加する
- [x] `assets/manifests/`・`assets/motions/`・`assets/specs/`をGit除外に追加する
- [x] 3ディレクトリに`.gdignore`を追加する
- [x] 既存の生成候補ファイルを削除せず、ローカル保存を維持する

## Phase 2: 運用ドキュメント

- [x] キャラクターアセット制作ガイドにGit／Godot除外の運用を追記する
- [x] AIスプライトパイプライン設計の生成作業領域ポリシーを確定する

## Phase 3: 検証

- [x] `git check-ignore`で4作業領域の内容がGit除外され、`.gdignore`だけが例外であることを確認する
- [x] 採用素材とツールがGit除外されていないことを確認する
- [x] `git diff --check`を実行する

## 実装後の振り返り

- 完了日: 2026-08-31
- 結果: 生成途中の画像・レポート・manifest・motion spec・asset specを4作業領域へ集約し、GitとGodotの双方から除外する規約に拡張した。
- 判断: これらは生成ごとに増える作業記録として扱い、正式な仕様だけを`docs/specs/`へ残す。
