class_name DialogueView
extends Control
## 跟人说话的画面: 照《辐射》二代的对话画面摆 (用户 2026-10-09 拿原版截图说「得像这个对话界面一样」)。
## 位置和比例照原版 (640×480) 放大: 横着 ×1.875, 竖着 ×1.5。只学摆法和样子: 图全用代码画, 英文换成中文。
## 上面: 中间老电视一样的大框里是对方的头像, 左边几根电子管, 右边喇叭、电线、线圈; 头像下面一条网格屏幕是对方说的话。
## 下面: 左边钱数小屏幕和「回顾」按钮, 中间弧形的屏幕是你能选的回答, 右边「交易」红圆按钮 (以后才有)。
## 鼠标: 点回答 (指着会变亮), 滚轮翻页。键盘: 数字键 1～9 选回答, ↑↓ 翻对方的话, R 回顾, B 交易。

signal finished(how: String)  ## 说完了: 「结束」或「开打」

const W := 1200
const H := 720
const PANEL_Y := 436.0                       # 下面面板从这里开始
# 上面
const FRAME := Rect2(232, 6, 736, 320)       # 头像的大框 (像老电视, 圆角)
const FRAME_EDGE := 16                       # 大框的边多宽
const PORTRAIT := Rect2(248, 22, 704, 288)   # 头像 (大框往里缩一圈)
const REPLY_BOX := Rect2(246, 334, 712, 96)  # 对方说的话 (网格屏幕)
const REPLY_LINE := 28.0
# 下面, 从左到右
const LEFT_PLATE := Rect2(4, 442, 146, 272)
const MONEY_BOX := Rect2(14, 454, 126, 78)   # 钱数小屏幕 (连外框)
const REVIEW_BTN := Rect2(14, 656, 126, 54)  # 回顾 (黄黑斜条的按钮)
const OPT_BEZEL := Rect2(156, 442, 888, 272) # 中间那块板
const OPT_BOX := Rect2(214, 488, 776, 194)   # 你能选的回答
const OPT_LINE := 28.0
const RIGHT_PLATE := Rect2(1050, 442, 146, 272)
const BARTER_PLATE := Rect2(1078, 498, 90, 50)
const BARTER_AT := Vector2(1123, 523)        # 交易的红圆按钮
const BARTER_R := 15.0
# 回顾
const REVIEW_SCREEN := Rect2(28, 24, 1004, 672)
const REVIEW_UP := Rect2(1058, 214, 120, 60)
const REVIEW_DOWN := Rect2(1058, 290, 120, 60)
const REVIEW_DONE := Rect2(1050, 596, 136, 84)
const REVIEW_LINE := 28.0

const HINT_TIME := 2.0
## 靠能力值换来的回答, 前面写「[学识 6]」(后来的《辐射》这样写, 原版一二代不写; 不想要就改成 false)
const SHOW_TAGS := true
const GREEN := Color8(96, 224, 88)
const HOVER := Color8(236, 240, 214)         # 鼠标指着的回答 (原版是发白的)
const YOU_COLOR := Color8(226, 214, 150)     # 回顾里你说的话
const LATER_BARTER := "交易: 以后才有"

## 上面的背景 (机器、电子管、喇叭) 单独一层, 画在最底下
class MachineLayer:
	extends Control
	var view: DialogueView

	func _draw() -> void:
		view.draw_machinery(self)


## 头像单独一层, 放大以后超出框的部分剪掉 (clip_contents)
class FaceLayer:
	extends Control
	var view: DialogueView

	func _draw() -> void:
		view.draw_face(self)


var talk: Dialogue.Talk
var look: Dictionary
var machine_layer: MachineLayer
var face_layer: FaceLayer
var mouse := Vector2.ZERO
var reply_scroll := 0      # 对方的话往下翻了几行
var opt_scroll := 0        # 回答往下翻了几行 (回答太多才用得到)
var reviewing := false     # 开着「回顾」
var review_scroll := 0
var hint := ""
var hint_left := 0.0
var time := 0.0
var speak_left := 0.0      # 对方还要「说」几秒 (嘴一张一合)


func _init(p_talk: Dialogue.Talk = null) -> void:
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# 两层都画在这个画面自己画的东西 (头像的框、对方的话、下面的面板) 后面
	machine_layer = MachineLayer.new()
	machine_layer.view = self
	machine_layer.size = size
	face_layer = FaceLayer.new()
	face_layer.view = self
	face_layer.position = PORTRAIT.position
	face_layer.size = PORTRAIT.size
	face_layer.clip_contents = true
	for layer in [machine_layer, face_layer]:
		layer.show_behind_parent = true
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(layer)
	if p_talk != null:
		begin(p_talk)


## 开始跟一个人说话
func begin(p_talk: Dialogue.Talk) -> void:
	talk = p_talk
	look = Portrait.look_of(talk.dialogue.face)
	reviewing = false
	hint = ""
	new_part()


