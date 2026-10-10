extends SceneTree
## 给画面拍照 (检查画得对不对用, 不是测试)。会开一下游戏窗口, 摆出几种场面, 存成图片, 然后自己关掉。
## 运行方法: Godot --path . -s tests/screenshots.gd -- 存图片的文件夹
## 只拍说话的画面: Godot --path . -s tests/screenshots.gd -- 存图片的文件夹 说话 (只拍背包: 最后写「背包」; 只拍压力槽: 「压力」)

var out := ""
var only := ""  # 「说话」「背包」或「压力」: 只拍这一种
var main: Control


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if not args.is_empty() else OS.get_user_data_dir()
	only = args[1] if args.size() > 1 else ""
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
	if only == "压力":
		await _stress_shots()
		quit()
		return
	var sv: SetupView = main.setup_view
	# 1. 准备画面: 鼠标指着右手拿的东西
	sv.mouse = SetupView.KIT_SLOTS["hand0"].get_center()
	await shot("g1_setup")
	if only != "背包":
		await _talk_shots()
	if only != "说话":
		await _pack_shots()
	if only != "":
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


## 压力槽: 下面面板上的一条、指着的说明、敌人的压力、大失败和换段时人头上飘的字
func _stress_shots() -> void:
	main._on_start()
	var arena: ArenaView = main.arena
	arena.new_battle()
	var b := arena.battle
	var you: Unit = b.units[0]
	var knife: Unit = b.units[1]
	var gunner: Unit = b.units[2]
	await wait(0.1)
	# 1. 开打: 冷静, 指着压力槽
	arena.mouse = ArenaView.STRESS_BOX.get_center()
	await shot("s1_calm_tip")
	# 2. 紧张; 指着持枪强盗 (他也有压力)
	you.stress = 52
	gunner.stress = 78
	arena.mouse = arena.unit_screen_pos(gunner) + Vector2(0, -25)
	await shot("s2_enemy_tip")
	# 3. 慌乱, 枪卡住了; 指着压力槽
	you.stress = 86
	you.jammed[0] = true
	arena.mouse = ArenaView.STRESS_BOX.get_center()
	await shot("s3_panic_tip")
	# 4. 慌乱时打歪了, 打中自己
	you.jammed[0] = false
	you.ap = 10
	b.dice = TestCase.FixedDice.new([1, 3, 1, 9])
	b.attack(you, gunner)
	arena.mouse = Vector2(600, 300)
	await wait(0.2)
	await shot("s4_fumble")
	await wait(1.2)
	# 5. 打中小刀强盗, 他慌了 (头上飘「慌了!」)
	you.stress = 40
	knife.stress = 60
	knife.pos = Vector2i(6, 8)
	b.dice = TestCase.FixedDice.new([1, 100, 9])
	b.attack(you, knife)
	await wait(0.62)
	await shot("s5_mood")
	await wait(1.2)
	# 6. 冷静时的瞄准窗口
	you.stress = 12
	you.ap = 10
	arena.open_aim(gunner)
	arena.mouse = arena.aim_buttons()["head"].get_center()
	await shot("s6_aim_calm")
	arena.aim_target = null
	# 7. 战斗里打开背包: 绿屏幕上写着压力
	arena.do_button("inv")
	arena.pack_view.mouse = Vector2(80, 300)
	await shot("s7_pack")
	arena.pack_view.close()


## 背包、武器架的画面
func _pack_shots() -> void:
	var sv: SetupView = main.setup_view
	sv.open_rack()
	var rv := sv.rack_view
	await wait(0.1)
	rv.mouse = rv.slot_rect(LootView.RACK.x, LootView.RACK.y, 4).get_center()
	await shot("p1_rack")
	# 拖着冲锋枪往背包里放
	rv.press(rv.slot_rect(LootView.RACK.x, LootView.RACK.y, 5).get_center())
	rv.mouse = rv.slot_rect(LootView.MINE.x, LootView.MINE.y, 1).get_center() + Vector2(10, 6)
	await shot("p2_rack_drag")
	rv.release(rv.mouse)
	rv.release(rv.mouse)
	rv.press(rv.slot_rect(LootView.RACK.x, LootView.RACK.y, 4).get_center())  # 步枪
	rv.release(rv.slot_rect(LootView.MINE.x, LootView.MINE.y, 0).get_center())
	rv.scroll_rack = 6  # 往下翻: 手雷、子弹、护甲
	for i in [0, 0, 2, 5]:  # 两个手雷、一盒步枪子弹、金属甲
		rv.press(rv.slot_rect(LootView.RACK.x, LootView.RACK.y, i).get_center())
		rv.release(rv.slot_rect(LootView.MINE.x, LootView.MINE.y, 0).get_center())
	rv.close()
	sv.open_pack()
	var pv := sv.pack_view
	await wait(0.1)
	pv.mouse = Vector2(1100, 600)
	await shot("p3_pack")
	pv.mouse = pv.slot_rect(InventoryView.LIST.x, InventoryView.LIST.y, 0).get_center()
	await shot("p4_pack_hover")
	pv.press(pv.slot_rect(InventoryView.LIST.x, InventoryView.LIST.y, 1).get_center())
	pv.mouse = pv.hand_rect(0).get_center() + Vector2(12, 8)
	await shot("p5_pack_drag")
	pv.release(pv.mouse)
	pv.close()
	sv.mouse = SetupView.PACK_BTN.get_center()
	await shot("p6_setup_kit")
	# 战斗里打开背包
	main._on_start()
	var arena: ArenaView = main.arena
	arena.new_battle()
	await wait(0.1)
	arena.do_button("inv")
	arena.pack_view.mouse = Vector2(80, 300)
	await shot("p7_battle_pack")
	arena.pack_view.close()
	main.setup.reset()
	main._on_back_to_setup()


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
