# 設計

## 保存するスキル構成

- `MatchPrototype` に保存ファイル名、設定セクション、既定構成を定義する。
- `ConfigFile` を使い、`user://` 配下の設定ファイルへ `typist`、`arithmetician`、`chanter` の各3スロット構成を書き込む。
- UI のノード参照を初期化した後、最初の `update_character_screen()` より前に読込みを行う。SAVE 押下時にはメモリの選択値を保存し、成功時だけ保存済み表示を更新する。
- 旧ファイルなし・読み込み失敗・壊れた値は例外にせず既定構成を採用する。候補数・実装済み判定は既存の `is_skill_candidate_implemented()` と `first_implemented_skill_candidate()` を使って正規化する。

## オンラインの BGM

- BGM の再生自体は各クライアントの `BattleBGMPlayer` が担当しているため、音量判定もそのクライアントのローカルプレイヤーに限定する。
- `network_mode == "client"` では `local_player_id` の `focused` だけを判定する。既存の host／local／practice のローカル側ID規則も共通ヘルパー化して扱い、ローカル対戦の既存挙動は変えない。
- `AudioServer` の `BattleBGM` バス効果とプレイヤー音量はプロセス内で完結するため、ネットワーク経由で音量を送らない。

## 試合終了時の課題 UI

- 課題 UI の終了を `set_challenge_overlay_visible(false)` だけに依存せず、課題進行値・なぞり描画・タイピング入力・入力フォーカス・筆記音をまとめて停止する共通終了処理を設ける。
- `finish_match()`、`show_result()`、P2P の状態反映、Dedicated Server の snapshot 反映で、試合が `finish`／`result` に遷移したときこの処理を呼ぶ。
- 画面親の可視性は既存どおり `apply_screen_state()` → `UIScreenManager.show_screen()` を唯一の窓口とし、課題レイヤーは画面遷移の副作用としても必ず非表示にする。

## 検証

- 永続化は一度保存した値を新規 `MatchPrototype` 相当の読込み処理で復元できること、不正ファイルで安全に既定値へ戻ることをテストする。
- BGM はローカルプレイヤーと相手プレイヤーの集中状態を個別に切り替え、前者だけ減衰判定が真になることをテストする。
- P2P と Dedicated Server の終了 snapshot／状態を投入し、課題レイヤー、タイピング入力、なぞり描画が非表示・非アクティブになることをテストする。
