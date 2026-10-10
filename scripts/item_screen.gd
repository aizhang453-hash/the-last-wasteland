class_name ItemScreen
extends Control
## 背包画面 (inventory_view.gd)、武器架画面 (loot_view.gd) 共用的东西:
## 一个照原版大小 (499×377) 放大 1.4 倍的窗口、一列一列的东西 (上下翻)、用鼠标拖东西、提示、会转身的小人。
## 原版的坐标直接写在各个画面里, 用 at() 换成画面上的位置。

signal closed

const SCALE := 1.4
const WIN_SIZE := Vector2(499, 377) * SCALE
const ROWS := 6                   # 一列显示几格
const SLOT_W := 64.0              # 一格多大 (原版坐标)
const SLOT_H := 48.0
const HINT_TIME := 2.5
const PANEL_GREEN := Color8(96, 224, 88)


## 拖着的东西画在最上面 (盖过小人)
class TopLayer:
	extends Control
	var screen: ItemScreen

	func _draw() -> void:
		screen.draw_top(self)


var unit: Unit
var win := Rect2(Vector2(250, 6), WIN_SIZE)
var mouse := Vector2.ZERO
var drag: Dictionary = {}  # 正在拖的东西: {"from": 从哪拖的, "item": Inventory.Item, ...}; 没在拖是空的
var hint := ""
var hint_left := 0.0
var figure: UIKit.FigureBox
var top_layer: TopLayer


func _init() -> void:
	size = Vector2(1200, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	figure = UIKit.FigureBox.new()
	add_child(figure)
	top_layer = TopLayer.new()
	top_layer.screen = self
	top_layer.size = size
	top_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_layer)


## 原版窗口里的坐标 -> 画面上的方块
func at(x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(win.position + Vector2(x, y) * SCALE, Vector2(w, h) * SCALE)


## 打开: 窗口左上角摆在 top_left
func open_for(p_unit: Unit, top_left: Vector2) -> void:
	unit = p_unit
	win.position = top_left
	drag = {}
	hint = ""
	figure.unit = unit
	visible = true
	layout()


## 各个画面摆好小人的位置
func layout() -> void:
	pass


func close() -> void:
	drag = {}
	visible = false
	closed.emit()


func show_hint(words: String) -> void:
	hint = words
	hint_left = HINT_TIME


func _process(delta: float) -> void:
	step(delta)
	queue_redraw()
	top_layer.queue_redraw()


func step(delta: float) -> void:
	if hint_left > 0:
		hint_left -= delta
		if hint_left <= 0:
			hint = ""


# ---------- 一列东西 ----------

## 一列从原版坐标 (x, y) 开始, 第 i 格
func slot_rect(x: float, y: float, i: int) -> Rect2:
	return at(x, y + i * SLOT_H, SLOT_W, SLOT_H)


## 鼠标在这一列的第几样东西 (算上往下翻了几格); 不在格子上是 -1, 在格子上但那格是空的是 -2
func row_at(x: float, y: float, p: Vector2, scroll: int, count: int) -> int:
	for i in ROWS:
		if slot_rect(x, y, i).has_point(p):
			return i + scroll if i + scroll < count else -2
	return -1


## 是不是同一样东西 (背包里的子弹每次都是新算出来的, 看是不是同一种)
static func same(a: Inventory.Item, b: Inventory.Item) -> bool:
	return a == b or (a.kind == "ammo" and b.kind == "ammo" and a.id == b.id)


func scroll_by(scroll: int, d: int, count: int) -> int:
	return clampi(scroll + d, 0, maxi(0, count - ROWS))


# ---------- 鼠标键盘 ----------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse = event.position
	elif event is InputEventMouseButton:
		mouse = event.position
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				press(event.position)
			else:
				release(event.position)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			wheel(event.position, -1)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			wheel(event.position, 1)


## 按下鼠标 (开始拖东西、点按钮); 各个画面自己写
func press(_p: Vector2) -> void:
	pass


## 松开鼠标 (把拖着的东西放下); 各个画面自己写
func release(_p: Vector2) -> void:
	pass


func wheel(_p: Vector2, _d: int) -> void:
	pass


## Esc、回车、I: 关掉
func press_key(key: Key) -> void:
	if key in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_I]:
		close()


