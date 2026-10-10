class_name LootView
extends ItemScreen
## 武器架画面 (练习场开打前挑带什么): 照《辐射》二代搜东西的画面摆 (两边对拖), 用户 2026-10-09 定的。
## 位置照原版 (窗口 499×377) 放大 1.4 倍: 左边是你的小人和说明屏幕, 中间两列: 你的背包、武器架, 右边画着武器架。
## 从武器架拖到你的背包: 拿走 (武器架上的拿不完, 背得动就行); 从背包拖回武器架: 放回去 (一堆子弹、手雷整堆放回去)。
## 以后搜尸体、开箱子也用这个画面, 右边换成尸体、箱子。
## 手上拿什么、穿什么在背包画面里换 (原版也是这样)。

# 原版窗口里的坐标
const YOU_BODY := [20, 35, 120, 150]
const INFO := [20, 196, 140, 166]
const MINE := Vector2(176, 37)
const MINE_UP := [244, 39, 22, 22]
const MINE_DOWN := [244, 62, 22, 22]
const RACK := Vector2(297, 37)
const RACK_UP := [365, 39, 22, 22]
const RACK_DOWN := [365, 62, 22, 22]
const RACK_BODY := [392, 35, 92, 150]
const DONE := [380, 310, 110, 50]

var rack: Array = []
var scroll_mine := 0
var scroll_rack := 0


func open(p_unit: Unit) -> void:
	rack = Inventory.rack()
	scroll_mine = 0
	scroll_rack = 0
	open_for(p_unit, Vector2(250, 96))


func layout() -> void:
	figure.place(r(YOU_BODY).grow(-8), 2.6)


func r(a: Array) -> Rect2:
	return at(a[0], a[1], a[2], a[3])


func mine() -> Array:
	return Inventory.entries(unit)


## 鼠标在哪一列的第几样: {"where": "mine" 或 "rack", "index": 第几样 (-2 是空格子)}; 都不在 {"where": ""}
func spot_at(p: Vector2) -> Dictionary:
	var row := row_at(MINE.x, MINE.y, p, scroll_mine, mine().size())
	if row != -1:
		return {"where": "mine", "index": row}
	row = row_at(RACK.x, RACK.y, p, scroll_rack, rack.size())
	if row != -1 or r(RACK_BODY).has_point(p):
		return {"where": "rack", "index": row}
	return {"where": ""}


func item_at(p: Vector2) -> Inventory.Item:
	var s := spot_at(p)
	if s["where"] == "" or s["index"] < 0:
		return null
	return mine()[s["index"]] if s["where"] == "mine" else rack[s["index"]]


func press(p: Vector2) -> void:
	for b in [[MINE_UP, "mine", -1], [MINE_DOWN, "mine", 1], [RACK_UP, "rack", -1], [RACK_DOWN, "rack", 1]]:
		if r(b[0]).has_point(p):
			if b[1] == "mine":
				scroll_mine = scroll_by(scroll_mine, b[2], mine().size())
			else:
				scroll_rack = scroll_by(scroll_rack, b[2], rack.size())
			return
	if r(DONE).has_point(p):
		close()
		return
	var it := item_at(p)
	if it != null:
		drag = {"from": spot_at(p)["where"], "item": it}


func release(p: Vector2) -> void:
	if drag.is_empty():
		return
	var d := drag
	drag = {}
	var to: String = spot_at(p)["where"]
	if d["from"] == "rack" and to == "mine":
		var why := Inventory.add(unit, d["item"].copy())
		if why != "":
			show_hint(why)
	elif d["from"] == "mine" and to == "rack":
		Inventory.remove(unit, d["item"])


func wheel(p: Vector2, d: int) -> void:
	if at(MINE.x, MINE.y, SLOT_W, SLOT_H * ROWS).has_point(p):
		scroll_mine = scroll_by(scroll_mine, d, mine().size())
	elif at(RACK.x, RACK.y, SLOT_W, SLOT_H * ROWS).has_point(p):
		scroll_rack = scroll_by(scroll_rack, d, rack.size())


# ---------- 画 ----------

