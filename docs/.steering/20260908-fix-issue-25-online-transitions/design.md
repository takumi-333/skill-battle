# 設計

## MatchSession

- `leave()` は切断直前の `phase` を確認する。`match` 中だけ `finish_by_disconnect()` と `result` 遷移を行い、`lobby` 中は接続 slot の削除と待機状態の更新だけを行う。
- `rematch_ready` を slot ごとの状態として保持する。リザルトで `rematch` を受けたら当該 slot だけを true にし、両方が true のときだけ試合状態をリセットして `match` へ遷移する。
- `lobby` を受けたときは既存のロビー復帰処理を即時に行い、`rematch_ready` も初期化する。
- snapshot に `rematch_ready` を追加する。

## クライアント UI

- snapshot の `rematch_ready` を取り込み、リザルト画面の再戦ボタンを選択済みのローカル peer では無効化し、テキストと結果メッセージに待機状況を反映する。
- ロビー復帰 snapshot を受けた時点で `apply_screen_state("online_waiting")` を通るため、結果画面の再戦ボタンは画面ごと非表示になる。

## テスト

- `MatchSession` のロビー中切断、試合中切断、片方／両者の再戦、ロビー復帰を検証する。
- UI テストでリザルト snapshot の再戦ボタン状態と、ロビー遷移後に相手シルエットが消えることを確認する。
- RPC 契約テストは、仕様どおり snapshot の `unreliable_ordered` を検証する。