func new_part() -> void:
	reply_scroll = 0
	opt_scroll = 0
	speak_left = clampf(talk.part.text.length() * 0.06, 0.8, 4.0) if talk.part != null else 0.0


func show_hint(words: String) -> void:
	hint = words
	hint_left = HINT_TIME


func _process(delta: float) -> void:
	step(delta)
	queue_redraw()
	for layer in [machine_layer, face_layer]:
		layer.visible = not reviewing
		layer.queue_redraw()


func step(delta: float) -> void:
	time += delta
	speak_left = maxf(0, speak_left - delta)
	if hint_left > 0:
		hint_left -= delta
		if hint_left <= 0:
			hint = ""


# ---------- 位置 ----------

## 对方的话折好的行 (文件里分几行写的, 这里也分开)
func reply_lines() -> Array:
	var lines := []
	if talk.part != null:
		for para in talk.part.text.split("\n"):
			lines.append_array(UIKit.wrap(24, para, REPLY_BOX.size.x - 56, false))
	return lines


func reply_fit() -> int:
	return floori((REPLY_BOX.size.y - 10) / REPLY_LINE)


## 回答折好的行: [第几个回答, 这一行的字, 是不是这个回答的第一行]
func option_rows() -> Array:
	var rows := []
	var opts := talk.options()
	for i in opts.size():
		var o: Dialogue.Option = opts[i]
		var words := o.text
		if SHOW_TAGS and o.tag != "":
			words = "[%s] %s" % [o.tag, words]
		var lines := UIKit.wrap(24, words, OPT_BOX.size.x - 80, false)
		for j in lines.size():
			rows.append([i, lines[j], j == 0])
	return rows


func opt_fit() -> int:
	return floori((OPT_BOX.size.y - 20) / OPT_LINE)


func opt_top() -> float:
	return OPT_BOX.position.y + 12


## 鼠标指着第几个回答 (从 0 数; 没指着是 -1)
func option_at(p: Vector2) -> int:
	if not OPT_BOX.has_point(p) or p.y < opt_top():
		return -1
	var rows := option_rows()
	var row := floori((p.y - opt_top()) / OPT_LINE)
	if row >= opt_fit() or row + opt_scroll >= rows.size():
		return -1
	return rows[row + opt_scroll][0]


## 回顾里的行: [字, 颜色, 往右缩进多少]
func review_rows() -> Array:
	var rows := []
	for entry in talk.history:
		var npc: bool = entry[0] == "npc"
		if not rows.is_empty():
			rows.append(["", GREEN, 0])
		rows.append([(talk.dialogue.who if npc else "你") + ":", UIKit.GREEN_DIM if npc else Color8(150, 140, 96), 0])
		for para in String(entry[1]).split("\n"):
			for line in UIKit.wrap(24, para, REVIEW_SCREEN.size.x - 100, false):
				rows.append([line, GREEN if npc else YOU_COLOR, 30])
	return rows


func review_fit() -> int:
	return floori((REVIEW_SCREEN.size.y - 40) / REVIEW_LINE)


func scroll_reply(d: int) -> void:
	reply_scroll = clampi(reply_scroll + d, 0, maxi(0, reply_lines().size() - reply_fit()))


func scroll_options(d: int) -> void:
	opt_scroll = clampi(opt_scroll + d, 0, maxi(0, option_rows().size() - opt_fit()))


func scroll_review(d: int) -> void:
	review_scroll = clampi(review_scroll + d, 0, maxi(0, review_rows().size() - review_fit()))


func barter_hit(p: Vector2) -> bool:
	return BARTER_PLATE.has_point(p) or p.distance_to(BARTER_AT) <= BARTER_R + 4


# ---------- 鼠标键盘 ----------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse = event.position
	elif event is InputEventMouseButton and event.pressed:
		mouse = event.position
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				click(event.position)
			MOUSE_BUTTON_WHEEL_UP:
				wheel(event.position, -1)
			MOUSE_BUTTON_WHEEL_DOWN:
				wheel(event.position, 1)


func wheel(p: Vector2, d: int) -> void:
	if reviewing:
		scroll_review(d * 2)
	elif REPLY_BOX.has_point(p):
		scroll_reply(d)
	elif OPT_BOX.has_point(p):
		scroll_options(d)


func click(p: Vector2) -> void:
	if reviewing:
		if REVIEW_UP.has_point(p):
			scroll_review(-review_fit() / 2)
		elif REVIEW_DOWN.has_point(p):
			scroll_review(review_fit() / 2)
		elif REVIEW_DONE.has_point(p):
			reviewing = false
		return
	var i := option_at(p)
	if i >= 0:
		choose(i)
	elif REVIEW_BTN.has_point(p):
		open_review()
	elif barter_hit(p):
		show_hint(LATER_BARTER)
	elif REPLY_BOX.has_point(p):  # 跟原版一样: 点对方的话上半边往上翻, 下半边往下翻
		scroll_reply(-1 if p.y < REPLY_BOX.get_center().y else 1)


