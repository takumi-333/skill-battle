# リザルト画面の改修

記載する要素
- 試合時間 xx:xx
    - 画面左上に小さく
- テキスト：「RESULT」
    - 画面上部中央
- 画面中央エリア内（上1/4空け、下1/3くらい空けたエリア）
    - 勝者のキャラクターの立ち絵
        - 画面左2/3くらい
        - 上部にそのユーザの名前
        - その上に王冠UI
            - assets\ui\badge_victory.png
    - 敗者のキャラクターの立ち絵
        - 画面右1/3
        - 上部にそのユーザの名前
        - このエリアは少し暗くする（グラデーション）
- 画面下部は試合結果詳細
    - お互いの残りHP
    - スキルの平均点数
- 画面最下部
    - 再戦ボタン
    - ロビーへ戻るボタン

## 完成イメージ画像
docs\ideas\result_screen_concept_issue-24.png
これを完成形とする

## 作成済みUI素材

以下の素材をリザルト画面専用の `assets/ui/result/` に配置した。画像は本issueの完成イメージに合わせて作成済みであり、リザルト画面実装時は各用途に使用する。

| 素材 | 用途 | パス |
| --- | --- | --- |
| RESULTロゴ | 画面上部中央に表示するRESULTのロゴ | `assets/ui/result/result_logo.png` |
| 試合時間表示枠 | 画面左上の試合時間テキストを囲む枠 | `assets/ui/result/match_time_frame.png` |
| 結果詳細表示枠 | HPと平均スキル点を左右のプレイヤーごとに表示する、中央区切り線付きの枠 | `assets/ui/result/result_stats_panel.png` |
| HPアイコン | 残りHPの表示に使用するハートアイコン | `assets/ui/result/icon_hp.png` |
| 平均スキル点アイコン | 平均スキル点の表示に使用する星アイコン | `assets/ui/result/icon_average_skill_score.png` |
| 王冠 | 勝者のユーザー名の上に表示する王冠UI | `assets/ui/badge_victory.png` |
| 再戦ボタン枠 | 画面最下部の再戦ボタンに使用する枠 | `assets/ui/button_primary.png` |
| ロビーへ戻るボタン枠 | 画面最下部のロビーへ戻るボタンに使用する枠 | `assets/ui/button_secondary.png` |
