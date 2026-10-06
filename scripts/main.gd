extends Control
## 游戏一打开: 先是「准备」画面, 按「开打」进练习场; 打完可以「重新准备」。Esc 退出。

var setup := Practice.Setup.new()
var setup_view: SetupView
var arena: ArenaView


func _ready() -> void:
	setup_view = SetupView.new(setup)
	setup_view.start_requested.connect(_on_start)
	add_child(setup_view)


func _on_start() -> void:
	if arena == null:
		arena = ArenaView.new(setup)
		arena.setup_requested.connect(_on_back_to_setup)
		arena.quit_requested.connect(func(): get_tree().quit())
		add_child(arena)
	else:
		arena.new_battle()
	setup_view.visible = false
	arena.visible = true


func _on_back_to_setup() -> void:
	arena.visible = false
	setup_view.hint = ""
	setup_view.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if setup_view.visible:
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			setup_view.press_enter()
	elif arena != null and arena.visible:
		arena.press_key(event.keycode)
