extends TestCase
## 画面的测试: 不开窗口, 直接把鼠标键盘的事件交给画面, 看点了有没有反应、会不会出错。
## 画得对不对要看截图 (screenshots.gd), 这里只管操作。

var arena: ArenaView
var quit_asked := false
var setup_asked := false


func before_each() -> void:
	arena = ArenaView.new(null, 5)
	arena.quit_requested.connect(func(): quit_asked = true)
	arena.setup_requested.connect(func(): setup_asked = true)


func after_each() -> void:
	arena.free()  # 画面是 Godot 的节点, 不用了要自己释放


func frames(n := 1, dt := 1.0 / 30) -> void:
	for i in n:
		arena.step(dt)


func click(p: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	var ev := InputEventMouseButton.new()
	ev.position = p
	ev.button_index = button
	ev.pressed = true
	arena._gui_input(ev)


func hover(p: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = p
	arena._gui_input(ev)


func enemy_pos(u: Unit) -> Vector2:
	return arena.unit_screen_pos(u) + Vector2(0, -25)


func test_tile_math_round_trip() -> void:
	for t in [Vector2i(0, 0), Vector2i(3, 10), Vector2i(13, 13), Vector2i(7, 2)]:
		eq(ArenaView.screen_to_tile(ArenaView.tile_center(Vector2(t))), t)


func test_click_tile_walks_there() -> void:
	var you: Unit = arena.battle.units[0]
	click(ArenaView.tile_center(Vector2(5, 9)))
	eq(you.pos, Vector2i(5, 9))
	check(arena.busy(), "在播走路动画")
	frames(30)
	check(not arena.busy())


func test_too_far_shows_hint() -> void:
	var you: Unit = arena.battle.units[0]
	click(ArenaView.tile_center(Vector2(13, 0)))
	eq(you.pos, Vector2i(3, 10))
	has_text(arena.hint, "行动点不够")


func test_click_enemy_attacks() -> void:
	var b := arena.battle
	var gunner: Unit = b.units[2]
	hover(enemy_pos(gunner))
	check(arena.unit_under(enemy_pos(gunner)) == gunner)
	click(enemy_pos(gunner))
	eq(b.units[0].ammo_in_hand(), 7)
	has_text(b.messages[-1][0], "命中")
	frames(30)


func test_keys_and_buttons() -> void:
	var b := arena.battle
	var you: Unit = b.units[0]
	arena.press_key(KEY_Q)
	eq(you.weapon().name, "小刀")
	frames()
	click(ArenaView.SWITCH_AT)  # 红圆按钮: 换手
	eq(you.weapon().name, "手枪")
	frames()
	arena.press_key(KEY_R)
	eq(arena.hint, "子弹是满的")
	arena.press_key(KEY_SPACE)
	check(b.current() != you)


func test_whole_battles_with_screen() -> void:
	# 玩家每回合都直接结束 (或者电脑替他打), 一直打到底, 再按回车重来
	for game in 3:
		var b := arena.battle
		for i in 3000:
			if b.result != "":
				break
			if arena.players_turn():
				if game == 0 or not AI.act(b, b.current()):
					arena.press_key(KEY_SPACE)
			frames(1, 0.1)
		check(b.result != "", "第 %d 局打不完" % game)
		frames(40, 0.1)
		arena.press_key(KEY_ENTER)
		check(arena.battle != b, "按回车应该开新的一局")


func test_right_click_aim_and_shoot_part() -> void:
	var b := arena.battle
	var you: Unit = b.units[0]
	var gunner: Unit = b.units[2]
	click(enemy_pos(gunner), MOUSE_BUTTON_RIGHT)
	check(arena.aim_target == gunner)
	var rect: Rect2 = arena.aim_buttons()["left_leg"]
	hover(rect.get_center())
	click(rect.get_center())
	check(arena.aim_target == null)
	eq(you.ap, 8 - 5)
	check(b.messages.any(func(m): return String(m[0]).contains("持枪强盗的左腿")))


func test_click_on_figure_part() -> void:
	var b := arena.battle
	arena.open_aim(b.units[2])
	var torso: Rect2 = UIKit.figure_parts(ArenaView.AIM_WIN.get_center().x, ArenaView.AIM_FIGURE_TOP)["torso"]
	eq(arena.aim_part_under(torso.get_center()), "torso")
	click(torso.get_center())
	check(b.messages.any(func(m): return String(m[0]).contains("持枪强盗的身上")))


func test_aim_mode_and_escape() -> void:
	var b := arena.battle
	var gunner: Unit = b.units[2]
	arena.press_key(KEY_A)
	check(arena.aiming)
	eq(arena.attack_mode(), "瞄准")
	click(enemy_pos(gunner))
	check(arena.aim_target == gunner)
	eq(b.units[0].ap, 8, "还没打")
	arena.press_key(KEY_ESCAPE)  # Esc 先关瞄准窗口, 不退出, 也还在瞄准模式
	check(arena.aim_target == null)
	check(arena.aiming)
	check(not quit_asked)
	arena.press_key(KEY_ESCAPE)  # 再按一次: 关掉瞄准模式
	check(not arena.aiming)
	click(ArenaView.WEAPON_SLOT.get_center())  # 点武器格子: 单发 → 瞄准
	check(arena.aiming)
	click(Vector2(5, 300), MOUSE_BUTTON_RIGHT)  # 右键取消瞄准
	check(not arena.aiming)
	arena.press_key(KEY_ESCAPE)
	check(quit_asked, "没在瞄准时 Esc 就是退出")


func test_aim_mode_stays_after_aimed_shot() -> void:
	# 跟原版一样: 换成瞄准以后一直是瞄准, 打完一下还是
	var b := arena.battle
	var gunner: Unit = b.units[2]
	arena.press_key(KEY_A)
	click(enemy_pos(gunner))
	click(arena.aim_buttons()["torso"].get_center())
	check(arena.aim_target == null)
	check(arena.aiming)
	eq(b.units[0].ap, 8 - 5)


func test_placeholder_buttons() -> void:
	click(ArenaView.INV_BTN.get_center())
	eq(arena.hint, "背包: 以后才有")
	click(ArenaView.PAP_BTN.get_center())
	has_text(arena.hint, "PAP (个人分析与防护)")
	click(ArenaView.PERK_AT)
	eq(arena.hint, "特长: 以后才有")
	click(ArenaView.OPT_AT)
	eq(arena.hint, "设置: 以后才有")
	click(ArenaView.END_COMBAT_BTN.get_center())
	eq(arena.hint, "敌人还在, 不能结束战斗")
	var you: Unit = arena.battle.units[0]
	click(ArenaView.END_TURN_BTN.get_center())
	check(arena.battle.current() != you, "结束回合")


func test_ammo_bar_reloads() -> void:
	var you: Unit = arena.battle.units[0]
	you.loaded[0] = 3
	click(ArenaView.AMMO_BAR.get_center())
	eq(you.ammo_in_hand(), 8)
	eq(you.ap, 8 - 2)


func test_grenade_has_one_mode() -> void:
	var you: Unit = arena.battle.units[0]
	you.hands[0] = "grenade"
	you.loaded[0] = 3
	click(ArenaView.WEAPON_SLOT.get_center())
	eq(arena.attack_mode(), "单发")
	has_text(arena.hint, "只有一种打法")


func test_pickup_by_clicking() -> void:
	var b := arena.battle
	var you: Unit = b.units[0]
	var gunner: Unit = b.units[2]
	gunner.crippled["right_arm"] = true
	var item := b._drop(gunner, 0)
	b.take_events()
	item.pos = Vector2i(4, 10)  # 放到你旁边
	you.hands[1] = ""  # 左手空出来
	click(ArenaView.tile_center(Vector2(item.pos)))
	eq(you.hands, ["pistol", "pistol"])
	eq(you.ap, 8 - 2)


func test_burst_mode() -> void:
	var b := arena.battle
	var you: Unit = b.units[0]
	var gunner: Unit = b.units[2]
	you.hands[0] = "smg"
	you.loaded[0] = 20
	click(ArenaView.WEAPON_SLOT.get_center())  # 点武器格子: 单发 → 瞄准
	eq(arena.attack_mode(), "瞄准")
	frames()
	click(ArenaView.WEAPON_SLOT.get_center())  # 再点: 瞄准 → 连发
	check(you.burst[0])
	eq(arena.attack_mode(), "连发")
	frames()
	click(enemy_pos(gunner), MOUSE_BUTTON_RIGHT)  # 连发不能瞄准
	check(arena.aim_target == null)
	has_text(arena.hint, "连发不能瞄准")
	click(enemy_pos(gunner))
	eq(you.ammo_in_hand(), 10)
	eq(you.ap, 8 - 6)
	frames(30)
	arena.press_key(KEY_F)  # F 换回单发
	check(not you.burst[0])


func test_grenade_throw() -> void:
	var b := arena.battle
	var you: Unit = b.units[0]
	var gunner: Unit = b.units[2]
	you.hands[0] = "grenade"
	you.loaded[0] = 3
	you.pos = Vector2i(8, 6)
	click(enemy_pos(gunner))
	eq(you.ammo_in_hand(), 2)
	check(b.messages.any(func(m): return String(m[0]).contains("扔出手雷")))
	frames(40)


func test_end_buttons() -> void:
	var b := arena.battle
	for u in b.units.slice(1):
		u.hp = 0
	b._check_end()
	frames(5)
	click(ArenaView.END_SETUP.get_center())
	check(setup_asked)


func test_fall_shows_after_the_shot() -> void:
	# 挨打的人等子弹动画播完才倒下 (以前子弹还没飞到就先倒了)
	var b := arena.battle
	var you: Unit = b.units[0]
	var gunner: Unit = b.units[2]
	gunner.hp = 1
	b.dice = TestCase.FixedDice.new([1, 100, 9])
	click(enemy_pos(gunner))
	check(not gunner.alive())
	frames(1, 0.05)
	eq(arena.shown[gunner][0], true, "动画还在播: 画面上还站着")
	frames(20, 0.05)
	eq(arena.shown[gunner][0], false, "播完了: 倒下")


func test_aim_window_reasons() -> void:
	var b := arena.battle
	var you: Unit = b.units[0]
	var gunner: Unit = b.units[2]
	you.ap = 4
	arena.open_aim(gunner)
	eq(b.attack_problem(you, gunner, "head"), "行动点不够 (要 5 点)")
	eq(ArenaView.short_reason("行动点不够 (要 5 点)"), "点数不够")
	eq(ArenaView.short_reason("要走到旁边才能打"), "要走过去")


# ---------- 准备画面 ----------

func setup_click(sv: SetupView, p: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.position = p
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	sv._gui_input(ev)


func test_setup_points_and_limits() -> void:
	var sv := SetupView.new()
	var started := [false]
	sv.start_requested.connect(func(): started[0] = true)
	var s := sv.setup
	eq(s.points_left(), 0)
	var plus: Rect2 = sv.stat_buttons()[["agility", 1]]
	setup_click(sv, plus.get_center())
	eq(s.stats["agility"], 6, "点数分完了, 加不上去")
	has_text(sv.hint, "分完了")
	setup_click(sv, sv.stat_buttons()[["survival", -1]].get_center())
	eq(s.points_left(), 1)
	sv.press_enter()
	check(not started[0], "还有 1 点没分, 不能开打")
	has_text(sv.hint, "没分完")
	setup_click(sv, plus.get_center())
	eq(s.stats["agility"], 7)
	for i in 3:
		setup_click(sv, sv.stat_buttons()[["intellect", -1]].get_center())
	eq(s.stats["intellect"], 1, "最低 1 分")
	setup_click(sv, SetupView.START_BTN.get_center())
	check(not started[0])
	setup_click(sv, sv.stat_buttons()[["resolve", 1]].get_center())
	setup_click(sv, SetupView.START_BTN.get_center())
	check(started[0])
	sv.free()


func test_setup_choose_gear_and_reset() -> void:
	var sv := SetupView.new()
	setup_click(sv, sv.gear_buttons()[["hand", 0, "smg"]].get_center())
	setup_click(sv, sv.gear_buttons()[["hand", 1, "grenade"]].get_center())
	setup_click(sv, sv.gear_buttons()[["armor", "metal"]].get_center())
	var you := sv.setup.make_player()
	eq(you.hands, ["smg", "grenade"])
	eq(you.loaded, [20, 3])
	eq(you.armor.name, "金属甲")
	setup_click(sv, SetupView.RESET_BTN.get_center())
	eq(sv.setup.hands, ["pistol", "knife"])
	sv.free()


func test_setup_help_texts() -> void:
	var sv := SetupView.new()
	for rect in sv.gear_buttons().values() + sv.stat_rows().values():
		sv.mouse = rect.get_center()
		check(sv.hovered_help() != "" and not sv.hovered_help().begins_with("鼠标指着"))
	sv.free()
