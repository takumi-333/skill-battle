# タスクリスト

- [x] issue-35と既存の音声・失敗・三叉震槌・なぞり入力の経路を確認し、要件・設計を記録する。
- [x] 4音源を `assets/audio/` へ整理し、再生用の定数と共通ヘルパーを追加する。
- [x] ダメージ、三叉震槌着弾、課題ミスの音をローカル・P2P・Dedicated Server の経路へ実装する。
- [x] 詠唱者のなぞり中だけ本人に聞こえる連続音を実装し、停止条件を扱う。
- [x] キャラクター別スキル仕様書へ各音の再生条件・可聴範囲を記載する。
- [x] 自動テスト、Godotヘッドレス起動を実行して結果と振り返りを記録する。

## 検証結果

- `godot --headless --editor --path . --quit`: 成功。追加した4音源をインポートした。
- `godot --headless --path . --script res://tests/network/lobby_ready_ui_test.gd`: 成功。Dedicated Serverの三叉震槌着弾遷移、音源配置、なぞり音プレイヤーの開始・停止を確認した。
- `godot --headless --path . --script res://tests/network/match_simulation_test.gd`: 成功。
- `godot --headless --path . --quit-after 3`: 成功。メインシーンの起動とスクリプトパースエラーがないことを確認した。
- 実行環境の `user://logs` 書込み、Windows証明書ストア、エディタ設定保存については権限／環境起因の警告が出たが、すべて終了コード0で完了した。

## 振り返り

- Dedicated Serverでは音をサーバーから再生せず、既存スナップショットのHP低下と三叉震槌の `released` 遷移をクライアントで検出して再生することで、両者に同期した音を届ける。
- なぞり音は入力イベントを通信せず、ローカルのマウス移動と90msの無操作判定だけで制御し、本人以外へは再生しない。
- issue-35は実装・検証完了後、`docs/issues/archives/issue-35.md` へ原文のまま移動した。
