class_name InventoryView
extends ItemScreen
## 背包画面: 照《辐射》二代的背包摆 (看板「界面」卡片; 用户 2026-10-09 说开始做背包)。
## 位置照原版 (窗口 499×377) 放大 1.4 倍:
##   左边一列是背包里的东西 (右边两个小按钮上下翻); 中间上面是你的小人 (转来转去), 下面是护甲格子,
##   最下面左手、右手两个格子; 右边绿屏幕写能力值、生命、手上拿的、总重量, 鼠标指着东西就写这样东西的说明。
## 用鼠标拖: 拖到手的格子上就拿在手上 (原来拿的放回背包), 拖到护甲格子上就穿上, 拖回左边一列就放回背包;
## 两只手的格子之间拖, 两只手的东西换一下。战斗里 (battle 不是 null) 拖到窗口外面就扔在地上。

# 原版窗口里的坐标
const LIST := Vector2(44, 35)
const UP := [128, 39, 22, 22]
const DOWN := [128, 62, 22, 22]
const BODY := [154, 35, 90, 142]
const ARMOR := [154, 183, 90, 61]
const LEFT_HAND := [154, 286, 90, 61]    # 左手 (hands[1])
const RIGHT_HAND := [245, 286, 90, 61]   # 右手 (hands[0])
const INFO := [297, 44, 152, 188]
const DONE := [350, 300, 120, 50]

var battle: Battle = null   # 战斗里才有: 能扔到地上
var scroll := 0


## 打开背包。战斗里窗口摆在地图上面 (跟原版一样, 下面的面板还看得见); 不在战斗里摆在正中间
func open(p_unit: Unit, p_battle: Battle = null) -> void:
	battle = p_battle
	scroll = 0
	open_for(p_unit, Vector2(250, 6) if battle != null else Vector2(250, 96))


func layout() -> void:
	figure.place(r(BODY).grow(-6), 2.6)


func r(a: Array) -> Rect2:
	return at(a[0], a[1], a[2], a[3])


func hand_rect(hand: int) -> Rect2:
	return r(RIGHT_HAND) if hand == 0 else r(LEFT_HAND)


func items() -> Array:
	return Inventory.entries(unit)


## 鼠标在哪: {"where": "pack", "index": 第几样 (-2 是空格子)} / {"where": "hand", "hand": 0 或 1} /
## {"where": "armor"} / {"where": "outside"} (窗口外面) / {"where": ""} (窗口里别的地方)
func spot_at(p: Vector2) -> Dictionary:
	if not win.has_point(p):
		return {"where": "outside"}
	var row := row_at(LIST.x, LIST.y, p, scroll, items().size())
	if row != -1:
		return {"where": "pack", "index": row}
	for hand in 2:
		if hand_rect(hand).has_point(p):
			return {"where": "hand", "hand": hand}
	if r(ARMOR).has_point(p):
		return {"where": "armor"}
	return {"where": ""}


## 鼠标指着的东西 (没有是 null)
func item_at(p: Vector2) -> Inventory.Item:
	var s := spot_at(p)
	match s["where"]:
		"pack":
			return items()[s["index"]] if s["index"] >= 0 else null
		"hand":
			return Inventory.hand_item(unit, s["hand"])
		"armor":
			return Inventory.Item.new("armor", unit.armor.id) if unit.armor.id != "none" else null
	return null


func press(p: Vector2) -> void:
	if r(UP).has_point(p):
		scroll = scroll_by(scroll, -1, items().size())
		return
	if r(DOWN).has_point(p):
		scroll = scroll_by(scroll, 1, items().size())
		return
	if r(DONE).has_point(p):
		close()
		return
	var s := spot_at(p)
	var it := item_at(p)
	if it != null:
		drag = {"from": s["where"], "item": it, "hand": s.get("hand", 0)}


func release(p: Vector2) -> void:
	if drag.is_empty():
		return
	var d := drag
	drag = {}
	var to := spot_at(p)
	var why := move(d, to)
	if why != "":
		show_hint(why)


## 把拖着的东西放到 to; 放不了返回原因
func move(d: Dictionary, to: Dictionary) -> String:
	var from: String = d["from"]
	var where: String = to["where"]
	if where == "" or where == from and from != "hand":
		return ""
	if where == "outside":
		if battle == null:
			return "不要的东西去武器架画面放回去"
		battle.throw_away(unit, from, d["item"], d["hand"])
		return ""
	match from:
		"pack":
			if where == "hand":
				return Inventory.equip(unit, d["item"], to["hand"])
			if where == "armor":
				return Inventory.wear(unit, d["item"])
		"hand":
			if where == "pack":
				return Inventory.unequip(unit, d["hand"])
			if where == "hand":
				return Inventory.swap_hands(unit) if to["hand"] != d["hand"] else ""
			if where == "armor":
				return "这个不能穿"
		"armor":
			if where == "pack":
				return Inventory.take_off(unit)
			if where == "hand":
				return "只有武器能拿在手上"
	return ""


func wheel(p: Vector2, d: int) -> void:
	if at(LIST.x, LIST.y, SLOT_W, SLOT_H * ROWS).has_point(p):
		scroll = scroll_by(scroll, d, items().size())


# ---------- 画 ----------