func press_key(key: Key) -> void:
	if reviewing:
		match key:
			KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_R:
				reviewing = false
			KEY_UP:
				scroll_review(-1)
			KEY_DOWN:
				scroll_review(1)
			KEY_PAGEUP:
				scroll_review(-review_fit() / 2)
			KEY_PAGEDOWN:
				scroll_review(review_fit() / 2)
		return
	if key >= KEY_1 and key <= KEY_9:
		choose(key - KEY_1)
	elif key >= KEY_KP_1 and key <= KEY_KP_9:
		choose(key - KEY_KP_1)
	elif key == KEY_UP:
		scroll_reply(-1)
	elif key == KEY_DOWN:
		scroll_reply(1)
	elif key == KEY_R:
		open_review()
	elif key == KEY_B:
		show_hint(LATER_BARTER)


## 选第 i 个回答 (从 0 数)
func choose(i: int) -> void:
	if not talk.choose(i):
		return
	if talk.ended != "":
		finished.emit(talk.ended)
	else:
		new_part()


func open_review() -> void:
	reviewing = true
	review_scroll = maxi(0, review_rows().size() - review_fit())  # 先看最近说的


# ---------- 画 ----------

func _draw() -> void:
	if talk == null:
		return
	if reviewing:
		draw_review()
		return
	draw_frame()
	draw_reply()
	draw_panel()
	draw_tip()


## 上面的背景: 深色的机器, 左边电子管, 右边电线、喇叭、线圈, 两个上角斜撑着铁条
func draw_machinery(ci: CanvasItem) -> void:
	UIKit.metal(ci, Rect2(0, 0, W, PANEL_Y), 21, Color(0.5, 0.46, 0.42))
	ci.draw_rect(Rect2(36, 24, 210, 410), Color(0, 0, 0, 0.3))
	ci.draw_rect(Rect2(962, 24, 232, 410), Color(0, 0, 0, 0.3))

	# 左边: 一块浅色的铁板, 带孔的板子, 一层架子, 四根电子管
	UIKit.metal(ci, Rect2(6, 40, 46, 380), 22, Color(1.3, 1.2, 1.05))
	UIKit.bevel(ci, Rect2(6, 40, 46, 380), true, 2)
	UIKit.screw(ci, Vector2(29, 58))
	UIKit.screw(ci, Vector2(29, 402))
	var holes := Rect2(52, 270, 196, 82)
	UIKit.metal(ci, holes, 23, Color(0.75, 0.7, 0.66))
	UIKit.bevel(ci, holes, true, 2)
	for y in range(int(holes.position.y) + 8, int(holes.end.y) - 4, 9):
		for x in range(int(holes.position.x) + 8, int(holes.end.x) - 4, 9):
			ci.draw_circle(Vector2(x, y), 2.4, Color8(24, 20, 16))
	var shelf := Rect2(50, 246, 200, 16)
	UIKit.metal(ci, shelf, 24, Color(1.05, 1.0, 0.92))
	UIKit.bevel(ci, shelf, true, 2)
	_tube(ci, Vector2(112, 246), 150, 0.0)
	_tube(ci, Vector2(196, 246), 160, 1.7)
	_tube(ci, Vector2(100, 428), 142, 3.1)
	_tube(ci, Vector2(196, 428), 142, 4.6)

	# 右边: 电线 (先画, 被喇叭挡住一部分)、喇叭、线圈、电容、几个小零件
	var wires := [
		[Color8(168, 40, 30), [Vector2(992, -4), Vector2(984, 120), Vector2(1060, 70), Vector2(1052, 170)]],
		[Color8(56, 128, 60), [Vector2(1012, -4), Vector2(1004, 110), Vector2(1186, 70), Vector2(1204, 190)]],
		[Color8(200, 194, 176), [Vector2(1034, -4), Vector2(1026, 64), Vector2(1150, 40), Vector2(1204, 120)]],
		[Color8(36, 36, 34), [Vector2(1058, -4), Vector2(1098, 56), Vector2(1170, 24), Vector2(1204, 80)]],
		[Color8(168, 40, 30), [Vector2(1006, 300), Vector2(984, 350), Vector2(1010, 390), Vector2(1040, 384)]],
		[Color8(56, 128, 60), [Vector2(1190, 300), Vector2(1200, 360), Vector2(1170, 420), Vector2(1150, 404)]],
	]
	for wire in wires:
		var pts := _bezier(wire[1])
		ci.draw_polyline(pts, Color8(16, 14, 12), 7)
		ci.draw_polyline(pts, wire[0], 4)
		ci.draw_polyline(pts, Color(wire[0].lightened(0.4), 0.6), 1)
	var housing := Rect2(1004, 132, 176, 176)
	UIKit.metal(ci, housing, 25, Color(0.92, 0.88, 0.82))
	UIKit.bevel(ci, housing, true, 3)
	UIKit.rivets(ci, housing, 10)
	_speaker(ci, housing.get_center(), 70)
	_coil(ci, Rect2(1030, 352, 90, 60))
	var cap := Rect2(1134, 356, 26, 50)  # 电容: 青色的小圆柱
	ci.draw_line(Vector2(cap.position.x + 8, cap.end.y), Vector2(cap.position.x + 8, cap.end.y + 14), Color8(170, 170, 170), 2)
	ci.draw_line(Vector2(cap.end.x - 8, cap.end.y), Vector2(cap.end.x - 8, cap.end.y + 14), Color8(170, 170, 170), 2)
	UIKit.rounded(ci, cap, Color8(64, 146, 150), 6, 1, Color8(30, 70, 72))
	ci.draw_rect(Rect2(cap.position.x + 5, cap.position.y + 6, 4, cap.size.y - 12), Color(1, 1, 1, 0.35))
	ci.draw_rect(Rect2(cap.position.x, cap.position.y + 14, cap.size.x, 6), Color8(200, 196, 180))
	for i in 4:  # 小电阻, 带颜色的环
		var r := Rect2(980 + i * 12, 330, 7, 24)
		UIKit.rounded(ci, r, Color8(196, 176, 130), 3)
		for k in 3:
			ci.draw_rect(Rect2(r.position.x, r.position.y + 5 + k * 5, r.size.x, 2), [Color8(150, 40, 30), Color8(40, 40, 40), Color8(200, 140, 40)][(i + k) % 3])

	# 两个上角斜撑的铁条
	_brace(ci, Vector2(-12, 118), Vector2(118, -12), 26)
	_brace(ci, Vector2(1082, -12), Vector2(1212, 118), 26)
	UIKit.rounded(ci, FRAME.grow(5), Color(0, 0, 0, 0.45), 50)  # 头像大框后面的影子


