class_name MenuLayout
extends Resource

## メニュー画面の座標・サイズだけを保持する編集用リソース。
## Godotのインスペクターから変更でき、画面生成のロジックはGDScript側に残す。

@export_category("オンライン対戦画面")

@export_group("ロゴと見出し")
@export var online_logo_position := Vector2(500, 18)
@export var online_logo_size := Vector2(280, 186)
@export var online_title_position := Vector2(330, 188)
@export var online_title_size := Vector2(620, 42)

@export_group("接続パネル")
@export var online_panel_position := Vector2(235, 245)
@export var online_panel_size := Vector2(810, 340)

@export_group("接続先入力")
@export var online_address_frame_position := Vector2(350, 300)
@export var online_address_frame_size := Vector2(580, 64)
@export var online_address_input_position := Vector2(370, 313)
@export var online_address_input_size := Vector2(540, 38)

@export_group("ルーム操作")
@export var online_host_button_position := Vector2(340, 390)
@export var online_join_button_position := Vector2(650, 390)
@export var online_action_button_size := Vector2(290, 80)

@export_group("接続状態")
@export var online_status_position := Vector2(330, 495)
@export var online_status_size := Vector2(620, 30)
