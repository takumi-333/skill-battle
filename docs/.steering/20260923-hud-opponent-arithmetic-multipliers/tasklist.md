# タスクリスト

- [x] HUDの既存HPバーと倍率表示の接続を確認する
- [x] 相手1・相手2用の倍率ラベルをシーンへ配置する
- [x] HUD更新を相手ごとの倍率表示へ変更する
- [x] duel / FFA の倍率表示をUIテストする
- [x] Godotテストと起動確認を行う

## 検証結果

- `tests/ui/opponent_arithmetic_hud_test.gd` で、算術士2人の独立表示、片方だけの表示、duel相当の1相手表示を確認した。
- `tests/ui/ffa_lobby_ui_test.gd` と `tests/network/match_simulation_test.gd` を回帰確認として実行した。