func _draw() -> void:
	if unit == null:
		return
	draw_window()
	var list := items()
	scroll = scroll_by(scroll, 0, list.size())
	var hot := row_at(LIST.x, LIST.y, mouse, scroll, list.size())
	draw_list(LIST.x, LIST.y, list, scroll, hot)
	draw_arrows(r(UP), r(DOWN), scroll > 0, scroll + ROWS < list.size())
	UIKit.slot(self, r(BODY))
	draw_rect(r(BODY).grow(-3), Color8(20, 22, 18))
	_big_slot(r(ARMOR), "护甲", Inventory.Item.new("armor", unit.armor.id) if unit.armor.id != "none" else null, "armor")
	for hand in 2:
		var label: String = Unit.HAND_NAMES[hand]
		if not unit.hand_ok(hand):
			label += " (废了)"
		_big_slot(hand_rect(hand), label, Inventory.hand_item(unit, hand), "hand", hand)
	draw_info()
	draw_done(r(DONE))


## 护甲、手的大格子: 左上角写是哪个格子, 中间画东西, 下面写名字; 拖东西过来时能放的格子描绿边
func _big_slot(rect: Rect2, label: String, it: Inventory.Item, where: String, hand := 0) -> void:
	UIKit.slot(self, rect)
	draw_rect(rect.grow(-3), Color8(30, 28, 22))
	if rect.has_point(mouse):
		draw_rect(rect.grow(-3), Color(1, 1, 1, 0.06))
	if not drag.is_empty() and rect.has_point(mouse):
		draw_rect(rect.grow(-2), UIKit.GREEN_DIM, false, 2)
	UIKit.text(self, 12, label, Color8(150, 140, 110), rect.position + Vector2(8, 6))
	var dragging_this: bool = not drag.is_empty() and drag["from"] == where and (where != "hand" or drag["hand"] == hand)
	if it != null and not dragging_this:
		UIKit.item_picture(self, rect.get_center() + Vector2(0, 2), it, 0.55)
		var name := it.name()
		if it.stacks():
			name += " ×%d" % it.count
		elif Gear.WEAPONS.has(it.id) and it.kind == "weapon" and Gear.WEAPONS[it.id].magazine > 0:
			name += " %d/%d" % [it.loaded, Gear.WEAPONS[it.id].magazine]
		UIKit.text(self, 12, name, UIKit.TEXT, Vector2(rect.get_center().x, rect.end.y - 12), "center")


## 右边的绿屏幕: 鼠标指着东西就写说明; 不然写你的能力值、生命、防御、压力 (战斗里)、手上拿的、总重量
func draw_info() -> void:
	var box := r(INFO)
	UIKit.crt(self, box)
	var y := box.position.y + 10
	var it: Inventory.Item = drag["item"] if not drag.is_empty() else item_at(mouse)
	if it != null:
		y = draw_lines(box, y, it.name(), UIKit.AMBER)
		y = draw_lines(box, y + 4, Inventory.describe(it))
	else:
		UIKit.text(self, 12, unit.name, UIKit.AMBER, Vector2(box.position.x + 12, y), "topleft", true)
		y += 20
		for i in 3:
			var a: String = Rules.STAT_ORDER[i * 2]
			var b: String = Rules.STAT_ORDER[i * 2 + 1]
			UIKit.text(self, 12, "%s %d" % [Rules.STAT_NAMES[a], unit.stats[a]], PANEL_GREEN, Vector2(box.position.x + 12, y), "topleft", true)
			UIKit.text(self, 12, "%s %d" % [Rules.STAT_NAMES[b], unit.stats[b]], PANEL_GREEN, Vector2(box.get_center().x + 6, y), "topleft", true)
			y += 16
		y += 6
		var hp := "生命 %d/%d" % [unit.hp, unit.max_hp] if battle != null else "生命 %d" % Rules.max_hp(unit.stats["vigor"])
		y = draw_lines(box, y, "%s   防御 %d" % [hp, unit.defense()])
		if battle != null:
			y = draw_lines(box, y, "压力 %d (%s)" % [unit.stress, Rules.stress_zone_name(unit.stress)])
		y = draw_lines(box, y, "护甲挡 %d 点, 再挡 %d%%" % [unit.armor.threshold, unit.armor.resist])
		y += 6
		for hand in 2:
			var w: Gear.Weapon = Gear.WEAPONS[unit.hands[hand]] if unit.hands[hand] != "" else Gear.WEAPONS["fist"]
			y = draw_lines(box, y, "%s: %s" % [Unit.HAND_NAMES[hand], w.name])
			y = draw_lines(box, y, "  伤害 %d～%d, 打一下 %d 点" % [w.dmg_min, w.dmg_max, w.ap], UIKit.GREEN_DIM)
	var room := Inventory.room(unit)
	var total := "总重 %s / %s 公斤" % [Inventory.kg(Inventory.weight(unit)), Inventory.kg(Inventory.capacity_of(unit))]
	UIKit.text(self, 12, total, PANEL_GREEN if room >= 0 else UIKit.ORANGE, Vector2(box.position.x + 12, box.end.y - 24), "topleft", true)
	draw_hint(Rect2(box.position, Vector2(box.size.x, box.size.y - 26)))
	# 窗口下面一行: 怎么用
	var tips := "拖到格子上: 拿着 / 穿上 · 拖回左边: 放回背包"
	if battle != null:
		tips += " · 拖到外面: 扔在地上"
	UIKit.text(self, 12, tips, Color8(50, 44, 32), Vector2(win.position.x + 20, win.end.y - 20))
