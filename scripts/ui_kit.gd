class_name UIKit
## 界面的样子: 照《辐射》二代的感觉 (用户 2026-10-05 要求), 全部用代码画, 不用原版的图。
## - 生锈的金属面板, 边上有铆钉, 有凸起和凹下去的边
## - 绿色字的老式屏幕 (有一条条的扫描线)
## - 一排小灯 (行动点)、红色的圆按钮、数字计数器
## 这里的函数都要传一个 CanvasItem (ci), 在它的 _draw() 里调用。

const METAL := Color8(92, 84, 66)
const METAL_LIGHT := Color8(140, 128, 100)
const METAL_DARK := Color8(44, 40, 32)
const RUST := Color8(110, 70, 40)
const SCREEN_BG := Color8(14, 22, 12)
const GREEN := Color8(96, 224, 88)
const GREEN_DIM := Color8(48, 120, 44)
const AMBER := Color8(232, 196, 80)
const LAMP_RED := Color8(200, 40, 30)
const TEXT := Color8(226, 214, 186)
const DIM := Color8(140, 130, 110)
const YELLOW := Color8(240, 200, 80)
const RED := Color8(220, 80, 60)
const ORANGE := Color8(240, 110, 70)
const WARN := Color8(255, 140, 60)

## 像素风的中文字体: 缝合像素字体 (Fusion Pixel Font, 12 像素, 简体中文), SIL 开放字体许可证 1.1,
## 许可证跟字体放在 fonts/fusion-pixel/ 里 (用户 2026-10-06 同意用)。万一缺字, 再用电脑自带的字体补上。
const PIXEL_FONT := "res://fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.otf.woff2"

static var _font: Font
static var _metal_cache := {}


static func font() -> Font:
	if _font == null:
		var backup := SystemFont.new()
		backup.font_names = PackedStringArray(["Hiragino Sans GB", "PingFang SC", "STHeiti",
				"Microsoft YaHei", "SimHei", "Noto Sans CJK SC", "WenQuanYi Micro Hei"])
		var pixel: FontFile = load(PIXEL_FONT)
		if pixel == null:
			_font = backup
		else:
			pixel = pixel.duplicate()
			# 像素字不要抹边, 一个点就是一个点
			pixel.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			pixel.hinting = TextServer.HINTING_NONE
			pixel.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
			pixel.fallbacks = [backup]
			_font = pixel
	return _font


## 像素字只有在 12 的整数倍大小时才清楚: 小字 12, 中字 24, 大字 48
static func px(size: int) -> int:
	if size < 18:
		return 12
	if size < 36:
		return 24
	return 48


static func text_size(size: int, words: String) -> Vector2:
	return font().get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, px(size))


## 写字。where: 字摆在哪; anchor: where 是字的哪个点 ("topleft" / "center" / "midleft" / "midright" / "topright" / "bottomright")
## glow: 绿屏幕上的字, 周围带一点光
static func text(ci: CanvasItem, size: int, words: String, color: Color, where: Vector2,
		anchor := "topleft", glow := false) -> void:
	var f := font()
	var sz := text_size(size, words)
	var top_left := where
	match anchor:
		"center":
			top_left = where - sz / 2
		"midleft":
			top_left = Vector2(where.x, where.y - sz.y / 2)
		"midright":
			top_left = Vector2(where.x - sz.x, where.y - sz.y / 2)
		"topright":
			top_left = Vector2(where.x - sz.x, where.y)
		"bottomright":
			top_left = where - sz
	var real := px(size)
	var baseline := (top_left + Vector2(0, f.get_ascent(real))).round()  # 摆在整数位置上, 像素字才不糊
	if glow:
		var halo := Color(color.r / 3, color.g / 3, color.b / 3)
		for d in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			ci.draw_string(f, baseline + d, words, HORIZONTAL_ALIGNMENT_LEFT, -1, real, halo)
	ci.draw_string(f, baseline, words, HORIZONTAL_ALIGNMENT_LEFT, -1, real, color)


