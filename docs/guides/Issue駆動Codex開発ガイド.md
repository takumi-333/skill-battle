# Issue駆動Codex開発ガイド

## 目的

本ガイドは、GitHub Issueを起点にCodexが実装用のPull Request（PR）を作り、開発者がレビューとマージに集中するための運用を定める。

ゲームの機能仕様は `docs/specs/` を正とする。本書は、依頼の受け付け、実装、検証、レビューの開発運用を扱う。

## 方針

- **GitHub Issueを依頼内容の正本**とする。スマホを含む任意の端末からここへ起票・追記する。
- `docs/issues/issue-<番号>.md` は、GitHub Issueから自動生成・同期する**実装用コピー**とする。人が直接編集して正本にしない。
- Codexは、`ready-for-agent` ラベルが付いたIssueだけを実装対象にする。
- Codexの成果物は必ず専用ブランチのPRとする。デフォルトブランチへの直接push・直接マージは行わない。
- 開発者の責務は、Issueの受入条件を決めること、PRをレビューすること、マージを判断することとする。

この方針により、外出先ではGitHubアプリからIssueを書くだけでよく、ローカルのSteering運用とも両立する。

## 全体フロー

```text
Issueを起票・編集
  ↓
ready-for-agent を付与
  ↓
自動処理: Issueを docs/issues/ に同期し、Codex実装を開始
  ↓
Codex: Steering作成 → 実装 → Godot確認 → PR作成
  ↓
needs-review を付与してPRで結果を報告
  ↓
レビュー・マージ
  ↓
Issueを完了、実装用コピーを docs/issues/archives/ へ保存
```

## Issueの状態とラベル

| ラベル | 意味 | 次の担当 |
| --- | --- | --- |
| `draft` | 起票途中。自動実装しない | 開発者 |
| `needs-info` | 受入条件またはスコープが不足している | 開発者 |
| `ready-for-agent` | 実装開始を許可する | 自動処理 / Codex |
| `in-progress` | Codexが作業中 | Codex |
| `blocked` | 外部情報・判断待ちで停止中 | 開発者 |
| `needs-review` | PRが作られ、レビュー待ち | 開発者 |
| `done` | マージ済み・完了 | 自動処理 |

`ready-for-agent`、`in-progress`、`needs-review`、`blocked` は同時に一つだけ付ける。優先度は `priority:high` / `priority:normal` / `priority:low`、規模は `size:S` / `size:M` / `size:L` を別途付ける。

`size:L`、複数の仕様書を変更する案件、または破壊的変更を含む案件は、実装前にCodexが設計・質問だけをPRまたはIssueコメントで提示し、開発者が改めて `ready-for-agent` を付ける。

## Issueに必ず書くこと

Issue Formで次の項目を必須にする。

1. **目的・背景**: なぜ必要か。
2. **受入条件**: 完了と判定できる、確認可能な条件。
3. **変更範囲**: 変更してよい画面・機能・ファイルの範囲。
4. **変更しないこと**: 既存挙動や仕様で守る点。
5. **確認方法**: テスト、Godotでの操作、確認したい画面など。
6. **関連資料**: `docs/specs/`、画像、関連Issue、参考リンク。

受入条件が曖昧な場合、Codexは推測して実装を開始せず `needs-info` を付けて質問する。アイデア段階の内容は `docs/ideas/` に置き、実装を許可するIssueには確定した仕様へのリンクを記載する。

## Codexの実装契約

Codexは対象Issueごとに、次を守る。

1. 同期済みの `docs/issues/issue-<番号>.md` を依頼元にして、既存のSteeringルールに従う。
2. `docs/.steering/YYYYMMDD-issue-<番号>-<短い名前>/` を作り、`request.md`、`requirements.md`、`design.md`、`tasklist.md` を管理する。
3. `tasklist.md` を進捗に合わせて更新する。
4. 可能な限りGodotを実行してログを確認し、実行できない場合はPRへ理由を明記する。
5. PRには、変更概要、受入条件ごとの検証結果、未解決事項、実行したテストを記載する。
6. 実装完了後は `needs-review` に移し、レビューされるまでIssueを `done` にしない。

## 自動化の境界

自動化は以下までを担当する。

- `ready-for-agent` 付与時に、Issue本文を `docs/issues/issue-<番号>.md` へ同期する。
- Issue番号を含む専用ブランチを作り、Codexへ実装を依頼する。
- Codexの作業結果からPRを作成し、Issueと相互リンクする。
- PRがマージされたらIssueを閉じ、同期ファイルを `docs/issues/archives/` へ移す。

以下は自動化しない。

- 仕様が未確定なIssueの実装開始
- デフォルトブランチへの直接push、直接マージ
- 本番公開、課金、外部サービス設定の変更
- 秘密情報の表示・コミット
- `size:L` または破壊的変更の実装開始

## 実行環境

Godotの実行確認を自動化するため、Codex実行環境にはプロジェクトで使うGodotのバージョン、必要なexportテンプレート、Git、テストに必要な依存物を事前に導入する。

最初は、Godotを導入した専用のself-hosted runnerを1台用意し、同時実行数を **2件まで** に制限する。各ジョブは別worktreeまたはクリーンな作業ディレクトリで実行し、`.godot/` や生成物を共有しない。安定後に並列数を増やす。

GitHubのトークンやCodex用の認証情報はGitHub Secretsまたは実行基盤のシークレットストアにだけ保存し、Issue本文、ログ、PR本文へ出力しない。

## 導入手順

導入は次の順序で行う。

1. リポジトリをGitHubへ接続し、デフォルトブランチの直接pushを禁止するブランチ保護を設定する。
2. Issue Formと上記ラベルを作成する。
3. Issue本文を `docs/issues/` に同期するワークフローを作る。
4. Godot実行環境を備えたself-hosted runnerを用意し、空のIssueで同期・Godot起動・PR作成を検証する。
5. `ready-for-agent` をトリガーにCodexを起動するワークフローを追加する。
6. 実際の `size:S` Issueを1件だけ流し、レビュー結果を反映する。
7. 問題なく完走できた後に、並列実行と `size:M` の自動実装を有効化する。

## 第1段階の初期設定

リポジトリへ `.github/` 配下の設定をマージした後、次を一度だけ行う。

1. GitHub CLIへログインする。
2. リポジトリ直下で `./scripts/setup-github-labels.ps1` を実行し、ラベルを作成または更新する。
3. GitHubのActions設定で、ワークフローにPR作成を許可する。
4. 「開発依頼」Issueを1件起票し、内容を確認して `ready-for-agent` を付ける。
5. 作られた同期PRをレビュー・マージし、`docs/issues/issue-<番号>.md` が作成されることを確認する。

この段階のワークフローはIssueを実装用コピーへ同期するだけで、Codexを起動しない。同期PRのマージ後、次段階のCodex実行ワークフローを導入する。

## 移行ルール

- 既存の `docs/issues/` の未解決ファイルは削除しない。対応するGitHub Issueを起票して番号・リンクを記録した後、同期運用へ切り替える。
- アーカイブ済みIssueは履歴としてそのまま保持し、GitHubへ移行しない。
- GitHub Issueの同期が開始された後、新規依頼を `docs/issues/` に直接追加しない。

## 完了の定義

この運用の導入完了は、スマホから作成した `size:S` のIssueに `ready-for-agent` を付けた後、追加の手動指示なしでCodexがPRを作成し、Godot確認結果を添えてレビュー待ちへ移せる状態とする。
