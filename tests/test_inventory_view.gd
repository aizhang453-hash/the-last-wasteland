extends TestCase
## 背包画面、武器架画面: 不开窗口, 直接把鼠标键盘的事件交给画面, 看拖东西有没有用。画得对不对看截图 (screenshots.gd)。


func mouse(view: Control, p: Vector2, button := MOUSE_BUTTON_LEFT, pressed := true) -> void:
	var ev := InputEventMouseButton.new()
	ev.position = p
	ev.button_index = button
	ev.pressed = pressed
	view._gui_input(ev)


## 从 a 拖到 b
func drag(view: Control, a: Vector2, b: Vector2) -> void:
	mouse(view, a)
	var ev := InputEventMouseMotion.new()
	ev.position = b
	view._gui_input(ev)
	mouse(view, b, MOUSE_BUTTON_LEFT, false)


func names(list: Array) -> Array:
	return list.map(func(it: Inventory.Item) -> String: return str(it))


# ---------- 准备画面: 武器架 ----------

func test_rack_take_and_put_back() -> void:
	var sv := SetupView.new()
	mouse(sv, SetupView.RACK_BTN.get_center())
	var rv := sv.rack_view
	check(rv != null and rv.visible, "点「武器架」打开武器架画面")
	eq(sv.overlay(), rv)
	var rifle_slot := rv.slot_rect(LootView.RACK.x, LootView.RACK.y, 4).get_center()
	var mine_slot := rv.slot_rect(LootView.MINE.x, LootView.MINE.y, 0).get_center()
	drag(rv, rifle_slot, mine_slot)
	eq(names(sv.setup.kit.pack), ["<步枪>"], "从武器架拖到背包: 拿走")
	drag(rv, rifle_slot, mine_slot)
	eq(names(sv.setup.kit.pack), ["<步枪>", "<步枪>"])
	eq(rv.rack.size(), 12, "武器架上的拿不完")
	drag(rv, mine_slot, rifle_slot)
	eq(names(sv.setup.kit.pack), ["<步枪>"], "拖回武器架: 放回去")
	drag(rv, rv.slot_rect(LootView.MINE.x, LootView.MINE.y, 1).get_center(), rifle_slot)
	eq(sv.setup.kit.spare, {}, "子弹整堆放回去")
	drag(rv, rifle_slot, rifle_slot)
	eq(sv.setup.kit.pack.size(), 1, "放回原地: 什么都不变")
	sv.press_key(KEY_ESCAPE)
	check(not rv.visible)
	eq(sv.overlay(), null)
	sv.free()


func test_rack_too_heavy() -> void:
	var sv := SetupView.new()
	sv.setup.stats["vigor"] = 1
	sv.open_rack()
	var rv := sv.rack_view
	rv.scroll_rack = 6  # 往下翻, 看到护甲
	var metal := rv.slot_rect(LootView.RACK.x, LootView.RACK.y, 5).get_center()
	eq(rv.item_at(metal).name(), "金属甲")
	drag(rv, metal, rv.slot_rect(LootView.MINE.x, LootView.MINE.y, 0).get_center())
	eq(sv.setup.kit.pack, [])
	has_text(rv.hint, "背不动了")
	sv.free()


func test_rack_scroll() -> void:
	var sv := SetupView.new()
	sv.open_rack()
	var rv := sv.rack_view
	var list := rv.slot_rect(LootView.RACK.x, LootView.RACK.y, 2).get_center()
	mouse(rv, list, MOUSE_BUTTON_WHEEL_DOWN)
	eq(rv.scroll_rack, 1)
	for i in 10:
		mouse(rv, rv.r(LootView.RACK_DOWN).get_center())
	eq(rv.scroll_rack, 12 - ItemScreen.ROWS, "翻到底就不动了")
	mouse(rv, rv.r(LootView.RACK_UP).get_center())
	eq(rv.scroll_rack, 12 - ItemScreen.ROWS - 1)
	mouse(rv, rv.r(LootView.DONE).get_center())
	check(not rv.visible, "点「完成」关掉")
	sv.free()


# ---------- 背包画面 ----------

func pack_view(sv: SetupView) -> InventoryView:
	sv.open_pack()
	return sv.pack_view


func test_pack_equip_and_wear() -> void:
	var sv := SetupView.new()
	var k := sv.setup.kit
	Inventory.add(k, Inventory.weapon("rifle"))
	Inventory.add(k, Inventory.Item.new("armor", "metal"))
	var pv := pack_view(sv)
	check(pv.visible and pv.battle == null)
	var first := pv.slot_rect(InventoryView.LIST.x, InventoryView.LIST.y, 0).get_center()
	eq(pv.item_at(first).name(), "步枪")
	drag(pv, first, pv.hand_rect(0).get_center())
	eq(k.hands, ["rifle", "knife"], "拖到右手的格子上: 拿在右手")
	eq(names(Inventory.entries(k)), ["<金属甲>", "<手枪>", "<手枪子弹 ×24>"])
	drag(pv, first, pv.r(InventoryView.ARMOR).get_center())
	eq(k.armor.id, "metal", "拖到护甲格子上: 穿上")
	drag(pv, pv.hand_rect(1).get_center(), first)
	eq(k.hands, ["rifle", ""], "手上的拖回左边: 放回背包")
	drag(pv, pv.hand_rect(0).get_center(), pv.hand_rect(1).get_center())
	eq(k.hands, ["", "rifle"], "两只手之间拖: 换一下")
	drag(pv, pv.r(InventoryView.ARMOR).get_center(), first)
	eq(k.armor.id, "none", "护甲拖回左边: 脱下来")
	sv.free()


