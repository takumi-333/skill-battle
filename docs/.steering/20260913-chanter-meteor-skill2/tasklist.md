# タスクリスト

- [x] 既存のスキル選択・課題・描画・同期処理を確認し、流月雨の状態設計を確定する。
- [x] スキル2候補、専用複合紋章課題、表示名、仕様書を追加する。
- [x] サーバー権威の隕石予約・着弾・ダメージ・スナップショット同期を実装する。
- [x] ローカル／Dedicated Serverクライアントで影、落下隕石、着弾波紋を描画する。
- [x] 回帰テストを追加し、Godotテスト・ヘッドレス起動・差分検査を実行する。

## 追加: 流月雨アイコン採用

- [x] ユーザー指定のアイコン画像を確認し、透明背景の専用アセットに変換する。
- [x] 専用アイコンを `assets/ui/skill_icons/` に配置し、流月雨のHUD表示を差し替える。
- [x] アイコン読み込みを含むGodot起動確認と差分検査を実行する。

## 検証結果

- 2026-09-13: `godot --headless --path . --script res://tests/network/match_simulation_test.gd` が成功。流月雨の選択、複合紋章、20個の予約、0.65秒間隔、2秒後の着弾、発動者への非ダメージ、8秒クールダウン、スナップショットを確認した。
- 2026-09-13: `godot --headless --path . --script res://tests/network/rpc_contract_test.gd` が成功。Dedicated ServerのRPC契約にエラーがないことを確認した。
- 2026-09-13: `godot --headless --path . --script res://tests/network/lobby_ready_ui_test.gd` が `online lobby ready UI tests passed` で成功。ローカル開発用設定の既存アサート表示と、`user://logs`・Windows証明書ストアの環境警告は発生したが、終了コードは0だった。
- 2026-09-13: `godot --headless --path . --quit-after 3` が成功。起動時のスクリプトエラーは発生しなかった。`user://logs`・Windows証明書ストアの環境警告のみ確認した。
- 2026-09-13: `git diff --check` で空白エラーがないことを確認した。
- 2026-09-13: ユーザー指定の流月雨アイコンを透明背景PNGとして `assets/ui/skill_icons/chanter_meteor_shower.png` に配置し、`godot --headless --path . --script res://tests/network/match_simulation_test.gd` と `godot --headless --path . --quit-after 3` が成功した。`user://logs` とWindows証明書ストアの環境警告のみ確認した。

## 実装後の振り返り

- 実装完了日: 2026-09-13
- 計画との差分: 隕石の当たり判定半径は48px、視覚素材は演出スプライト規格に合わせて128×192pxで描画した。既存の望月は残し、流月雨をスキル2の第2候補として追加した。
- 学び: Dedicated Serverで位置と経過時間を同期すれば、クライアント側は同じ隕石状態を描画するだけで、ランダムな落下位置とダメージの整合性を保てる。
- 次回への改善: 実ゲーム画面で、20個連続時の視認性とダメージ量をプレイテストして、落下範囲・予告時間・ダメージ式を調整する。
- 追加変更: 画像生成による透明化では波紋周辺に不要な粒が発生したため、ユーザー指定画像から白背景だけを除去して、承認済みの図形と配色を維持した。
