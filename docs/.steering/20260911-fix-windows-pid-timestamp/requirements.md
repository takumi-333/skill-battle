# 要求内容

## 概要

Windows の公開・ローカル起動スクリプトが、同一プロセスを PID 再利用と誤判定しないようにする。

## 背景

PowerShell 7 の `ConvertFrom-Json` は ISO 8601 の `started_at` を `System.DateTime` として復元する。既存実装はプロセス開始時刻の文字列とこの `DateTime` を直接比較していたため、同じ時刻でも比較が失敗し、公開起動・後始末が停止した。

## 実装対象の機能

### 1. PID 所有確認の正規化

- 記録済みの開始時刻が文字列、`DateTime`、または `DateTimeOffset` のいずれでも、UTC ticks に正規化して比較する。
- 実際に PID が再利用されていた場合は、従来どおり管理・停止を拒否する。
- 壊れた時刻記録は、安全側に倒して明確なエラーにする。

### 2. Windows 起動スクリプトの一貫性

- 公開用共通スクリプトとローカル起動・停止・状態確認スクリプトの同種比較を同じ判定方式にする。

### 3. 回帰検証

- PowerShell 7 が JSON 時刻を `DateTime` に復元する経路と、文字列の経路で同じプロセス開始時刻が一致することを検証する。
- 異なる開始時刻では拒否判定が維持されることを検証する。

## 受け入れ条件

- [ ] `ConvertFrom-Json` 後の `started_at` が `DateTime` でも、同じ UTC 時刻のプロセスは管理対象として認識される。
- [ ] 文字列として読まれた `started_at` でも同じ結果になる。
- [ ] 開始時刻が異なる PID 記録は引き続き拒否される。
- [ ] 公開・ローカルの各スクリプトで直接の文字列比較が残らない。
- [ ] Windows 向け PowerShell 回帰テストとスクリプト構文検証が成功する。

## 成功指標

- `start-public.ps1` を連続実行しても、同一プロセスに対して `has been reused` を誤表示しない。

## スコープ外

- 既に停止した古い PID ファイルの自動削除ポリシー変更。
- 公開トンネル、Funnel、playit.gg の設定変更。
- Lobby / Gateway / Dedicated Server のネットワーク仕様変更。

## 参照ドキュメント

- `docs/specs/自宅PC公開対戦サーバー運用方針.md`
- `deploy/windows/PUBLIC_OPERATION.md`
