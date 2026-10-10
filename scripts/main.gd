extends Control
## 游戏一打开: 先是「准备」画面, 按「开打」进练习场; 打完可以「重新准备」。
## 准备画面上可以「找教官说话」(试对话), 说完回到准备画面, 或者直接开打。Esc 退出。

const TRAINER := "res://dialogues/trainer.txt"  ## 练习场教官的对话 (试对话用的, 不是正式剧情)

var setup := Practice.Setup.new()
var memory := Dialogue.Memory.new()  ## 钱和记住的事: 说话时会看、会改, 一直留着
var setup_view: SetupView
var arena: ArenaView
var dialogue_view: DialogueView


func _ready() -> void:
	setup_view = SetupView.new(setup)
	setup_view.start_requested.connect(_on_start)
	setup_view.talk_requested.connect(_on_talk)
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


func _on_talk() -> void:
	var d := Dialogue.load_file(TRAINER)
	if not d.problems.is_empty():
		setup_view.hint = "对话文件有错: " + d.problems[0]
		return
	var talk := Dialogue.Talk.new(d, setup.stats, memory)
	if dialogue_view == null:
		dialogue_view = DialogueView.new(talk)
		dialogue_view.finished.connect(_on_talk_finished)
		add_child(dialogue_view)
	else:
		dialogue_view.begin(talk)
	setup_view.visible = false
	dialogue_view.visible = true


## 说完了: 回到准备画面; 说的是「开打」就直接开打 (点数没分完会提示)
func _on_talk_finished(how: String) -> void:
	dialogue_view.visible = false
	setup_view.hint = ""
	setup_view.visible = true
	if how == Dialogue.FIGHT:
		setup_view.start()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if setup_view.visible:
		if setup_view.press_key(event.keycode):
			return  # 背包、武器架开着
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			setup_view.press_enter()
		elif event.keycode == KEY_T:
			_on_talk()
		elif event.keycode == KEY_I:
			setup_view.open_pack()
	elif dialogue_view != null and dialogue_view.visible:
		dialogue_view.press_key(event.keycode)
	elif arena != null and arena.visible:
		arena.press_key(event.keycode)
