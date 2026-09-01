# 開発用UI調整機能 削除手順

## 目的

開発中だけ使用する実行中UI調整機能を、ゲーム完成時に安全に取り外すための手順。

対象機能は以下。

- `F10`で起動するUI調整モード
- UIのドラッグ移動・サイズ変更
- 複数選択・整列・複製
- 数字キーによる画面プレビュー切替
- `res://resources/ui_layout_overrides.cfg` による位置・サイズ保存

## 削除前の確認

1. 必要なUI位置・サイズの調整を完了する。
2. `Ctrl + S`で保存した調整結果を、正式なUI座標へ反映する。
3. 保存結果を残す必要がなければ、Godotのユーザーデータにある `ui_layout_overrides.cfg` を削除する。
4. 削除前にGitなどで変更をコミット、またはバックアップを作成する。

## ソースコードの削除

対象ファイルは `scripts/match_prototype.gd`。

### 1. UIAdjustOverlayクラスを削除

ファイル先頭付近にある以下のクラス全体を削除する。

```gdscript
class UIAdjustOverlay extends Control:
```

### 2. UI調整用の変数・定数を削除

以下の名前を検索し、宣言ブロックを削除する。

- `ui_adjust_mode`
- `ui_adjust_targets`
- `ui_adjust_selected`
- `ui_adjust_index`
- `ui_adjust_drag_target`
- `ui_adjust_drag_offset`
- `ui_adjust_resize_mode`
- `ui_adjust_resize_target`
- `ui_adjust_overlay`
- `ui_adjust_hint`
- `UI_ADJUST_SAVE_PATH`

### 3. `_ready()`の初期化呼び出しを削除

以下の行を削除する。

```gdscript
create_ui_adjustment_tools()
```

### 4. UI調整用関数を削除

以下の関数を、それぞれ関数の終端まで削除する。

- `create_ui_adjustment_tools`
- `collect_ui_adjust_targets`
- `register_ui_adjust_target`
- `load_ui_layout_overrides`
- `save_ui_layout_overrides`
- `toggle_ui_adjust_mode`
- `update_ui_adjust_hint`
- `move_ui_adjust_target`
- `resize_ui_adjust_target`
- `align_ui_adjust_targets`
- `duplicate_ui_adjust_target`
- `preview_ui_adjust_screen`
- `handle_ui_adjust_input`

### 5. `_input()`の先頭処理を削除

以下のブロックを削除する。

```gdscript
if handle_ui_adjust_input(event):
    get_viewport().set_input_as_handled()
    return
```

既存の `_input()` 本体、通常のボタン処理、ゲーム操作処理は残す。

## 保存データの扱い

調整機能は `res://resources/ui_layout_overrides.cfg` に保存する。これはGit管理対象のプロジェクト内ファイルである。

過去版の調整機能が作成した `user://ui_layout_overrides.cfg` は、移行確認後に不要なら削除する。

不要になった場合は、Godotのユーザーデータフォルダ内にある次のファイルだけを削除する。

```text
res://resources/ui_layout_overrides.cfg
```

旧ファイルの場所が分からない場合は、Godotの「エディタ設定」ではなく、実行プロジェクトのユーザーデータフォルダを確認する。

## ドキュメントの扱い

履歴として残す場合は、以下のステアリング資料は削除せず保管する。

- `docs/.steering/20260902-runtime-ui-adjustment/`
- `docs/.steering/20260902-fix-runtime-ui-adjustment/`
- `docs/.steering/20260902-powerpoint-ui-editor/`
- `docs/.steering/20260902-ui-preview-screens/`
- `docs/.steering/20260902-hidden-ui-adjustment/`
- `docs/.steering/20260902-runtime-ui-resize-adjustment/`

プロジェクトを軽くしたい場合でも、削除対象は履歴資料だけに限定し、`docs/specs/`の正式仕様は削除しない。

## 削除後の確認

1. `rg "ui_adjust|UIAdjust|preview_ui_adjust|handle_ui_adjust" scripts docs` で残存箇所を確認する。
2. Godotでプロジェクトを開き、スクリプトエラーがないことを確認する。
3. ゲームを起動し、通常の画面遷移とボタン操作を確認する。
4. `F10`、`Ctrl+D`、`Ctrl+S`、数字キーによる画面プレビューがゲーム操作へ悪影響を与えないことを確認する。
5. 調整機能を残したままリリースしない。特に、調整モード中のボタン入力遮断処理を中途半端に削除しない。

## 注意

UI調整機能を削除しても、調整結果が正式な座標としてソースコードやリソースに反映されるわけではない。削除前に、必要な座標・サイズを `scripts/match_prototype.gd` や `resources/menu_layout.tres` へ反映すること。
