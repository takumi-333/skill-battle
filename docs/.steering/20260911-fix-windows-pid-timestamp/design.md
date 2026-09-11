# 設計書

## アーキテクチャ概要

PID 記録は PID と UTC 開始時刻でプロセスの所有権を確認する。記録の時刻型だけを UTC ticks に正規化し、PID 再利用の安全境界は維持する。

```text
pid.json started_at
  ├─ JSON string (Windows PowerShell)
  ├─ DateTime (PowerShell 7)
  └─ DateTimeOffset
           │
           ▼
     UTC DateTime.Ticks
           │
Process.StartTime UTC ticks ── 一致判定 ──> 管理を許可 / 拒否
```

## コンポーネント設計

### 1. 開始時刻正規化ヘルパー

**責務**:

- JSON から復元された値を UTC ticks に変換する。
- 既存の ISO 8601 文字列との互換性を保つ。

**実装の要点**:

- `DateTime` と `DateTimeOffset` は型のまま UTC ticks を取得する。
- 文字列は round-trip 形式として不変カルチャで解析する。
- 解析不能な値は所有確認失敗として扱う。

### 2. 公開・ローカルの PID 管理

**責務**:

- 正規化ヘルパーを使い、プロセス開始時刻を比較する。

**実装の要点**:

- PID または開始時刻が違う場合は、既存どおり停止も置換も行わない。
- 同一プロセスの `DateTime` 復元だけを許可する。

## エラーハンドリング戦略

- `started_at` が欠落・解析不能なら、PID 所有者を断定せず、管理を拒否するエラーを出す。
- ticks が不一致なら、従来の PID 再利用エラーを維持する。

## テスト戦略

### PowerShell 回帰テスト

- `ConvertFrom-Json` の `DateTime` 値、ISO 文字列、`DateTimeOffset` が同じ開始時刻として一致する。
- 1 tick 異なる時刻は一致しない。
- `public-common.ps1` の既存 Funnel 検査も継続して成功する。

### 構文検証

- 変更した Windows PowerShell スクリプトを PowerShell AST で構文解析する。

## ディレクトリ構造

```text
deploy/windows/public-common.ps1
deploy/windows/start-local.ps1
deploy/windows/stop-local.ps1
deploy/windows/status-local.ps1
tests/windows/public_common_test.ps1
docs/.steering/20260911-fix-windows-pid-timestamp/
```

## 実装の順序

1. 既存 PID 所有確認を型安全な UTC ticks 比較へ置換する。
2. JSON `DateTime` と文字列の回帰テストを追加する。
3. PowerShell テスト・構文検証・可能な範囲の実行確認を行う。

## セキュリティ考慮事項

- 時刻の正規化は PID と開始時刻の両方の確認を弱めない。
- PID 記録、秘密値、ログ本文をテスト出力へ出さない。

## パフォーマンス考慮事項

- 起動・停止時に一度だけ実行される定数時間の比較である。

## 将来の拡張性

- JSON 逆シリアル化の時刻型が変わっても、正規化関数内で扱える。
