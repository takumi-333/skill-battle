# 設計方針

1. `export_presets.cfg` に `Windows Client` の release preset を追加する。PCK は実行ファイルへ埋め込み、サーバー、運用資料、テスト、ローカル状態を export filter から除外する。
2. `deploy/windows/build-client-release.ps1` は Godot 4 の release export を時刻付き `build/releases/` 配下へ出力し、友人向け手順書を同梱した ZIP を生成する。既存の成果物を削除・上書きしない。
3. `deploy/windows/show-client-invite.ps1` は、ホストが明示した Funnel HTTPS URL と `public.env` の shared invite token だけを画面へ表示する。配布物やログへ秘密値を書き込まない。
4. `deploy/windows/CLIENT_DISTRIBUTION.md` に、ホストの起動・配布・対戦・停止の順序と、友人の初回設定操作を記載する。既存の公開運用手順を参照し、公開 URL と token の共有を同じ配布 ZIP で行わない。
5. 実際の release export、Godot headless 起動、既存のネットワーク UI テストを実行して検証する。
