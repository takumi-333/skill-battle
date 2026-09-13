# タスクリスト

- [x] 要求と既存の三叉震槌衝撃波の実装を確認する。
- [x] 真上視点・全方向共用の衝撃波 PNG を作成して差し替える。
- [x] 三叉震槌の衝撃波へ向きを持たせ、回転した素材を描画する。
- [x] PNG、テスト、Godot ヘッドレス起動を検証する。
- [x] 検証結果と作業内容を記録する。

## 検証結果

- 2026-09-13: `typist_hammer_shockwave.png` が RGBA 64x64px、透明 3,645px／描画 451px であることを確認した。
- 2026-09-13: `godot --headless --path . --script res://tests/network/match_simulation_test.gd` が `server-authoritative match simulation tests passed` で完了した。
- 2026-09-13: `godot --headless --path . --quit-after 3` がシーン読み込みエラーなしで完了した。
- 2026-09-13: `git diff --check` が問題なしで完了した。

Godot 実行時に `user://logs` へのログ出力失敗と Windows のルート証明書ストア読込失敗が出るが、今回の変更に関係するスクリプト・素材の読み込みエラーは発生していない。

## 追加タスク: スプライト alpha 判定

- [x] 描画変換と一致する不透明ピクセル判定を共通化する。
- [x] ローカル対戦と専用サーバーの三叉震槌へ共通判定を適用する。
- [x] 不透明／透明ピクセルと既存ネットワーク挙動を検証する。

## 追加検証結果

- 2026-09-13: `typist_hammer_shockwave_hitbox.gd` が PNG の alpha が 0 より大きい 451 ピクセルを抽出し、描画と同じ位置・左向き基準回転・1.8倍拡大率で衝突判定へ変換するようにした。
- 2026-09-13: ネットワークシミュレーションテストで、不透明ピクセルは命中し、透明な左上隅ピクセルは命中しないこと、上向き回転後も不透明ピクセルが命中することを確認した。
- 2026-09-13: `godot --headless --path . --script res://tests/network/match_simulation_test.gd` と `godot --headless --path . --quit-after 3` がスクリプト／リソース読込エラーなしで完了し、`git diff --check` も問題なしで完了した。

## 訂正: 5方向のスキル弾へ適用

ユーザーの指定は、着弾後に広がる円形波動ではなく、三叉震槌から5方向へ飛ぶスキル弾だった。円形波動への変更は撤回し、以下を実施する。

- [x] 円形波動の描画・当たり判定を従来どおりへ戻す。
- [x] 5方向の三叉震槌スキル弾を専用スプライトへ置き換える。
- [x] 5方向のスキル弾と分身の当たり判定を不透明ピクセルへ合わせる。
- [x] 透明／不透明ピクセル、回転、専用サーバー判定をネットワークシミュレーションテストで確認する。

### 訂正後の検証結果

- 2026-09-13: 三叉震槌の5方向スキル弾がすべて `typist_hammer_shockwave` フラグを持つことをネットワークシミュレーションテストで確認した。
- 2026-09-13: 不透明ピクセルは命中し、透明な左上隅ピクセルは命中しないこと、上向きに回転した弾でも不透明ピクセルが命中することを確認した。
- 2026-09-13: `godot --headless --path . --script res://tests/network/match_simulation_test.gd` が `server-authoritative match simulation tests passed` で完了し、`godot --headless --path . --quit-after 3` および `git diff --check` も完了した。

## 追加タスク: 周囲波動の描画順

- [x] 周囲波動をプレイヤーより後ろの地面レイヤーへ移動する。