func test_pack_problems_show_hint() -> void:
	var sv := SetupView.new()
	var pv := pack_view(sv)
	var ammo := pv.slot_rect(InventoryView.LIST.x, InventoryView.LIST.y, 0).get_center()
	drag(pv, ammo, pv.hand_rect(0).get_center())
	eq(pv.hint, "只有武器能拿在手上")
	drag(pv, pv.hand_rect(0).get_center(), pv.r(InventoryView.ARMOR).get_center())
	eq(pv.hint, "这个不能穿")
	drag(pv, pv.hand_rect(0).get_center(), Vector2(10, 10))
	has_text(pv.hint, "武器架", "不在战斗里, 不能扔到外面")
	eq(sv.setup.kit.hands, ["pistol", "knife"])
	pv.step(ItemScreen.HINT_TIME + 0.1)
	eq(pv.hint, "")
	sv.free()


func test_pack_info_and_keys() -> void:
	var sv := SetupView.new()
	var pv := pack_view(sv)
	pv.mouse = pv.hand_rect(0).get_center()
	eq(pv.item_at(pv.mouse).name(), "手枪")
	eq(pv.item_at(pv.r(InventoryView.INFO).get_center()), null)
	for key in [KEY_ESCAPE, KEY_ENTER, KEY_I]:
		sv.open_pack()
		check(sv.press_key(key))
		check(not pv.visible)
	check(not sv.press_key(KEY_ESCAPE), "都关上了, 键盘交回准备画面")
	sv.free()


func test_pack_scroll() -> void:
	var sv := SetupView.new()
	for i in 9:
		Inventory.add(sv.setup.kit, Inventory.weapon("knife"))
	var pv := pack_view(sv)
	var list := pv.slot_rect(InventoryView.LIST.x, InventoryView.LIST.y, 0).get_center()
	mouse(pv, list, MOUSE_BUTTON_WHEEL_DOWN)
	eq(pv.scroll, 1)
	mouse(pv, pv.r(InventoryView.DOWN).get_center())
	mouse(pv, pv.r(InventoryView.DOWN).get_center())
	mouse(pv, pv.r(InventoryView.DOWN).get_center())
	mouse(pv, pv.r(InventoryView.DOWN).get_center())
	eq(pv.scroll, 10 - ItemScreen.ROWS, "9 把小刀加一堆子弹")
	eq(pv.item_at(pv.slot_rect(InventoryView.LIST.x, InventoryView.LIST.y, ItemScreen.ROWS - 1).get_center()).kind, "ammo")
	sv.free()


# ---------- 战斗里 ----------

func test_battle_pack_costs_ap_and_throw_away() -> void:
	var arena := ArenaView.new(null, 5)
	var you: Unit = arena.battle.units[0]
	var ap := you.ap
	mouse(arena, ArenaView.INV_BTN.get_center())
	var pv := arena.pack_view
	check(pv != null and pv.visible, "点「背包」打开背包")
	eq(you.ap, ap - 4)
	eq(pv.battle, arena.battle)
	drag(pv, pv.hand_rect(0).get_center(), Vector2(60, 300))
	eq(you.hands, ["", "knife"], "拖到窗口外面: 扔在地上")
	eq(arena.battle.ground.size(), 1)
	eq(arena.battle.ground[0].weapon_id, "pistol")
	eq(you.ap, ap - 4, "在背包里扔东西不花点数")
	arena.press_key(KEY_SPACE)
	eq(arena.battle.current(), you, "背包开着, 空格不结束回合")
	arena.press_key(KEY_ESCAPE)
	check(not pv.visible)
	arena.press_key(KEY_I)
	check(pv.visible, "I 键也能打开")
	eq(you.ap, ap - 8)
	arena.press_key(KEY_I)
	arena.press_key(KEY_I)
	check(not pv.visible)
	has_text(arena.hint, "行动点不够 (要 4 点)")
	arena.free()


func test_battle_pack_not_your_turn() -> void:
	var arena := ArenaView.new(null, 5)
	arena.battle.end_turn()
	arena.do_button("inv")
	check(arena.pack_view == null or not arena.pack_view.visible)
	has_text(arena.hint, "轮到你")
	arena.free()


func test_ground_ammo_tooltip_and_pickup() -> void:
	var arena := ArenaView.new(null, 5)
	var b := arena.battle
	var you: Unit = b.units[0]
	var box := Battle.GroundItem.new(you.pos + Vector2i(1, 0), Inventory.Item.new("ammo", "pistol", 12))
	b.ground = [box]
	arena.mouse = ArenaView.tile_center(Vector2(box.pos))
	var lines := arena.item_tooltip()
	has_text(lines[0][0], "手枪子弹 (12 发)")
	has_text(lines[1][0], "点一下捡起来")
	mouse(arena, arena.mouse)
	eq(you.spare["pistol"], 36)
	eq(b.ground, [])
	arena.free()


func test_main_key_opens_pack() -> void:
	var main: Control = load("res://scripts/main.gd").new()
	main._ready()
	var ev := InputEventKey.new()
	ev.keycode = KEY_I
	ev.pressed = true
	main._unhandled_input(ev)
	check(main.setup_view.pack_view.visible, "准备画面按 I 打开背包")
	ev.keycode = KEY_ESCAPE
	main._unhandled_input(ev)
	check(not main.setup_view.pack_view.visible, "Esc 先关背包, 不退出游戏")
	main.free()
