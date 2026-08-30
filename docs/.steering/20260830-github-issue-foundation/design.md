# 設計書

## アーキテクチャ概要

GitHub標準のIssue Formsで入力を統一し、GitHub Actionsがラベルイベントを受けて同期専用のPRを作る。Codex実行は認証情報とrunnerを導入する第2段階まで接続しない。

```text
GitHub Issue Form
  ↓ draft
開発者が ready-for-agent を付与
  ↓ issues.labeled
GitHub Actions (issue-sync.yml)
  ↓ 専用ブランチ
docs/issues/issue-<番号>.md
  ↓
同期PR（レビュー・マージ）
```

## コンポーネント設計

### Issue Form

`.github/ISSUE_TEMPLATE/development-request.yml` に定義する。フォーム側のラベルは `draft` と `priority:normal` とし、実装開始の許可は人が明示的に `ready-for-agent` を付ける。

### ラベル定義

`.github/labels.json` はラベルの宣言を保持する。GitHubはこのファイルを自動適用しないため、初回はGitHub CLIで `scripts/setup-github-labels.ps1` を実行する。

### 同期ワークフロー

`.github/workflows/issue-sync.yml` は `issues.labeled` で起動し、イベント上のラベルが `ready-for-agent` のときだけ実行する。`actions/github-script` を用い、Issue本文はJavaScriptのファイルAPIで書き出す。イベント本文をシェル文字列へ展開しない。

同期用ブランチは `automation/issue-<番号>-sync` とする。既存ブランチがあれば更新し、同一Issueの既存PRを再利用する。`main`へのpushは行わない。

## エラーハンドリング戦略

- ラベルが異なるイベントはjob条件でスキップする。
- 同期対象の変更がない場合、PR作成は行わない。
- GitHub APIまたはpushに失敗した場合、ワークフローを失敗させ、実行ログで確認可能にする。

## テスト戦略

- YAMLをPowerShellで解析し、構文が有効であることを確認する。
- フォームに必須項目・初期ラベルがあることをテキスト検査する。
- ワークフローが `ready-for-agent` の条件、最小権限、PR作成処理を含むことを確認する。

## ディレクトリ構造

```text
.github/
  ISSUE_TEMPLATE/development-request.yml
  workflows/issue-sync.yml
  labels.json
scripts/setup-github-labels.ps1
docs/guides/Issue駆動Codex開発ガイド.md
```

## 実装の順序

1. Issue Formとラベル定義を追加する。
2. ラベルをGitHubへ適用するスクリプトを追加する。
3. 同期ワークフローを追加する。
4. ガイドを第1段階の利用方法で補足し、静的検査する。

## セキュリティ考慮事項

- ワークフローは最小限の `contents`、`issues`、`pull-requests` 権限だけを要求する。
- Issue本文をシェルへ渡さない。
- 同期先パスはIssue番号から固定形式で組み立てる。
- Secretsを参照しない。Codex認証は次段階で追加する。
