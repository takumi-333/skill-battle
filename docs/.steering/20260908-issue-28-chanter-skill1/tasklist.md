# タスクリスト

- [x] 既存の詠唱士スキル1仕様・実装・オンライン同期経路を確認し、改修方針をステアリングへ記録する。
- [x] スキル1の仕様書を「月柱・昇華」と新しいエリア／光柱タイムラインへ更新する。
- [x] ローカルとサーバー権威シミュレーションの魔方陣状態、継続ダメージ、表示用テクスチャ描画を実装する。
- [x] 詠唱士なぞり失敗時に既存と同様の赤色・揺れフィードバックを表示する。
- [x] タイムライン・継続ダメージ・失敗フィードバックを検証する自動テストを追加する。
- [x] Godotテストとヘッドレス起動を実行し、結果と振り返りを記録する。

## 検証結果

- `godot --headless --path . --script res://tests/network/match_simulation_test.gd`: 成功。エリアの0.5秒予告、固定位置、継続ダメージ、失敗時にエリアを生成しないことを検証。
- `godot --headless --path . --script res://tests/network/lobby_ready_ui_test.gd`: 成功。
- `godot --headless --path . --script res://tests/network/rpc_contract_test.gd`: 成功。
- `godot --headless --path . --script res://tests/trace_evaluator_test.gd`: 成功。
- `godot --headless --path . --quit-after 3`: 成功。スクリプトエラーなし。
- 全コマンドで `user://logs` とWindows証明書ストアに関する環境警告が出たが、終了コードは0。

## 振り返り

- 光柱の見た目と判定範囲は分離し、判定は魔方陣の半径80px内だけに固定する。
- オンライン対戦は表示側だけでなくサーバー権威シミュレーションにも同じタイムラインを持たせる。
- なぞりはマウスを離した時点でしか最終スコアを確定できないため、失敗時は閉じる前に既存のミスフィードバックを短時間保持する。