## 一根电子管: 玻璃壳、里面的极板、发橙光的灯丝 (一闪一闪)、底座
func _tube(ci: CanvasItem, base: Vector2, h: float, phase: float) -> void:
	var glow := 0.8 + 0.12 * sin(time * 7.0 + phase) + 0.08 * sin(time * 23.0 + phase * 3.0)
	var glass := Rect2(base.x - 20, base.y - h, 40, h - 20)
	var mid := Vector2(base.x, glass.position.y + glass.size.y * 0.55)
	ci.draw_circle(mid, 40, Color(1, 0.55, 0.15, 0.09 * glow))
	ci.draw_circle(mid, 26, Color(1, 0.6, 0.2, 0.1 * glow))
	UIKit.rounded(ci, glass, Color(0.62, 0.66, 0.68, 0.2), 18)
	ci.draw_rect(Rect2(base.x - 3, glass.position.y - 9, 6, 12), Color(0.72, 0.74, 0.78, 0.6))  # 顶上的小尖
	var plate := Rect2(base.x - 13, mid.y - glass.size.y * 0.22, 26, glass.size.y * 0.44)
	ci.draw_rect(plate, Color8(66, 64, 62))
	for y in range(int(plate.position.y) + 3, int(plate.end.y) - 1, 4):
		ci.draw_line(Vector2(plate.position.x + 1, y), Vector2(plate.end.x - 1, y), Color8(104, 100, 96))
	ci.draw_rect(Rect2(base.x - 4, plate.position.y + 6, 8, plate.size.y - 12), Color(1.0, 0.62, 0.22, 0.75 * glow))
	ci.draw_rect(Rect2(base.x - 2, plate.position.y + 10, 4, plate.size.y - 20), Color(1.0, 0.88, 0.6, 0.8 * glow))
	UIKit.rounded(ci, Rect2(base.x - 12, glass.position.y + 8, 24, 14), Color(0.72, 0.73, 0.76, 0.75), 6)
	ci.draw_line(Vector2(glass.position.x + 7, glass.position.y + 18), Vector2(glass.position.x + 7, glass.end.y - 6), Color(1, 1, 1, 0.45), 3)
	ci.draw_line(Vector2(glass.end.x - 6, glass.position.y + 26), Vector2(glass.end.x - 6, glass.end.y - 14), Color(1, 1, 1, 0.18), 2)
	UIKit.rounded(ci, glass, Color(0, 0, 0, 0), 18, 1, Color(0.85, 0.88, 0.9, 0.5))
	var socket := Rect2(base.x - 24, base.y - 22, 48, 22)
	UIKit.rounded(ci, socket, Color8(206, 200, 184), 4, 1, Color8(110, 104, 92))
	for k in 2:
		ci.draw_line(Vector2(socket.position.x + 3, socket.position.y + 7 + k * 7), Vector2(socket.end.x - 3, socket.position.y + 7 + k * 7), Color8(160, 154, 140), 1)


