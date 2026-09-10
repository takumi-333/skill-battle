# 設計方針

1. `MatchProtocol.valid_event()` の loadout 用 `big_skill` 許可リストへ `typist_golden_time_ii` を追加する。
2. `MatchSession._reset_simulation_preserving_loadouts()` の `small_skill` 判定へ `typist_golden_time_i` を追加する。
3. 既存のネットワークシミュレーションテストへ、黄金時間IIの通信受理・状態反映と、黄金時間Iの再戦復元を追加する。
4. Godot headless テストとプロジェクト起動確認を実行し、既存の作業ツリー変更を保持する。
