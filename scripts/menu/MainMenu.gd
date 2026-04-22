extends Control

const GAME_SCENE_PATH: String = "res://scenes/main/Game.tscn"
const JOB_SELECT_PATH: String = "res://scenes/menu/JobSelect.tscn"

@onready var _continue_btn: Button = $VBox/ContinueButton
@onready var _start_btn: Button = $VBox/StartButton
@onready var _display_btn: Button = $VBox/DisplayButton
@onready var _shards_btn: Button = $VBox/ShardsButton
@onready var _help_btn: Button = $VBox/HelpButton

func _ready() -> void:
	theme = GameTheme.create()
	if _continue_btn != null:
		_continue_btn.pressed.connect(_on_continue)
		_continue_btn.visible = SaveManager.has_save()
	_start_btn.pressed.connect(_on_start)
	_display_btn.pressed.connect(_on_toggle_display)
	_shards_btn.pressed.connect(_on_shards)
	if _help_btn != null:
		_help_btn.pressed.connect(_on_help)
	_refresh_display_label()

func _on_continue() -> void:
	if GameManager.load_run():
		get_tree().change_scene_to_file(GAME_SCENE_PATH)

func _on_start() -> void:
	get_tree().change_scene_to_file(JOB_SELECT_PATH)

func _on_toggle_display() -> void:
	GameManager.toggle_tiles()
	_refresh_display_label()

func _refresh_display_label() -> void:
	_display_btn.text = "Display: %s" % ("Tiles" if GameManager.use_tiles else "ASCII")

func _on_shards() -> void:
	var dlg: GameDialog = GameDialog.create("룬샤드")
	add_child(dlg)
	var lab := Label.new()
	lab.text = "보유: %d\n\n던전을 돌파하고 쌓으세요.\n(메타 업그레이드는 다음 업데이트)" \
			% GameManager.rune_shards
	lab.add_theme_font_size_override("font_size", 36)
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dlg.body().add_child(lab)

func _on_help() -> void:
	var dlg: GameDialog = GameDialog.create("How to Play")
	add_child(dlg)
	var body: VBoxContainer = dlg.body()
	for line in _help_lines():
		var lab := Label.new()
		lab.text = line
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.add_theme_font_size_override("font_size", 22)
		body.add_child(lab)

func _help_lines() -> Array:
	return [
		"이동: 화살표 / WASD / HJKL",
		"공격: 이동 방향에 적이 있으면 자동 공격",
		"계단: '>' 밟으면 다음 층으로",
		"",
		"BAG: 인벤토리 — 장착 / 사용 / 버리기",
		"MAGIC: 주문 시전 (마법사만)",
		"SKILLS: 스킬 레벨 확인",
		"STATUS: HP, 스탯, 장비 요약",
		"WAIT: 한 턴 넘기기 (+1 HP/MP 재생)",
		"REST: 적 없을 때 HP 찰 때까지 자동 대기",
		"MENU: 저장 후 메인 메뉴로",
		"",
		"Display 토글로 타일/ASCII 전환",
		"런에 실패하면 룬샤드 획득 (추후 업그레이드 연동)",
		"",
		"타일 모드 ASCII 범례:",
		"@ 나  # 벽  . 바닥  < > 계단  + 닫힌문",
		"r 쥐  b 박쥐  K 코볼드  g 고블린  o 오크 ...",
		"( 무기  [ 방어구  ! 포션  ? 주문서  $ 금화",
	]