## 一行太长就折成几行 (中文一个字一个字地折; 句号逗号这些不放在一行的开头)。indent: 折下来的行前面空两格
static func wrap(size: int, words: String, width: float, indent := true) -> Array:
	const NO_LINE_START := "，。、,.!?！？;；:：)）」』…"
	var lead := "  " if indent else ""
	var lines := []
	var line := ""
	for ch in words:
		if line != "" and text_size(size, line + ch).x > width and not NO_LINE_START.contains(ch):
			lines.append(line)
			line = lead + ch if ch != " " else lead
		else:
			line += ch
	if line.strip_edges() != "":
		lines.append(line)
	return lines


## 一块生锈的金属板的图: 底色上撒斑点、锈迹和划痕 (每块用固定的随机数, 画出来每次都一样; 只做一次)
static func metal_texture(size: Vector2i, seed_value: int) -> ImageTexture:
	var key := "%s/%d" % [size, seed_value]
	if _metal_cache.has(key):
		return _metal_cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(METAL)
	for i in size.x * size.y / 40:
		var shade := rng.randi_range(-18, 14) / 255.0
		var c := Color(METAL.r + shade, METAL.g + shade, METAL.b + shade)
		img.fill_rect(Rect2i(rng.randi_range(0, size.x - 1), rng.randi_range(0, size.y - 1),
				rng.randi_range(1, 3), rng.randi_range(1, 2)), c)
	for i in size.x * size.y / 2500 + 1:  # 一块块锈
		var x := rng.randi_range(0, size.x - 1)
		var y := rng.randi_range(0, size.y - 1)
		for j in 30:
			var p := Vector2i(x + rng.randi_range(-14, 14), y + rng.randi_range(-6, 6))
			if p.x >= 0 and p.y >= 0 and p.x < size.x - 1 and p.y < size.y - 1:
				img.fill_rect(Rect2i(p, Vector2i(2, 2)), RUST if rng.randf() < 0.6 else Color8(90, 60, 36))
	for i in size.x / 60 + 1:  # 划痕
		var x := rng.randi_range(0, maxi(0, size.x - 21))
		var y := rng.randi_range(0, size.y - 1)
		var c := METAL_LIGHT if rng.randf() < 0.5 else METAL_DARK
		var length := rng.randi_range(8, 30)
		var dy := rng.randi_range(-3, 3)
		for k in length:
			var p := Vector2i(x + k, y + int(dy * k / float(length)))
			if p.x < size.x and p.y >= 0 and p.y < size.y:
				img.set_pixelv(p, c)
	var tex := ImageTexture.create_from_image(img)
	_metal_cache[key] = tex
	return tex


static func metal(ci: CanvasItem, rect: Rect2, seed_value := 0, tint := Color.WHITE) -> void:
	ci.draw_texture_rect(metal_texture(Vector2i(rect.size), seed_value), rect, false, tint)


## 一颗螺丝 (带一字槽)
static func screw(ci: CanvasItem, p: Vector2, r := 5.0) -> void:
	ci.draw_circle(p + Vector2(1, 1), r, METAL_DARK)
	ci.draw_circle(p, r, Color8(150, 140, 116))
	ci.draw_circle(p, r - 1.5, Color8(118, 108, 88))
	ci.draw_line(p + Vector2(-r + 1.5, r - 2.5), p + Vector2(r - 2.5, -r + 1.5), Color8(60, 54, 42), 2)


## 凸起 (raised) 或凹下去的边: 上左亮、下右暗, 凹下去就反过来
static func bevel(ci: CanvasItem, rect: Rect2, raised := true, width := 3) -> void:
	var light := METAL_LIGHT if raised else METAL_DARK
	var dark := METAL_DARK if raised else METAL_LIGHT
	for i in width:
		var r := rect.grow(-i)
		ci.draw_line(r.position + Vector2(0, 0.5), Vector2(r.end.x, r.position.y + 0.5), light)
		ci.draw_line(r.position + Vector2(0.5, 0), Vector2(r.position.x + 0.5, r.end.y), light)
		ci.draw_line(Vector2(r.position.x, r.end.y - 0.5), r.end - Vector2(0, 0.5), dark)
		ci.draw_line(Vector2(r.end.x - 0.5, r.position.y), r.end - Vector2(0.5, 0), dark)


