# 設計

## 結果画面と公開Lobbyの分離

`MatchSession`に「新規入室だけを閉じる」状態を追加する。Dedicated Serverは試合終了時にこの状態とLobbyの`CLOSED`通知を使い、既存peerの結果操作は`terminal_closed`にしない。切断など、既存peerも継続できない場合だけ従来どおり`close_terminal()`を使う。

## ローカル開発設定

`start-local.ps1`は`.local-server/local-client.env`にLobby URLと招待tokenだけを書き出す。デバッグ版のGodotクライアントは、保存済みの公開設定がない場合だけ、このファイルを読み込む。release buildは`OS.is_debug_build()`とexport除外の両方でこの経路を使わない。HTTPは明示的な開発設定かつloopback URLだけ許可する。

## Dedicated Server再起動

Lobby Databaseに内部再起動reconcile操作を追加し、Dedicated Serverが起動して内部認証できた時点で非終端roomを`CLOSED`へ遷移させる。Dedicated Serverはこの完了まで新規joinを拒否し、失敗時は公開／consume必須モードで終了する。

## Funnel検査

`tailscale funnel status --json`をJSONとして走査し、`Proxy` targetをすべて抽出する。targetが一件だけで、正規化後に`http://127.0.0.1:8080`と一致する場合だけ公開可能とする。
