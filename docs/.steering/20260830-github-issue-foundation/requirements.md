# 要求内容

## 概要

Issue駆動Codex開発ガイドの第1段階として、GitHubから起票できるIssue Formと、`ready-for-agent` を契機にIssue本文を実装用コピーへ同期するGitHub Actionsの土台を追加する。

## 背景

GitHubリポジトリが接続済みになった。スマホからGitHub Issueを作成し、既存の `docs/issues/` とSteering運用に渡せるようにする必要がある。

## 実装対象の機能

### 1. 開発依頼用Issue Form

- 目的、受入条件、変更範囲、確認方法、関連資料を記入できるフォームを追加する。
- 起票時は自動実装されない `draft` 状態にする。

### 2. Issue同期ワークフロー

- `ready-for-agent` ラベルの付与時に、Issue本文を `docs/issues/issue-<番号>.md` 形式で専用ブランチへ同期する。
- 直接pushせず、同期結果をPRとして作成する。

### 3. 運用定義

- 必要ラベルの宣言ファイルと、GitHub上で適用する手順を追加する。

## 受け入れ条件

### 開発依頼用Issue Form

- [ ] GitHubのNew issue画面から「開発依頼」を選択できる。
- [ ] ガイドで必須とした記入項目をフォームで収集できる。
- [ ] 起票されたIssueには `draft` と `priority:normal` が付く。

### Issue同期ワークフロー

- [ ] `ready-for-agent` の付与だけをトリガーに実行する。
- [ ] 同期内容にIssue番号、URL、タイトル、本文が含まれる。
- [ ] 同期結果は `main` ではなくPRでレビューできる。
- [ ] Issue本文をシェル展開せず、安全にファイルへ書き出す。

### 運用定義

- [ ] 必要ラベルの名前・色・説明がバージョン管理される。
- [ ] 初回ラベル適用の実行方法が文書化される。

## スコープ外

- Codexの実装ジョブの自動起動
- Godot用self-hosted runnerのセットアップ
- ブランチ保護やGitHub Secretsなど、GitHub設定画面で行う変更
- 既存IssueのGitHubへの移行

## 参照ドキュメント

- `docs/guides/Issue駆動Codex開発ガイド.md`
- `AGENTS.md`