func _draw() -> void:
	if unit == null:
		return
	draw_window()
	var list := mine()
	scroll_mine = scroll_by(scroll_mine, 0, list.size())
	UIKit.text(self, 12, "你的背包", UIKit.AMBER, at(MINE.x, 22, 0, 0).position)
	UIKit.text(self, 12, "武器架", UIKit.AMBER, at(RACK.x, 22, 0, 0).position)
	draw_list(MINE.x, MINE.y, list, scroll_mine, row_at(MINE.x, MINE.y, mouse, scroll_mine, list.size()))
	draw_arrows(r(MINE_UP), r(MINE_DOWN), scroll_mine > 0, scroll_mine + ROWS < list.size())
	draw_list(RACK.x, RACK.y, rack, scroll_rack, row_at(RACK.x, RACK.y, mouse, scroll_rack, rack.size()))
	draw_arrows(r(RACK_UP), r(RACK_DOWN), scroll_rack > 0, scroll_rack + ROWS < rack.size())
	if not drag.is_empty():  # 拖东西的时候, 能放的那一列描绿边
		var target := MINE if drag["from"] == "rack" else RACK
		draw_rect(at(target.x - 3, target.y - 3, SLOT_W + 6, SLOT_H * ROWS + 6), UIKit.GREEN_DIM, false, 2)
	var room := Inventory.room(unit)
	UIKit.text(self, 12, "总重 %s / %s 公斤" % [Inventory.kg(Inventory.weight(unit)), Inventory.kg(Inventory.capacity_of(unit))],
			UIKit.TEXT if room >= 0 else UIKit.ORANGE, at(MINE.x, 332, 0, 0).position)
	UIKit.slot(self, r(YOU_BODY))
	draw_rect(r(YOU_BODY).grow(-3), Color8(20, 22, 18))
	UIKit.slot(self, r(RACK_BODY))
	draw_rect(r(RACK_BODY).grow(-3), Color8(20, 22, 18))
	_draw_rack(r(RACK_BODY).grow(-6))
	draw_info()
	draw_done(r(DONE))


## 右边画的武器架: 两根木头柱子、三根横杆, 上面挂着枪和棍子, 底下一箱子弹
func _draw_rack(box: Rect2) -> void:
	var wood := Color8(110, 78, 48)
	for x in [box.position.x + 10, box.end.x - 18]:
		draw_rect(Rect2(x, box.position.y + 6, 8, box.size.y - 12), wood)
		draw_line(Vector2(x + 2, box.position.y + 8), Vector2(x + 2, box.end.y - 8), wood.lightened(0.2), 1)
	var shelves := 3
	for i in shelves:
		var y := box.position.y + 34 + i * (box.size.y - 70) / (shelves - 1)
		draw_rect(Rect2(box.position.x + 10, y, box.size.x - 20, 6), wood.darkened(0.15))
	var c := box.get_center()
	UIKit.item_picture(self, Vector2(c.x, box.position.y + 26), Inventory.weapon("rifle"), 0.42)
	UIKit.item_picture(self, Vector2(c.x, c.y - 4), Inventory.weapon("smg"), 0.42)
	UIKit.item_picture(self, Vector2(c.x - 4, box.end.y - 42), Inventory.weapon("pipe"), 0.38)
	UIKit.item_picture(self, Vector2(c.x, box.end.y - 18), Inventory.Item.new("ammo", "pistol", 24), 0.36)


## 左下的绿屏幕: 鼠标指着东西就写说明; 不然写手上拿的、穿的, 还有怎么用
func draw_info() -> void:
	var box := r(INFO)
	UIKit.crt(self, box)
	var y := box.position.y + 10
	var it: Inventory.Item = drag["item"] if not drag.is_empty() else item_at(mouse)
	if it != null:
		y = draw_lines(box, y, it.name(), UIKit.AMBER)
		y = draw_lines(box, y + 4, Inventory.describe(it))
	else:
		for hand in 2:
			var held := Inventory.hand_item(unit, hand)
			y = draw_lines(box, y, "%s: %s" % [Unit.HAND_NAMES[hand], held.name() if held != null else "空手"])
		y = draw_lines(box, y, "护甲: %s" % unit.armor.name)
		y = draw_lines(box, y + 8, "从武器架拖到背包: 拿走; 拖回武器架: 放回去。拿在手上、穿上, 去背包画面。", UIKit.GREEN_DIM)
	draw_hint(box)
