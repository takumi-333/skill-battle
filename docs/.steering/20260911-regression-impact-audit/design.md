# 調査方針

1. Git差分と既存仕様から、変更された公開API契約、起動設定、クライアント接続設定、Dedicated Serverの入室状態遷移を確認する。
2. PythonのLobby/Gatewayテスト、Godotネットワーク・UIテスト、Godotヘッドレス起動、PowerShell構文検証を実行し、既存導線への回帰を検出する。
3. 実行結果と静的レビューを照合し、重大度と影響範囲を付けて報告する。外部Funnel、playit.gg、別回線が必要な確認は未検証として明記する。