static func rivet(ci: CanvasItem, p: Vector2) -> void:
	ci.draw_circle(p + Vector2(1, 1), 4, METAL_DARK)
	ci.draw_circle(p, 4, Color8(120, 110, 88))
	ci.draw_circle(p - Vector2(1, 1), 1, Color8(170, 160, 130))


static func rivets(ci: CanvasItem, rect: Rect2, inset := 8.0) -> void:
	for p in [rect.position + Vector2(inset, inset), Vector2(rect.end.x - inset - 1, rect.position.y + inset),
			Vector2(rect.position.x + inset, rect.end.y - inset - 1), rect.end - Vector2(inset + 1, inset + 1)]:
		rivet(ci, p)


static var _box_cache := {}


## 圆角方块 (Godot 的 draw_rect 没有圆角, 用 StyleBox 画; 一样的样子只做一次)
static func rounded(ci: CanvasItem, rect: Rect2, color: Color, radius := 10, border := 0, border_color := Color.BLACK) -> void:
	var key := "%s/%d/%d/%s" % [color, radius, border, border_color]
	var sb: StyleBoxFlat = _box_cache.get(key)
	if sb == null:
		sb = StyleBoxFlat.new()
		sb.bg_color = color
		sb.set_corner_radius_all(radius)
		if border > 0:
			sb.set_border_width_all(border)
			sb.border_color = border_color
		_box_cache[key] = sb
	sb.draw(ci.get_canvas_item(), rect)


## 老式绿字屏幕: 深色底, 一条条扫描线, 凹下去的边框
static func crt(ci: CanvasItem, rect: Rect2) -> void:
	rounded(ci, rect, SCREEN_BG, 10)
	var y := rect.position.y + 2
	while y < rect.end.y - 2:
		ci.draw_line(Vector2(rect.position.x + 3, y), Vector2(rect.end.x - 3, y), Color(0, 0, 0, 0.23))
		y += 3
	rounded(ci, rect, Color(0, 0, 0, 0), 10, 3, METAL_DARK)
	rounded(ci, rect.grow(-3), Color(0, 0, 0, 0), 8, 1, Color8(30, 44, 26))


## 凹下去的深色格子 (放武器、计数器)
static func slot(ci: CanvasItem, rect: Rect2) -> void:
	ci.draw_rect(rect, Color8(30, 28, 22))
	bevel(ci, rect, false, 3)


## 一盏小圆灯: 亮着的有一圈光
static func lamp(ci: CanvasItem, center: Vector2, on: bool, color := GREEN, radius := 6.0) -> void:
	ci.draw_circle(center, radius + 2, METAL_DARK)
	if on:
		ci.draw_circle(center, radius * 2, Color(color, 0.2))
		ci.draw_circle(center, radius, color)
		ci.draw_circle(center - Vector2(2, 2), 2, color.lightened(0.5))
	else:
		ci.draw_circle(center, radius, color.darkened(0.75))


## 红色圆按钮 (像老机器上的按钮)
static func red_button(ci: CanvasItem, center: Vector2, radius: float, hover := false) -> void:
	ci.draw_circle(center + Vector2(2, 2), radius + 4, METAL_DARK)
	ci.draw_circle(center, radius + 4, Color8(150, 140, 112))
	ci.draw_circle(center, radius, Color8(70, 14, 10))
	ci.draw_circle(center - Vector2(1, 1), radius - 3, Color8(230, 60, 44) if hover else LAMP_RED)
	ci.draw_circle(center - Vector2(radius / 3, radius / 3), maxf(2, radius / 4), Color8(255, 170, 150))


## 普通的金属按钮: 鼠标指着变亮, 按下去 (pressed) 的样子是凹的
static func metal_button(ci: CanvasItem, rect: Rect2, hover: bool, pressed := false) -> void:
	ci.draw_rect(rect, Color8(70, 64, 50) if pressed else (Color8(120, 108, 84) if hover else METAL))
	bevel(ci, rect, not pressed, 2)