## 喇叭: 一圈圈往里暗下去, 中间一个防尘罩, 左上角一道反光
func _speaker(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c + Vector2(2, 3), r + 6, Color(0, 0, 0, 0.4))
	ci.draw_circle(c, r + 5, Color8(34, 32, 28))
	ci.draw_circle(c, r, Color8(70, 66, 60))
	for i in 9:
		var t := i / 8.0
		ci.draw_circle(c, r * (0.88 - t * 0.6), Color8(58, 55, 50).lerp(Color8(20, 19, 18), t))
	ci.draw_arc(c, r * 0.88, 0, TAU, 48, Color8(90, 86, 78), 2)
	ci.draw_circle(c, r * 0.24, Color8(28, 27, 26))
	ci.draw_circle(c + Vector2(-r * 0.05, -r * 0.07), r * 0.09, Color(0.9, 0.9, 0.9, 0.8))
	ci.draw_arc(c, r * 0.7, PI * 1.08, PI * 1.45, 16, Color(1, 1, 1, 0.16), 7)


## 线圈: 两头是铁片, 中间一圈圈红铜线
func _coil(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_rect(r.grow(4), Color(0, 0, 0, 0.35))
	var y := r.position.y + 2
	var k := 0
	while y < r.end.y - 2:
		ci.draw_line(Vector2(r.position.x + 8, y), Vector2(r.end.x - 8, y), Color8(178, 56, 34) if k % 2 == 0 else Color8(118, 32, 22), 2)
		y += 2
		k += 1
	ci.draw_line(Vector2(r.position.x + 8, r.position.y + 10), Vector2(r.end.x - 8, r.position.y + 10), Color(1, 0.8, 0.7, 0.35), 2)
	for x in [r.position.x, r.end.x - 9]:
		UIKit.rounded(ci, Rect2(x, r.position.y - 6, 9, r.size.y + 12), Color8(70, 66, 58), 2, 1, Color8(30, 28, 24))


## 斜撑的铁条, 上面一排铆钉
func _brace(ci: CanvasItem, a: Vector2, b: Vector2, width: float) -> void:
	var dir := (b - a).normalized()
	var n := Vector2(-dir.y, dir.x) * width / 2
	UIKit.poly(ci, [a + n, b + n, b - n, a - n], Color8(74, 70, 60), Color8(30, 28, 24), 2)
	ci.draw_line(a - n * 0.8, b - n * 0.8, Color8(126, 118, 100), 2)
	var length := a.distance_to(b)
	var d := 26.0
	while d < length - 16:
		UIKit.rivet(ci, a + dir * d)
		d += 34


static func _bezier(p: Array, n := 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var t := i / float(n)
		var u := 1.0 - t
		pts.append(p[0] * u * u * u + p[1] * 3 * u * u * t + p[2] * 3 * u * t * t + p[3] * t * t * t)
	return pts


## 头像 (画在 FaceLayer 上, 左上角是 (0, 0)): 说话时嘴一张一合, 隔一会儿眨眼, 胸口一起一伏
func draw_face(ci: CanvasItem) -> void:
	var mouth := 0.0
	if speak_left > 0:
		mouth = absf(sin(time * 13.0)) * (0.55 + 0.45 * absf(sin(time * 3.3)))
	var blink := fmod(time, 3.7) < 0.13
	Portrait.draw(ci, Rect2(Vector2.ZERO, PORTRAIT.size), look, mouth, blink, 1.5 + 1.5 * sin(time * 1.7))


## 像老电视一样的圆角大框 (盖在头像上)
func draw_frame() -> void:
	# 玻璃的反光
	UIKit.poly(self, [PORTRAIT.position + Vector2(30, 0), PORTRAIT.position + Vector2(230, 0),
			PORTRAIT.position + Vector2(70, 170), PORTRAIT.position + Vector2(0, 170), PORTRAIT.position + Vector2(0, 40)],
			Color(1, 1, 1, 0.04))
	# 大框: 一圈宽边正好盖住头像的四个角 (所以头像看起来是圆角的)
	UIKit.rounded(self, FRAME, Color(0, 0, 0, 0), 44, FRAME_EDGE, Color8(86, 72, 56))
	UIKit.rounded(self, FRAME, Color(0, 0, 0, 0), 44, 3, Color8(34, 28, 22))
	UIKit.rounded(self, FRAME.grow(-3), Color(0, 0, 0, 0), 41, 2, Color8(150, 128, 96))
	UIKit.rounded(self, FRAME.grow(-FRAME_EDGE + 3), Color(0, 0, 0, 0), 31, 3, Color8(28, 22, 18))
	var rng := RandomNumberGenerator.new()  # 框上的锈斑
	rng.seed = 5
	for i in 90:
		var along := rng.randf()
		var p := FRAME.position + Vector2(48 + along * (FRAME.size.x - 96), rng.randf_range(4, FRAME_EDGE - 4))
		if rng.randf() < 0.5:
			p.y = FRAME.end.y - (p.y - FRAME.position.y)
		draw_rect(Rect2(p, Vector2(rng.randi_range(2, 5), 2)), UIKit.RUST if rng.randf() < 0.6 else Color8(60, 48, 36))


## 对方说的话: 深色半透明的网格屏幕, 绿字
func draw_reply() -> void:
	var box := REPLY_BOX
	draw_rect(box.grow(3), Color8(24, 22, 18))
	draw_rect(box, Color(0.05, 0.07, 0.05, 0.9))
	var x := box.position.x + 3
	while x < box.end.x:
		draw_line(Vector2(x, box.position.y), Vector2(x, box.end.y), Color(0.3, 0.36, 0.28, 0.18))
		x += 7
	var y := box.position.y + 3
	while y < box.end.y:
		draw_line(Vector2(box.position.x, y), Vector2(box.end.x, y), Color(0.3, 0.36, 0.28, 0.18))
		y += 7
	UIKit.bevel(self, box.grow(3), false, 2)
	for i in 5:  # 下面一排小针脚 (原版屏幕底下也有)
		draw_rect(Rect2(box.position.x + 40 + i * 9, box.end.y + 3, 3, 5), Color8(150, 146, 136))
		draw_rect(Rect2(box.end.x - 84 + i * 9, box.end.y + 3, 3, 5), Color8(150, 146, 136))
	var lines := reply_lines()
	var fit := reply_fit()
	for i in mini(fit, lines.size() - reply_scroll):
		UIKit.text(self, 24, lines[i + reply_scroll], GREEN, Vector2(box.position.x + 20, box.position.y + 6 + i * REPLY_LINE), "topleft", true)
	# 还有没显示完的: 右边画小三角 (点上半边 / 下半边、滚轮、↑↓ 翻)
	var ax := box.end.x - 18
	if reply_scroll > 0:
		_arrow(Vector2(ax, box.position.y + 14), true, GREEN)
	if reply_scroll + fit < lines.size():
		_arrow(Vector2(ax, box.end.y - 14), false, GREEN)


func _arrow(c: Vector2, up: bool, color: Color) -> void:
	var s := 1.0 if up else -1.0
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7 * s), c + Vector2(8, 5 * s), c + Vector2(-8, 5 * s)]), color)


