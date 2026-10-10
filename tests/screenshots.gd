extends SceneTree
## 给画面拍照 (检查画得对不对用, 不是测试)。会开一下游戏窗口, 摆出几种场面, 存成图片, 然后自己关掉。
## 运行方法: Godot --path . -s tests/screenshots.gd -- 存图片的文件夹
## 只拍说话的画面: Godot --path . -s tests/screenshots.gd -- 存图片的文件夹 说话

var out := ""
var only_talk := false
var main: Control


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if not args.is_empty() else OS.get_user_data_dir()
	only_talk = args.size() > 1 and args[1] == "说话"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run()


func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("拍好: ", name)


func wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _run() -> void:
	await process_frame
	var sv: SetupView = main.setup_view
	# 1. 准备画面: 鼠标指着「手雷」
	sv.mouse = sv.gear_buttons()[["hand", 1, "grenade"]].get_center()
	await shot("g1_setup")
	await _talk_shots()
	if only_talk:
		quit()
		return
	# 2. 开打, 鼠标指着一块空地
	main._on_start()
	var arena: ArenaView = main.arena
	arena.new_battle()
	var b := arena.battle
	var you: Unit = b.units[0]
	var knife: Unit = b.units[1]
	var gunner: Unit = b.units[2]
	arena.mouse = ArenaView.tile_center(Vector2(6, 8))
	await shot("g2_path")
	# 3. 指着持枪强盗
	arena.mouse = arena.unit_screen_pos(gunner) + Vector2(0, -25)
	await shot("g3_tooltip")
	arena.mouse = ArenaView.WEAPON_SLOT.get_center()
	await shot("g3b_panel_tip")
	# 4. 开一枪, 拍动画中间
	b.dice = Dice.new(3)
	b.attack(you, gunner)
	await wait(0.08)
	await shot("g4_shot")
	await wait(1.0)
	# 5. 瞄准窗口
	arena.open_aim(gunner)
	arena.mouse = arena.aim_buttons()["left_leg"].get_center()
	await shot("g5_aim")
	arena.aim_target = null
	# 6. 受了伤的场面
	gunner.crippled["right_arm"] = true
	var item := b._drop(gunner, 0)
	knife.knocked_down = true
	knife.pos = Vector2i(5, 9)
	you.crippled["left_leg"] = true
	you.blind = true
	b.take_events()
	arena.mouse = ArenaView.tile_center(Vector2(item.pos))
	await wait(0.2)
	await shot("g6_hurt")
	# 7. 冲锋枪连发
	arena.new_battle()
	b = arena.battle
	you = b.units[0]
	gunner = b.units[2]
	knife = b.units[1]
	knife.pos = Vector2i(10, 5)
	you.hands[0] = "smg"
	you.loaded[0] = 20
	you.spare = {"smg": 20}
	you.burst[0] = true
	arena.mouse = arena.unit_screen_pos(gunner) + Vector2(0, -25)
	await shot("g7_burst_tip")
	b.attack(you, gunner)
	await wait(0.12)
	await shot("g8_burst")
	await wait(1.2)
	# 8. 手雷
	you.hands[1] = "grenade"
	you.loaded[1] = 3
	b.switch_hand(you)
	b.end_turn()
	while not arena.players_turn() and b.result == "":
		await wait(0.1)
	knife = b.units[1]
	if knife.alive():
		arena.mouse = arena.unit_screen_pos(knife) + Vector2(0, -25)
		await shot("g9_grenade_aim")
		b.attack(you, knife)
		await wait(0.75)
		await shot("g10_boom")
	await wait(1.5)
	# 9. 打完
	for u in b.units:
		if u.side == Unit.ENEMY:
			u.hp = 0
	b._check_end()
	await wait(0.6)
	arena.mouse = ArenaView.END_SETUP.get_center()
	await shot("g11_end")
	quit()


## 说话的画面 (练习场教官)
func _talk_shots() -> void:
	var sv: SetupView = main.setup_view
	sv.mouse = SetupView.TALK_BTN.get_center()
	await shot("t1_setup_talk_button")
	# 默认的准备 (学识 2): 鼠标指着第二个回答
	main._on_talk()
	var dv: DialogueView = main.dialogue_view
	dv.mouse = Vector2(DialogueView.OPT_BOX.position.x + 120, dv.opt_top() + DialogueView.OPT_LINE * 1.5)
	await wait(0.25)
	await shot("t2_talk")
	# 学识、意志高的人: 能看到带「[学识 6]」的回答
	var saved: Dictionary = main.setup.stats.duplicate()
	main.setup.stats.merge({"intellect": 6, "resolve": 7}, true)
	main._on_talk()
	dv.mouse = Vector2(600, 300)
	await wait(0.1)
	await shot("t3_smart")
	dv.press_key(KEY_3)  # 要钱
	dv.mouse = DialogueView.REVIEW_BTN.get_center()
	await wait(0.4)
	await shot("t4_money")
	dv.press_key(KEY_1)
	dv.press_key(KEY_2)  # 问命中几率
	dv.open_review()
	dv.mouse = DialogueView.REVIEW_UP.get_center()
	await shot("t5_review")
	dv.reviewing = false
	dv.mouse = DialogueView.BARTER_AT
	dv.click(DialogueView.BARTER_AT)
	await shot("t6_barter")
	main.setup.stats.merge(saved, true)
	dv.choose(dv.talk.options().size() - 1)  # 「知道了」: 回到准备画面
	await wait(0.1)