static func poly(ci: CanvasItem, points: Array, color: Color, outline := Color(0, 0, 0, 0), width := 1.0) -> void:
	var pts := PackedVector2Array(points)
	ci.draw_colored_polygon(pts, color)
	if outline.a > 0:
		pts.append(pts[0])
		ci.draw_polyline(pts, outline, width)


# ---------- 武器的样子 (放在武器格子里的大图) ----------

## 在 center 画一把武器 (都用方块和多边形拼的)
static func weapon_picture(ci: CanvasItem, center: Vector2, weapon_id: String) -> void:
	var c := center
	match weapon_id:
		"pistol":
			poly(ci, [c + Vector2(-50, -16), c + Vector2(46, -16), c + Vector2(46, -2), c + Vector2(-10, -2),
					c + Vector2(-14, 4), c + Vector2(-50, 4)], Color8(70, 72, 78), Color8(110, 112, 120), 2)
			poly(ci, [c + Vector2(-46, 4), c + Vector2(-18, 4), c + Vector2(-24, 36), c + Vector2(-50, 36)],
					Color8(88, 60, 40), Color8(60, 40, 26), 2)
			ci.draw_arc(c + Vector2(-10, 6), 10, 3.3, 6.1, 12, Color8(90, 92, 98), 3)
			ci.draw_line(c + Vector2(-44, -12), c + Vector2(40, -12), Color8(150, 152, 160))
		"knife":
			poly(ci, [c + Vector2(-10, -8), c + Vector2(52, -8), c + Vector2(64, -2), c + Vector2(52, 6),
					c + Vector2(-10, 6)], Color8(190, 192, 198))
			ci.draw_line(c + Vector2(-8, -6), c + Vector2(54, -6), Color8(235, 236, 240), 2)
			ci.draw_rect(Rect2(c + Vector2(-16, -14), Vector2(6, 26)), Color8(80, 80, 84))
			rounded(ci, Rect2(c + Vector2(-56, -7), Vector2(40, 14)), Color8(96, 64, 40), 4)
			for i in 4:
				ci.draw_line(c + Vector2(-50 + i * 9, -6), c + Vector2(-50 + i * 9, 6), Color8(70, 46, 28), 2)
		"pipe":
			ci.draw_line(c + Vector2(-60, 16), c + Vector2(60, -16), Color8(120, 120, 126), 9)
			ci.draw_line(c + Vector2(-58, 12), c + Vector2(58, -19), Color8(170, 170, 176), 2)
			ci.draw_circle(c + Vector2(60, -16), 6, Color8(100, 100, 106))
		"sledgehammer":
			ci.draw_line(c + Vector2(-66, 24), c + Vector2(40, -10), Color8(110, 76, 46), 7)
			poly(ci, [c + Vector2(26, -34), c + Vector2(62, -22), c + Vector2(52, 6), c + Vector2(16, -6)],
					Color8(96, 96, 102), Color8(140, 140, 148), 2)
		"rifle", "smg":
			var long := weapon_id == "rifle"
			var left := c.x - (74 if long else 54)
			var right := c.x + (74 if long else 50)
			ci.draw_rect(Rect2(left + 30, c.y - 12, right - left - 30, 10), Color8(70, 72, 78))
			ci.draw_line(Vector2(left + 32, c.y - 10), Vector2(right - 2, c.y - 10), Color8(150, 152, 160))
			poly(ci, [Vector2(left, c.y - 10), Vector2(left + 32, c.y - 12), Vector2(left + 32, c.y + 2),
					Vector2(left + 4, c.y + 14)], Color8(96, 64, 40) if long else Color8(60, 60, 66))
			ci.draw_rect(Rect2(left + 44, c.y - 2, 10, 20), Color8(88, 60, 40))
			if long:
				rounded(ci, Rect2(c.x - 6, c.y - 22, 30, 7), Color8(40, 40, 44), 3)  # 瞄准镜
			else:
				ci.draw_rect(Rect2(c.x + 2, c.y - 2, 9, 26), Color8(40, 40, 44))  # 长弹夹
		"grenade":
			ci.draw_circle(c + Vector2(0, 6), 23, Color8(66, 90, 48))
			for i in 3:
				ci.draw_line(c + Vector2(-20, -4 + i * 12), c + Vector2(20, -4 + i * 12), Color8(44, 62, 32), 2)
			ci.draw_rect(Rect2(c + Vector2(-8, -28), Vector2(16, 12)), Color8(120, 120, 126))
			ci.draw_arc(c + Vector2(14, -26), 7, 0, TAU, 16, Color8(170, 170, 176), 2)
		_:  # 拳头 (两只手都废了用脚踢, 也画这个)
			var skin := Color8(210, 168, 128)
			var dark := Color8(150, 112, 80)
			rounded(ci, Rect2(c + Vector2(-30, -22), Vector2(60, 44)), skin, 12, 2, dark)
			for i in 4:
				ci.draw_line(c + Vector2(-18 + i * 13, -20), c + Vector2(-18 + i * 13, -4), dark, 2)
			rounded(ci, Rect2(c + Vector2(-40, -6), Vector2(18, 24)), skin, 8)


