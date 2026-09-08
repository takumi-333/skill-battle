# リザルト画面の改修

実装する要件
- 試合終了時間：xx:xx
    - 画面左上に小さく
- テキスト：RESULT
    - 画面上部中央
- 画面中央エリアを2/4程度、上/3くらいの高さのエリア
    - 勝利したキャラクターの配置
        - 画面左2/3くらい
        - 左上にそのユーザーの名前
        - その下に勝利UI
            - assets/ui/badge_victory.png
    - 敗北したキャラクターの配置
        - 画面右1/3
        - 左上にそのユーザーの名前
        - このエリアは少し暗くする（グラデーション？）
- 画面左下は試合結果詳細
    - 残りのHP
    - スキルの平均スコア
- 画面最下部
    - 再戦ボタン
    - ロビーへ戻るボタン

## 完成イメージ画像

docs/ideas/result_screen_concept_issue-24.png
これを完成形とする

## 実装済みUI素材

以下の素材をリザルト画面実装の `assets/ui/result/` に配置した。完成イメージ画像と合わせて実装済みであり、リザルト画面実装時は積極的に利用する。
| 素材 | 用途 | パス |
| --- | --- | --- |
| RESULTロゴ | 画面上部中央に表示するRESULTのロゴ | `assets/ui/result/result_logo.png` |
| 試合終了時間表示枠 | 画面左上の試合終了時間テキストを囲む枠 | `assets/ui/result/match_time_frame.png` |
| 試合結果詳細表示枠 | HPとスキルスコアを各プレイヤーのプレイヤー情報とともに表示する、中央寄り左下の枠 | `assets/ui/result/result_stats_panel.png` |
| HPアイコン | 残りHPの表示に利用するハートアイコン | `assets/ui/result/icon_hp.png` |
| 平均スキルスコアアイコン | 平均スキルスコアの表示に利用する星アイコン | `assets/ui/result/icon_average_skill_score.png` |
| 勝利章 | 勝利したユーザー名の下に表示する勝利UI | `assets/ui/badge_victory.png` |
| 再戦ボタン枠 | 画面最下部の再戦ボタンに利用する枠 | `assets/ui/button_primary.png` |
| ロビーへ戻るボタン枠 | 画面最下部のロビーへ戻るボタンに利用する枠 | `assets/ui/button_secondary.png` |