# ---------- 画 ----------

## 窗口: 外面暗一点, 生锈的铁板, 四个角铆钉
func draw_window() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))
	draw_rect(win.grow(4), Color(0, 0, 0, 0.5))
	UIKit.metal(self, win, 41)
	UIKit.bevel(self, win, true, 3)
	UIKit.rivets(self, win, 10)


## 一列东西: 每格一个凹下去的深色格子, 里面画东西的图, 一堆的写「×24」; 鼠标指着的格子亮一点
func draw_list(x: float, y: float, items: Array, scroll: int, hot: int) -> void:
	UIKit.slot(self, at(x - 3, y - 3, SLOT_W + 6, SLOT_H * ROWS + 6))
	for i in ROWS:
		var r := slot_rect(x, y, i)
		draw_rect(r.grow(-2), Color8(26, 24, 20))
		draw_line(Vector2(r.position.x + 4, r.end.y - 1), Vector2(r.end.x - 4, r.end.y - 1), Color8(56, 52, 42), 1)
		var k := i + scroll
		if k >= items.size():
			continue
		var it: Inventory.Item = items[k]
		if k == hot and drag.is_empty():
			draw_rect(r.grow(-2), Color(1, 1, 1, 0.07))
		if not drag.is_empty() and same(drag["item"], it):
			continue  # 正拿在鼠标上
		UIKit.item_picture(self, r.get_center() + Vector2(0, 2), it, 0.48)
		if it.stacks():
			UIKit.text(self, 12, "×%d" % it.count, UIKit.TEXT, r.end - Vector2(6, 4), "bottomright")


## 上下翻的两个小按钮
func draw_arrows(up: Rect2, down: Rect2, can_up: bool, can_down: bool) -> void:
	for b in [[up, true, can_up], [down, false, can_down]]:
		var r: Rect2 = b[0]
		UIKit.metal_button(self, r, r.has_point(mouse) and b[2])
		var c := r.get_center()
		var s := 1.0 if b[1] else -1.0
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7 * s), c + Vector2(8, 5 * s), c + Vector2(-8, 5 * s)]),
				UIKit.AMBER if b[2] else Color8(110, 100, 76))


## 绿屏幕上一段一段的字 (自动折行); 返回写到哪了
func draw_lines(box: Rect2, y: float, words: String, color := PANEL_GREEN, size := 12) -> float:
	for line in UIKit.wrap(size, words, box.size.x - 24, false):
		if y > box.end.y - 18:
			break
		UIKit.text(self, size, line, color, Vector2(box.position.x + 12, y), "topleft", true)
		y += 16 if size < 18 else 28
	return y


## 「完成」: 红圆按钮 + 字
func draw_done(r: Rect2) -> void:
	UIKit.red_button(self, Vector2(r.position.x + 26, r.get_center().y), 16, r.has_point(mouse))
	UIKit.text(self, 24, "完成", Color8(226, 196, 86), Vector2(r.position.x + 52, r.get_center().y), "midleft")


func draw_hint(box: Rect2) -> void:
	if hint == "":
		return
	var lines := UIKit.wrap(12, hint, box.size.x - 24, false)
	var y := box.end.y - 10 - lines.size() * 16
	draw_rect(Rect2(box.position.x + 4, y - 4, box.size.x - 8, lines.size() * 16 + 8), Color(0.1, 0.05, 0, 0.85))
	for line in lines:
		UIKit.text(self, 12, line, UIKit.ORANGE, Vector2(box.position.x + 12, y), "topleft")
		y += 16


## 拖着的东西跟着鼠标走
func draw_top(ci: CanvasItem) -> void:
	if drag.is_empty() or not visible:
		return
	UIKit.item_picture(ci, mouse, drag["item"], 0.5)