## 地上的小武器 (周围一圈淡黄的光, 好让人看见)
static func ground_item(ci: CanvasItem, c: Vector2, weapon_id: String) -> void:
	ci.draw_set_transform(c, 0, Vector2(1, 0.5))
	ci.draw_circle(Vector2.ZERO, 20, Color(1, 0.86, 0.47, 0.27))
	ci.draw_set_transform(Vector2.ZERO)
	match weapon_id:
		"knife":
			ci.draw_line(c + Vector2(-2, -1), c + Vector2(10, -4), Color8(210, 210, 216), 2)
			ci.draw_line(c + Vector2(-9, 1), c + Vector2(-2, -1), Color8(110, 72, 44), 3)
		"pipe":
			ci.draw_line(c + Vector2(-11, 3), c + Vector2(11, -4), Color8(130, 130, 136), 3)
		"sledgehammer":
			ci.draw_line(c + Vector2(-12, 3), c + Vector2(6, -3), Color8(110, 76, 46), 3)
			ci.draw_rect(Rect2(c + Vector2(4, -7), Vector2(7, 9)), Color8(96, 96, 102))
		"grenade":
			ci.draw_circle(c + Vector2(0, -1), 5, Color8(66, 90, 48))
			ci.draw_rect(Rect2(c + Vector2(-2, -8), Vector2(4, 3)), Color8(120, 120, 126))
		"pistol", "rifle", "smg":
			var length := 14 if weapon_id == "pistol" else 22
			ci.draw_rect(Rect2(c.x - length / 2.0, c.y - 4, length, 4), Color8(52, 52, 58))
			ci.draw_rect(Rect2(c.x - length / 2.0, c.y, 4, 5), Color8(88, 60, 40))
		_:
			ci.draw_rect(Rect2(c + Vector2(-8, -3), Vector2(16, 6)), Color8(90, 90, 96))


# ---------- 人 ----------

## 人的样子 (按排队头像上的那个字找)
const LOOKS := {
	"你": {"shirt": Color8(70, 120, 100), "pants": Color8(78, 64, 48), "hair": Color8(52, 38, 26), "skin": Color8(222, 182, 142), "mohawk": false},
	"刀": {"shirt": Color8(140, 58, 42), "pants": Color8(60, 58, 60), "hair": Color8(30, 26, 24), "skin": Color8(200, 160, 120), "mohawk": true},
	"枪": {"shirt": Color8(120, 82, 50), "pants": Color8(66, 60, 52), "hair": Color8(150, 60, 40), "skin": Color8(214, 172, 132), "mohawk": true},
}


static func look_of(short: String) -> Dictionary:
	return LOOKS.get(short, LOOKS["刀"])


