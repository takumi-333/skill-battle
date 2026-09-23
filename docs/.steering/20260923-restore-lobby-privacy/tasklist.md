# タスクリスト

- [x] ロビーの既存配置とプレビュー設定の回帰箇所を確認する
- [x] duel の固定配置を毎回復元する
- [x] 相手キャラクターのシークレット表示を duel / FFA 共通にする
- [x] UI自動テストを追加・更新する
- [x] Godot UIテストと起動確認を行う

## 検証結果

- `tests/ui/ffa_lobby_ui_test.gd` で FFA の3枠、duel への座標復元、duel / FFA 両方の相手プレビュー秘匿を確認した。
- `tests/network/match_simulation_test.gd` を回帰確認として実行した。