## 下面一整条: 左边钱数和回顾, 中间回答的屏幕, 右边交易
func draw_panel() -> void:
	var panel := Rect2(0, PANEL_Y, W, H - PANEL_Y)
	UIKit.metal(self, panel, 26)
	UIKit.bevel(self, panel, true, 3)
	draw_rect(Rect2(0, H - 8, W, 8), Color(0, 0, 0, 0.25))

	# 左边: 钱数小屏幕、几道通风口、「回顾」和黄黑斜条的按钮
	_side_plate(LEFT_PLATE, 27)
	UIKit.rounded(self, MONEY_BOX, Color8(58, 54, 44), 12, 2, Color8(30, 28, 22))
	UIKit.crt(self, MONEY_BOX.grow(-9))
	UIKit.text(self, 24, "$%d" % talk.memory.money, GREEN, MONEY_BOX.get_center(), "center", true)
	for i in 3:
		var slot := Rect2(26, 556 + i * 15, 102, 8)
		UIKit.rounded(self, slot, Color8(22, 20, 16), 4)
		draw_line(Vector2(slot.position.x + 4, slot.end.y), Vector2(slot.end.x - 4, slot.end.y), Color8(140, 130, 104), 1)
	_stencil("回顾", Vector2(LEFT_PLATE.get_center().x, 624))
	var hot_review := REVIEW_BTN.has_point(mouse)
	UIKit.rounded(self, REVIEW_BTN, Color8(70, 66, 54), 4, 2, Color8(30, 28, 22))
	UIKit.bevel(self, REVIEW_BTN.grow(-2), true, 2)
	_hazard(REVIEW_BTN.grow(-9), hot_review)

	# 中间: 回答的屏幕
	UIKit.metal(self, OPT_BEZEL, 28, Color(1.12, 1.1, 1.04))
	UIKit.bevel(self, OPT_BEZEL, true, 3)
	var band := Rect2(OPT_BEZEL.position.x + 34, OPT_BEZEL.position.y + 8, OPT_BEZEL.size.x - 68, 30)
	draw_rect(band, Color8(132, 126, 112))
	for k in range(int(band.position.y) + 2, int(band.end.y), 3):
		draw_line(Vector2(band.position.x, k), Vector2(band.end.x, k), Color(1, 1, 1, 0.06) if k % 2 == 0 else Color(0, 0, 0, 0.06))
	UIKit.bevel(self, band, true, 2)
	UIKit.screw(self, OPT_BEZEL.position + Vector2(18, 20), 7)
	UIKit.screw(self, Vector2(OPT_BEZEL.end.x - 18, OPT_BEZEL.position.y + 20), 7)
	_knob(Vector2(OPT_BEZEL.position.x + 26, OPT_BEZEL.end.y - 52))
	_knob(Vector2(OPT_BEZEL.end.x - 26, OPT_BEZEL.end.y - 52))
	UIKit.rounded(self, OPT_BOX.grow(10), Color8(36, 34, 30), 34, 2, Color8(150, 142, 120))
	UIKit.rounded(self, OPT_BOX, Color8(30, 36, 30), 28)
	var sy := OPT_BOX.position.y + 4
	while sy < OPT_BOX.end.y - 4:  # 扫描线
		draw_line(Vector2(OPT_BOX.position.x + 14, sy), Vector2(OPT_BOX.end.x - 14, sy), Color(0, 0, 0, 0.18))
		sy += 3
	UIKit.poly(self, [OPT_BOX.position + Vector2(40, 6), OPT_BOX.position + Vector2(360, 6), OPT_BOX.position + Vector2(300, 40),
			OPT_BOX.position + Vector2(20, 40)], Color(1, 1, 1, 0.025))  # 弧形玻璃的反光
	UIKit.rounded(self, OPT_BOX, Color(0, 0, 0, 0), 28, 3, Color8(20, 22, 18))
	var rows := option_rows()
	var hot := option_at(mouse)
	var fit := opt_fit()
	for r in mini(fit, rows.size() - opt_scroll):
		var row: Array = rows[r + opt_scroll]
		var color := HOVER if row[0] == hot else GREEN
		var y := opt_top() + r * OPT_LINE
		if row[2]:  # 原版每个回答前面一个小方点
			draw_rect(Rect2(OPT_BOX.position.x + 30, y + 9, 7, 7), color)
		UIKit.text(self, 24, row[1], color, Vector2(OPT_BOX.position.x + 48, y), "topleft", true)
	if opt_scroll > 0:
		_arrow(Vector2(OPT_BOX.end.x - 22, opt_top() + 10), true, GREEN)
	if opt_scroll + fit < rows.size():
		_arrow(Vector2(OPT_BOX.end.x - 22, OPT_BOX.end.y - 16), false, GREEN)
	if hint != "":
		UIKit.text(self, 24, hint, Color8(20, 16, 10), band.get_center() + Vector2(1, 1), "center")
		UIKit.text(self, 24, hint, UIKit.AMBER, band.get_center(), "center")
	UIKit.text(self, 12, "数字键 1～9 选回答 · R 回顾 · 滚轮翻页", Color8(46, 42, 32), Vector2(OPT_BEZEL.get_center().x, OPT_BEZEL.end.y - 14), "center")

	# 右边: 「交易」和红圆按钮, 下面一块带通风口的铁板
	_side_plate(RIGHT_PLATE, 29)
	_stencil("交易", Vector2(RIGHT_PLATE.get_center().x, 470))
	UIKit.metal(self, BARTER_PLATE, 30, Color(1.15, 1.1, 0.95))
	UIKit.bevel(self, BARTER_PLATE, true, 2)
	for p in [BARTER_PLATE.position + Vector2(8, 8), Vector2(BARTER_PLATE.end.x - 8, BARTER_PLATE.position.y + 8),
			Vector2(BARTER_PLATE.position.x + 8, BARTER_PLATE.end.y - 8), BARTER_PLATE.end - Vector2(8, 8)]:
		UIKit.screw(self, p, 3.5)
	UIKit.red_button(self, BARTER_AT, BARTER_R, barter_hit(mouse))
	var vent := Rect2(1082, 566, 82, 130)
	UIKit.metal(self, vent, 31, Color(1.2, 1.15, 1.0))
	UIKit.bevel(self, vent, true, 2)
	UIKit.rivets(self, vent, 9)
	for i in 3:
		UIKit.rounded(self, Rect2(vent.position.x + 14, vent.end.y - 52 + i * 13, vent.size.x - 28, 7), Color8(24, 22, 18), 3)
	draw_rect(Rect2(vent.position.x + 18, vent.position.y + 26, vent.size.x - 36, 30), Color8(70, 64, 50))
	UIKit.bevel(self, Rect2(vent.position.x + 18, vent.position.y + 26, vent.size.x - 36, 30), false, 2)


