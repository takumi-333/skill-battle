---
name: local-debug-session
description: ローカル対戦サーバーと、ユーザーが指定した台数のGodotゲームクライアントをデバッグ用に起動・確認する。Skill Battleのローカル複数クライアント検証時に使う。
---

# ローカルデバッグセッション

`X台` のようにクライアント台数が明示されたとき、Lobby API・Dedicated Server・X台のGUIクライアントを起動する。

## 起動

- 台数が未指定なら、起動前に必要なクライアント台数を一つだけ質問する。台数を推測したり、追加のクライアントを起動したりしない。
- プロジェクトルートで次を実行する。`X` はユーザー指定の正の整数に置き換える。

```powershell
& .\.agents\skills\local-debug-session\scripts\start-debug-session.ps1 -ClientCount X
```

- スクリプトは既存の `deploy/windows/start-local.ps1 -NoBrowser` を使う。Lobby API と Dedicated Server がすでに安全に管理されている場合は再利用する。
- 各クライアントは `.local-server/debug-clients/` 以下の別々のユーザーデータ領域で実行される。起動後、サーバーの稼働状況と全クライアントプロセスを確認し、PIDと台数を簡潔に報告する。
- 起動に失敗した場合は、成功済みのプロセスを勝手に停止せず、失敗したコンポーネントと確認先を報告する。再試行や停止はユーザーの指示があるときだけ行う。

## 停止

停止を依頼された場合だけ、クライアントとローカルサーバーを別々に停止する。

```powershell
& .\.agents\skills\local-debug-session\scripts\stop-debug-clients.ps1
& .\deploy\windows\stop-local.ps1
```

最初のスクリプトは、このスキルが記録したPIDと開始時刻が一致するクライアントだけを停止する。`.local-server/debug-clients/` のログとユーザーデータは削除しない。
