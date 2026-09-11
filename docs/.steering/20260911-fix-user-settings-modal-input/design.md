# 設計書

## アーキテクチャ概要

固定 UI の入力方針に従い、モーダルの入力遮断は `home_screen.tscn` に明示する。保存後にモーダルを閉じる操作は、ボタンの `pressed` シグナルを処理し終えた次のアイドルフレームへ送る。

```text
SaveButton pressed
  -> save_user_settings()
  -> ConfigFile.save(user://settings.cfg)
  -> call_deferred(close_user_settings)

UserSettingsModal / Dimmer: mouse_filter = STOP
  -> 背後の DebugButton へマウスイベントを渡さない
```

## コンポーネント設計

### 1. `scenes/ui/home_screen.tscn`

**責務**:

- ユーザー設定モーダルが画面全体の入力を受け、背面のホーム画面を操作不能にする。

**実装の要点**:

- `UserSettingsModal` と `Dimmer` を `MOUSE_FILTER_STOP` に明示設定する。
- パネルと保存ボタンは既存のクリック可能状態を維持する。

### 2. `scripts/match_prototype.gd`

**責務**:

- 検証と設定保存を完了してからモーダルを閉じる。

**実装の要点**:

- 保存成功時の `close_user_settings()` を `call_deferred()` に置き換える。
- 検証失敗と保存失敗は従来どおり同期的に表示を維持する。

### 3. `deploy/windows/build-client-release.ps1`

**責務**:

- Godot エクスポート後、出力された実行ファイルが安定するまで待機してからアーカイブする。

**実装の要点**:

- 固定の 5 秒待機ではなく、期限内に `SkillBattle.exe` が作成され、サイズが連続して変化しなくなることを確認する。
- 期限切れ時だけ、出力ファイル未作成として失敗させる。

## テスト戦略

- シーン定義でモーダルとディマーが入力停止になっていることを確認する。
- 保存処理が即時の画面遷移を行わず、遅延モーダルクローズを使うことをテストする。
- リリーススクリプトがエクスポート出力を待機して ZIP と SHA-256 を生成することを確認する。
- Godot のヘッドレス起動と Windows x64 エクスポートを実行する。

## 依存ライブラリ

追加なし。

## 変更対象

```text
scenes/ui/home_screen.tscn
scripts/match_prototype.gd
tests/ui/user_settings_modal_test.gd
deploy/windows/build-client-release.ps1
docs/.steering/20260911-fix-user-settings-modal-input/
build/releases/SkillBattle-Windows-x64-*.zip
```

## 実装の順序

1. モーダルの入力遮断と遅延クローズを実装する。
2. 回帰テストを追加し、Godot ヘッドレスで実行する。
3. エクスポート出力の安定待機を実装し、Windows x64 ZIP を再ビルドして SHA-256 を確認する。

## セキュリティ考慮事項

- テスト・ビルド出力・ステアリング文書に招待トークンを記録しない。

## パフォーマンス考慮事項

- 1 フレームの遅延クローズのみで、継続的な処理は追加しない。