## 两边那种带螺丝的竖铁板
func _side_plate(rect: Rect2, seed_value: int) -> void:
	UIKit.metal(self, rect, seed_value, Color(1.08, 1.06, 0.84))
	UIKit.bevel(self, rect, true, 3)
	for p in [rect.position + Vector2(9, 9), Vector2(rect.end.x - 9, rect.position.y + 9),
			Vector2(rect.position.x + 9, rect.end.y - 9), rect.end - Vector2(9, 9)]:
		UIKit.screw(self, p, 4)


## 原版那种喷上去的黄色大字 (带一点黑影子)
func _stencil(words: String, center: Vector2) -> void:
	UIKit.text(self, 48, words, Color8(36, 30, 18), center + Vector2(2, 2), "center")
	UIKit.text(self, 48, words, Color8(226, 196, 86), center, "center")


## 黄黑斜条 (回顾按钮); 鼠标指着亮一点
func _hazard(rect: Rect2, hot: bool) -> void:
	draw_rect(rect, Color8(26, 24, 20))
	var box := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	var yellow := Color8(236, 206, 60) if hot else Color8(206, 176, 52)
	var x := rect.position.x - rect.size.y
	while x < rect.end.x:
		var stripe := PackedVector2Array([Vector2(x, rect.end.y), Vector2(x + rect.size.y, rect.position.y),
				Vector2(x + rect.size.y + 12, rect.position.y), Vector2(x + 12, rect.end.y)])
		for piece in Geometry2D.intersect_polygons(stripe, box):
			draw_colored_polygon(piece, yellow)
		x += 24
	UIKit.bevel(self, rect, false, 2)


