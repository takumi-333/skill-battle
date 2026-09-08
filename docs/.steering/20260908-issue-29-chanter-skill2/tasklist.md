# タスクリスト

- [x] 既存の詠唱士スキル2・課題・投射物同期経路を確認し、改修方針をステアリングへ記録する。
- [x] 詠唱士スキル2の仕様書を「望月」と新しい課題・発射仕様へ更新する。
- [x] ローカル対戦とサーバー権威シミュレーションに、スコア別周回数、固定方向、移動後の発射位置、ダメージ、5秒クールダウンを実装する。
- [x] 新アイコン・弾アセットと渦巻き状の目標紋章を実装する。
- [x] スキル2の発射列、ダメージ、追従発射位置、課題を検証する自動テストを追加する。
- [x] Godotテストとヘッドレス起動を実行し、結果と振り返りを記録する。

## 検証結果

- `godot --headless --path . --script res://tests/network/match_simulation_test.gd`: 成功。スコア境界ごとの周回数、開始方向、固定弾道、移動後の発射位置、ダメージ、渦巻き目標を検証。
- `godot --headless --path . --script res://tests/network/lobby_ready_ui_test.gd`: 成功。
- `godot --headless --path . --script res://tests/network/rpc_contract_test.gd`: 成功。
- `godot --headless --path . --script res://tests/trace_evaluator_test.gd`: 成功。
- `godot --headless --path . --quit-after 3`: 成功。スクリプトのパースエラーなし。
- 新アイコンの初回インポートは `godot --headless --editor --path . --quit` で実行した。全コマンドで `user://logs`、Windows 証明書ストア、エディタ設定保存に関する環境警告が出たが、各検証コマンドは終了コード0だった。

## 振り返り

- スキル2は最大160発を予約するため、サーバー権威シミュレーションの投射物上限を192へ拡張した。
- 方向を固定する状態と、発射時の発動者位置を取得する状態を分けることで、打鍵士のターゲット狙い弾の挙動を変えずに要件を満たした。
- Godotに新規PNGを認識させるには、初回だけエディタのアセットインポートが必要だった。