## 用方块和圆画一个小人, 脚底踩在 (cx, cy)。facing: 1 朝右, -1 朝左。
## 死了的人画成躺着的, 身下一摊血; 被打倒、打晕的人 (lying) 也躺着, 没有血。
static func person(ci: CanvasItem, foot: Vector2, look: Dictionary, facing: int, weapon_id: String,
		alive := true, lying := false) -> void:
	var cx := roundf(foot.x)
	var cy := roundf(foot.y)
	var shirt: Color = look["shirt"]
	var pants: Color = look["pants"]
	var skin: Color = look["skin"]
	if not alive or lying:
		ci.draw_set_transform(Vector2(cx, cy), 0, Vector2(1, 0.35))
		ci.draw_circle(Vector2.ZERO, 20, Color8(96, 22, 16) if not alive else Color8(70, 58, 42))
		ci.draw_set_transform(Vector2.ZERO)
		ci.draw_rect(Rect2(cx - facing * 2 - 7, cy - 10, 16, 7), pants)
		rounded(ci, Rect2(cx - facing * 14 - 9, cy - 12, 18, 10), shirt, 3)
		ci.draw_circle(Vector2(cx - facing * 26, cy - 8), 6, skin)
		return
	ci.draw_set_transform(Vector2(cx, cy), 0, Vector2(1, 0.36))
	ci.draw_circle(Vector2.ZERO, 14, Color8(70, 58, 42))  # 影子
	ci.draw_set_transform(Vector2.ZERO)
	var dark_shirt := shirt.darkened(0.25)
	for lx in [cx - 6, cx + 1]:  # 腿和鞋
		ci.draw_rect(Rect2(lx, cy - 16, 5, 14), pants)
		ci.draw_rect(Rect2(lx - (1 if facing < 0 else 0), cy - 3, 6, 3), Color8(40, 32, 26))
	ci.draw_rect(Rect2(cx - facing * 9 - 2, cy - 30, 4, 13), dark_shirt)  # 后面那只胳膊
	rounded(ci, Rect2(cx - 8, cy - 33, 16, 19), shirt, 3)  # 身子
	ci.draw_circle(Vector2(cx, cy - 40), 7, skin)  # 头和头发
	if look["mohawk"]:
		ci.draw_rect(Rect2(cx - 2, cy - 51, 4, 9), look["hair"])
	else:
		ci.draw_rect(Rect2(cx - 7, cy - 47, 14, 4), look["hair"])
		ci.draw_circle(Vector2(cx, cy - 44), 6, look["hair"])
		ci.draw_circle(Vector2(cx, cy - 40), 6, skin)
	ci.draw_rect(Rect2(cx + facing * 3 - 1, cy - 41, 2, 2), Color8(30, 24, 20))  # 眼睛
	# 前面那只胳膊往前伸, 手里拿着武器
	var hand := Vector2(cx + facing * 10, cy - 25)
	ci.draw_line(Vector2(cx + facing * 5, cy - 29), hand, dark_shirt, 4)
	var hx := hand.x
	var hy := hand.y
	match weapon_id:
		"pistol", "rifle", "smg":
			var length: int = {"pistol": 12, "smg": 16, "rifle": 22}[weapon_id]
			var x0 := hx - 6 if facing > 0 else hx - length + 6
			ci.draw_rect(Rect2(x0, hy - 2, length, 4), Color8(58, 58, 62))
			ci.draw_rect(Rect2(hx - 1, hy, 3, 5), Color8(40, 40, 44))
			if weapon_id == "smg":
				ci.draw_rect(Rect2(hx + facing * 5 - 1, hy + 2, 3, 6), Color8(40, 40, 44))  # 弹夹
			if weapon_id == "rifle":
				ci.draw_rect(Rect2(hx - facing * 9 - 3, hy - 1, 6, 5), Color8(96, 64, 40))  # 枪托
		"knife":
			ci.draw_line(hand, Vector2(hx + facing * 9, hy - 6), Color8(200, 200, 205), 2)
		"pipe":
			ci.draw_line(Vector2(hx - facing * 3, hy + 4), Vector2(hx + facing * 10, hy - 14), Color8(130, 130, 136), 3)
		"sledgehammer":
			ci.draw_line(Vector2(hx - facing * 3, hy + 5), Vector2(hx + facing * 9, hy - 16), Color8(110, 76, 46), 3)
			ci.draw_rect(Rect2(hx + facing * 9 - 6, hy - 22, 12, 8), Color8(90, 90, 96))
		"grenade":
			ci.draw_circle(Vector2(hx + facing * 3, hy - 2), 4, Color8(60, 84, 44))
	ci.draw_circle(hand, 2, skin)


