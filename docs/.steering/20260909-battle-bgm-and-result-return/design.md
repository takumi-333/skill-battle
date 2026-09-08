# 設計

## BGM

- `BattleBGMPlayer` を `main.tscn` の固定ノードとして追加し、`BattleBGM` バスへ出力する。
- `resources/battle_audio_bus_layout.tres` で `BattleBGM` バスと `AudioEffectLowPassFilter` を定義する。スクリプトは集中状態に応じてエフェクト有効化と音量トゥイーンを制御する。
- `begin_match()` とネットワーク同期の `countdown -> match` 遷移で再生を開始する。終了検知では残り時間 0 秒ならフェード、それ以外は即停止する。

## リザルト

- `MatchSession` は `result_lobby_slots` を保持する。最初のロビー復帰ではルーム全体の `phase` を `result` のままとし、復帰した受信者に限り snapshot の `phase` を `lobby` とする。
- 相手のロビー復帰後は `rematch_ready` を両者とも false にし、再戦要求を拒否する。snapshot に `result_lobby_slots` を含め、クライアント UI は相手が戻ったことを表示して再戦を無効化する。
- 両者の復帰後にのみ従来のリセットと全体ロビー遷移を行う。従来のホスト対戦は同じスロット状態を受信者別のネットワーク状態へ反映する。