## 屏幕下面两角那种圆钮 (中间一个亮点)
func _knob(c: Vector2) -> void:
	draw_circle(c + Vector2(1, 2), 15, Color(0, 0, 0, 0.4))
	draw_circle(c, 15, Color8(40, 38, 34))
	draw_circle(c, 12, Color8(150, 148, 140))
	draw_circle(c, 8, Color8(36, 34, 32))
	draw_circle(c + Vector2(-1, -1), 3, Color8(240, 240, 236))


## 鼠标指着回顾、交易: 一句说明
func draw_tip() -> void:
	var words := ""
	if REVIEW_BTN.has_point(mouse):
		words = "回顾 (R): 看看刚才说过的话"
	elif barter_hit(mouse):
		words = "交易 (B): 以后才有"
	if words == "":
		return
	var size := UIKit.text_size(12, words) + Vector2(20, 12)
	var box := Rect2(Vector2(REVIEW_BTN.end.x + 10, REVIEW_BTN.get_center().y - size.y / 2), size)  # 回顾: 放在按钮右边
	if words.begins_with("交易"):  # 交易: 放在按钮左边
		box.position = Vector2(BARTER_PLATE.position.x - size.x - 10, BARTER_AT.y - size.y / 2)
	UIKit.crt(self, box)
	UIKit.text(self, 12, words, GREEN, box.get_center(), "center", true)


## 回顾: 一整屏绿字, 列出刚才说过的话; 右边上下翻和「完成」
func draw_review() -> void:
	UIKit.metal(self, Rect2(0, 0, W, H), 32)
	UIKit.bevel(self, Rect2(0, 0, W, H), true, 3)
	UIKit.rounded(self, REVIEW_SCREEN.grow(10), Color8(36, 34, 30), 20, 2, Color8(150, 142, 120))
	UIKit.crt(self, REVIEW_SCREEN)
	var rows := review_rows()
	var fit := review_fit()
	for i in mini(fit, rows.size() - review_scroll):
		var row: Array = rows[i + review_scroll]
		UIKit.text(self, 24, row[0], row[1], Vector2(REVIEW_SCREEN.position.x + 30 + row[2], REVIEW_SCREEN.position.y + 20 + i * REVIEW_LINE), "topleft", true)
	var side := Rect2(1046, 24, 144, 672)
	_side_plate(side, 33)
	_stencil("回顾", Vector2(side.get_center().x, 110))
	for b in [[REVIEW_UP, true], [REVIEW_DOWN, false]]:
		var rect: Rect2 = b[0]
		UIKit.metal_button(self, rect, rect.has_point(mouse))
		_arrow(rect.get_center(), b[1], UIKit.AMBER)
	UIKit.text(self, 12, "滚轮 / ↑↓ 翻页", Color8(60, 54, 40), Vector2(side.get_center().x, REVIEW_DOWN.end.y + 22), "center")
	UIKit.red_button(self, Vector2(REVIEW_DONE.position.x + 34, REVIEW_DONE.get_center().y), 20, REVIEW_DONE.has_point(mouse))
	UIKit.text(self, 24, "完成", Color8(226, 196, 86), Vector2(REVIEW_DONE.position.x + 66, REVIEW_DONE.get_center().y), "midleft")
	UIKit.text(self, 12, "Esc / 回车", Color8(60, 54, 40), Vector2(side.get_center().x, REVIEW_DONE.end.y + 4), "center")