# ---------- 瞄准窗口里的大个子 ----------

## 瞄准窗口里的大个子 (正面朝着你, 所以他的右手在你的左边): 每个部位在画上的位置
## fx: 人正中间的横坐标; fy: 头顶
static func figure_parts(fx: float, fy: float) -> Dictionary:
	return {
		"eyes": Rect2(fx - 18, fy + 26, 36, 16),
		"head": Rect2(fx - 26, fy + 4, 52, 60),
		"torso": Rect2(fx - 36, fy + 70, 72, 92),
		"right_arm": Rect2(fx - 60, fy + 74, 22, 96),
		"left_arm": Rect2(fx + 38, fy + 74, 22, 96),
		"groin": Rect2(fx - 30, fy + 162, 60, 26),
		"right_leg": Rect2(fx - 30, fy + 188, 27, 104),
		"left_leg": Rect2(fx + 3, fy + 188, 27, 104),
	}


## 画瞄准窗口里的大个子。瘸了、废了的地方画个红叉, 鼠标指着的部位描黄边
static func figure(ci: CanvasItem, fx: float, fy: float, look: Dictionary, crippled := {}, blind := false,
		highlight := "") -> Dictionary:
	var parts := figure_parts(fx, fy)
	var shirt: Color = look["shirt"]
	var dark := shirt.darkened(0.25)
	for key in ["right_leg", "left_leg"]:
		var r: Rect2 = parts[key]
		rounded(ci, r, look["pants"], 4)
		rounded(ci, Rect2(r.position.x - 2, r.end.y - 10, r.size.x + 4, 10), Color8(40, 32, 26), 3)
	rounded(ci, parts["groin"], look["pants"], 4)
	for key in ["right_arm", "left_arm"]:
		var r: Rect2 = parts[key]
		rounded(ci, r, dark, 8)
		ci.draw_circle(Vector2(r.get_center().x, r.end.y - 4), 9, look["skin"])
	rounded(ci, parts["torso"], shirt, 10)
	ci.draw_line(Vector2(fx, fy + 76), Vector2(fx, fy + 156), dark, 2)
	var head: Rect2 = parts["head"]
	ci.draw_set_transform(head.get_center(), 0, Vector2(1, head.size.y / head.size.x))
	ci.draw_circle(Vector2.ZERO, head.size.x / 2, look["skin"])
	ci.draw_set_transform(Vector2.ZERO)
	if look["mohawk"]:
		rounded(ci, Rect2(fx - 6, fy - 12, 12, 28), look["hair"], 3)
	else:
		rounded(ci, Rect2(head.position.x, head.position.y - 2, head.size.x, 20), look["hair"], 10)
	var eyes: Rect2 = parts["eyes"]
	for ex in [eyes.position.x + 8, eyes.end.x - 12]:
		if blind:
			ci.draw_line(Vector2(ex - 3, eyes.position.y + 4), Vector2(ex + 5, eyes.position.y + 12), Color8(200, 40, 30), 2)
			ci.draw_line(Vector2(ex + 5, eyes.position.y + 4), Vector2(ex - 3, eyes.position.y + 12), Color8(200, 40, 30), 2)
		else:
			ci.draw_rect(Rect2(ex, eyes.position.y + 6, 5, 5), Color8(30, 24, 20))
	for key in crippled:
		var r: Rect2 = parts[key]
		ci.draw_line(r.position, r.end, Color8(220, 40, 30), 3)
		ci.draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), Color8(220, 40, 30), 3)
	if highlight != "":
		var r: Rect2 = parts[highlight]
		if highlight == "head":
			ci.draw_set_transform(r.get_center(), 0, Vector2(1, r.size.y / r.size.x))
			ci.draw_arc(Vector2.ZERO, r.size.x / 2, 0, TAU, 32, AMBER, 3)
			ci.draw_set_transform(Vector2.ZERO)
		else:
			rounded(ci, r.grow(2), Color(0, 0, 0, 0), 6, 3, AMBER)
	return parts
