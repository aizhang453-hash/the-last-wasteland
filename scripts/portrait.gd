class_name Portrait
## 说话时上面大框里的头像: 胸口以上, 正对着你。全用代码画 (以后用 Blender 做模型拍成图, 到时候换掉)。
## 说话的时候嘴一张一合, 隔一会儿眨一下眼, 胸口跟着呼吸一起一伏。

## 头像的样子 (对话文件里「头像: 教官」就是用这里的名字找)
const LOOKS := {
	# 练习场的教官 (试对话用的人, 不是正式剧情里的人)
	"教官": {"skin": Color8(190, 146, 108), "hair": Color8(150, 146, 136), "eyes": Color8(84, 104, 72),
			"coat": Color8(82, 86, 56), "shirt": Color8(116, 96, 72), "wall": Color8(78, 60, 46),
			"stubble": true, "goggles": true, "scar": true, "wrinkles": true},
	# 找不到头像时用的普通人
	"路人": {"skin": Color8(214, 172, 132), "hair": Color8(70, 50, 34), "eyes": Color8(70, 50, 36),
			"coat": Color8(110, 84, 60), "shirt": Color8(150, 140, 120), "wall": Color8(60, 64, 58),
			"stubble": false, "goggles": false, "scar": false, "wrinkles": false},
}

const FACE_RX := 60.0   # 脸多宽 (一半)
const FACE_RY := 78.0   # 脸多高 (一半)

static var _wall_cache := {}
static var _vignette: ImageTexture
static var _base := Transform2D.IDENTITY  # 放大用的 (画椭圆时要接着用)


static func look_of(name: String) -> Dictionary:
	return LOOKS.get(name, LOOKS["路人"])


## 背后的墙: 深色的石头墙, 有斑点和刻痕 (一样的样子只做一次)
static func wall_texture(size: Vector2i, color: Color) -> ImageTexture:
	var key := "%s/%s" % [size, color]
	if _wall_cache.has(key):
		return _wall_cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(color)
	for i in size.x * size.y / 30:
		var shade := rng.randf_range(-0.07, 0.06)
		var c := Color(color.r + shade, color.g + shade, color.b + shade * 0.8)
		img.fill_rect(Rect2i(rng.randi_range(0, size.x - 1), rng.randi_range(0, size.y - 1),
				rng.randi_range(2, 6), rng.randi_range(1, 3)), c)
	for i in 14:  # 墙上一道道浅色的刻痕
		var p := Vector2(rng.randi_range(0, size.x - 1), rng.randi_range(0, size.y - 1))
		var dir := Vector2.from_angle(rng.randf_range(0, TAU))
		var c := color.lightened(0.06)
		for k in rng.randi_range(20, 70):
			var q := Vector2i(p + dir * k + Vector2(0, sin(k * 0.2) * 3))
			if q.x >= 0 and q.y >= 0 and q.x < size.x and q.y < size.y:
				img.set_pixelv(q, c)
	var tex := ImageTexture.create_from_image(img)
	_wall_cache[key] = tex
	return tex


## 四周暗、中间亮 (像一盏灯照着脸): 一张小图, 画的时候拉大, 自己会变得很平滑
static func vignette_texture() -> ImageTexture:
	if _vignette == null:
		var img := Image.create(48, 24, false, Image.FORMAT_RGBA8)
		for y in 24:
			for x in 48:
				var d := Vector2((x + 0.5) / 24.0 - 1, (y + 0.5) / 12.0 - 1)
				img.set_pixel(x, y, Color(0, 0, 0, clampf(d.length_squared() * 0.5 - 0.05, 0, 0.62)))
		_vignette = ImageTexture.create_from_image(img)
	return _vignette


## 脸的轮廓: 蛋形, 下巴窄一点
static func face_points(c: Vector2, rx := FACE_RX, ry := FACE_RY) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 48:
		var t := TAU * i / 48
		var s := sin(t)
		var narrow := 1.0 - 0.24 * maxf(0, s) * maxf(0, s)
		pts.append(c + Vector2(cos(t) * rx * narrow, s * ry))
	return pts


static func _ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, color: Color) -> void:
	ci.draw_set_transform_matrix(_base * Transform2D(0, Vector2(1, ry / rx), 0, c))
	ci.draw_circle(Vector2.ZERO, rx, color)
	ci.draw_set_transform_matrix(_base)


## 在 rect 里画一个头像。mouth: 嘴张多大 (0 闭着 ~ 1 张最大); blink: 正在眨眼; breath: 胸口抬起几个像素;
## zoom: 以脸为中心放大几倍 (原版的脸几乎占满整个框, 肩膀只露出一点; 放大了会超出 rect, 要画的地方自己剪掉)
static func draw(ci: CanvasItem, rect: Rect2, look: Dictionary, mouth := 0.0, blink := false, breath := 0.0, zoom := 1.28) -> void:
	ci.draw_texture_rect(wall_texture(Vector2i(rect.size), look["wall"]), rect, false)
	var cx := roundf(rect.get_center().x)
	var top := rect.position.y
	var bottom := rect.end.y
	var c := Vector2(cx, top + 120)  # 脸的正中间
	_base = Transform2D(0, Vector2(zoom, zoom), 0, c * (1 - zoom))
	ci.draw_set_transform_matrix(_base)
	var skin: Color = look["skin"]
	var hair: Color = look["hair"]
	var b := breath

	# 衣服: 肩膀、领口、翻领
	var coat: Color = look["coat"]
	var neck_y := top + 206 - b
	UIKit.poly(ci, [Vector2(cx - 262, bottom), Vector2(cx - 246, top + 256 - b), Vector2(cx - 190, top + 224 - b),
			Vector2(cx - 70, neck_y), Vector2(cx + 70, neck_y), Vector2(cx + 190, top + 224 - b),
			Vector2(cx + 246, top + 256 - b), Vector2(cx + 262, bottom)], coat, coat.darkened(0.4), 2)
	UIKit.poly(ci, [Vector2(cx + 20, neck_y), Vector2(cx + 70, neck_y), Vector2(cx + 190, top + 224 - b),
			Vector2(cx + 246, top + 256 - b), Vector2(cx + 262, bottom), Vector2(cx + 60, bottom)], Color(0, 0, 0, 0.18))
	ci.draw_line(Vector2(cx - 170, top + 230 - b), Vector2(cx - 196, bottom), coat.darkened(0.3), 2)  # 袖子的缝
	ci.draw_line(Vector2(cx + 170, top + 230 - b), Vector2(cx + 196, bottom), coat.darkened(0.4), 2)
	UIKit.poly(ci, [Vector2(cx - 46, neck_y), Vector2(cx + 46, neck_y), Vector2(cx, top + 276 - b)], look["shirt"])
	ci.draw_rect(Rect2(cx - 31, c.y + 40, 62, neck_y - c.y - 30), skin.darkened(0.14))  # 脖子
	_ellipse(ci, Vector2(cx, c.y + FACE_RY - 4), 42, 14, Color(0, 0, 0, 0.25))  # 下巴底下的影子
	for side in [-1, 1]:  # 翻领
		UIKit.poly(ci, [Vector2(cx + side * 40, neck_y - 6), Vector2(cx + side * 78, neck_y + 2),
				Vector2(cx + side * 60, top + 262 - b), Vector2(cx + side * 8, top + 284 - b)],
				coat.lightened(0.08), coat.darkened(0.45), 2)
	UIKit.rounded(ci, Rect2(cx - 150, top + 262 - b, 44, 30), coat.darkened(0.12), 3, 2, coat.darkened(0.4))  # 口袋
	ci.draw_circle(Vector2(cx - 128, top + 268 - b), 3, Color8(170, 160, 120))

	# 耳朵
	for side in [-1, 1]:
		_ellipse(ci, Vector2(cx + side * (FACE_RX - 3), c.y + 4), 10, 18, skin.darkened(0.06))
		_ellipse(ci, Vector2(cx + side * (FACE_RX - 1), c.y + 4), 5, 11, skin.darkened(0.25))

	# 脸, 右边暗一点 (光从左边来)
	var face := face_points(c)
	ci.draw_colored_polygon(face, skin)
	for inner in [0.62, 0.82]:  # 两层, 边上更暗, 看起来是慢慢暗下去的
		var shade := PackedVector2Array()
		for i in 25:
			var t := -PI / 2 + PI * i / 24
			var s := sin(t)
			var narrow := 1.0 - 0.24 * maxf(0, s) * maxf(0, s)
			shade.append(c + Vector2(cos(t) * FACE_RX * narrow, s * FACE_RY))
		for i in range(24, -1, -1):
			var t := -PI / 2 + PI * i / 24
			var s := sin(t)
			var narrow := 1.0 - 0.24 * maxf(0, s) * maxf(0, s)
			shade.append(c + Vector2(cos(t) * FACE_RX * narrow * inner, s * FACE_RY * 0.96))
		ci.draw_colored_polygon(shade, Color(0, 0, 0, 0.08))
	ci.draw_polyline(face + PackedVector2Array([face[0]]), skin.darkened(0.4), 1.5)

	# 胡茬 (固定的随机数, 每帧画出来都一样)
	if look["stubble"]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var dot := Color(hair.darkened(0.5), 0.45)
		for i in 420:
			var p := Vector2(cx + rng.randf_range(-FACE_RX, FACE_RX), c.y + rng.randf_range(24, FACE_RY))
			var mouth_area := absf(p.x - cx) < 22 and absf(p.y - (c.y + 54)) < 7
			var nose_area := absf(p.x - cx) < 13 and p.y < c.y + 39
			if Geometry2D.is_point_in_polygon(p, face) and not mouth_area and not nose_area:
				ci.draw_rect(Rect2(p.round(), Vector2(1, 1)), dot)

	# 皱纹: 额头两道, 鼻子两边两道, 眼角
	if look["wrinkles"]:
		var line := Color(0, 0, 0, 0.18)
		for k in 2:
			ci.draw_arc(Vector2(cx, c.y + 18 + k * 7), 44, PI * 1.32, PI * 1.68, 12, line, 1.5)
		for side in [-1, 1]:
			ci.draw_polyline(PackedVector2Array([Vector2(cx + side * 13, c.y + 30), Vector2(cx + side * 22, c.y + 44),
					Vector2(cx + side * 25, c.y + 58)]), line, 2)
			ci.draw_line(Vector2(cx + side * 38, c.y - 2), Vector2(cx + side * 45, c.y - 6), line, 1)
			ci.draw_line(Vector2(cx + side * 38, c.y + 2), Vector2(cx + side * 45, c.y + 4), line, 1)

	# 头发: 短头发, 从两边鬓角盖过头顶; 上面一道道发丝
	var hair_pts := PackedVector2Array()
	for i in 25:
		var t := PI + 0.18 + (PI - 0.36) * i / 24.0
		hair_pts.append(c + Vector2(cos(t) * (FACE_RX + 5), sin(t) * (FACE_RY + 8)))
	for p in [Vector2(FACE_RX - 7, -30), Vector2(FACE_RX * 0.5, -48), Vector2(0, -53), Vector2(-FACE_RX * 0.5, -49), Vector2(-FACE_RX + 7, -30)]:
		hair_pts.append(c + p)
	ci.draw_colored_polygon(hair_pts, hair)
	var hr := RandomNumberGenerator.new()
	hr.seed = 11
	for i in 140:
		var p := c + Vector2(hr.randf_range(-FACE_RX, FACE_RX), hr.randf_range(-FACE_RY - 6, -32))
		if Geometry2D.is_point_in_polygon(p, hair_pts):
			var strand := hair.darkened(0.25) if hr.randf() < 0.6 else hair.lightened(0.18)
			ci.draw_line(p, p + Vector2(hr.randf_range(-2, 2), 4), strand, 1)
	ci.draw_polyline(hair_pts + PackedVector2Array([hair_pts[0]]), hair.darkened(0.45), 1.5)

	# 护目镜: 推到额头上
	if look["goggles"]:
		var strap := PackedVector2Array([c + Vector2(-FACE_RX - 5, -24), c + Vector2(-40, -46), c + Vector2(0, -52),
				c + Vector2(40, -46), c + Vector2(FACE_RX + 5, -24)])
		ci.draw_polyline(strap, Color8(46, 38, 30), 10)
		ci.draw_polyline(strap, Color8(70, 58, 44), 6)
		ci.draw_rect(Rect2(cx - 8, c.y - 54, 16, 6), Color8(90, 86, 76))
		for side in [-1, 1]:
			var g := c + Vector2(side * 24, -50)
			ci.draw_circle(g, 17, Color8(52, 48, 42))
			ci.draw_circle(g, 15, Color8(128, 122, 108))
			ci.draw_circle(g, 11, Color8(40, 70, 62))
			ci.draw_circle(g, 11, Color(0.4, 0.8, 0.7, 0.25))
			ci.draw_arc(g, 7, PI * 1.05, PI * 1.6, 8, Color(1, 1, 1, 0.55), 2)

	# 眉毛
	var brow := hair.darkened(0.35)
	for side in [-1, 1]:
		UIKit.poly(ci, [Vector2(cx + side * 9, c.y - 15), Vector2(cx + side * 38, c.y - 21), Vector2(cx + side * 40, c.y - 16),
				Vector2(cx + side * 10, c.y - 10)], brow)

	# 眼睛: 眨眼的时候是一条线
	for side in [-1, 1]:
		var e := Vector2(cx + side * 24, c.y - 2)
		_ellipse(ci, e + Vector2(0, -3), 14, 8, Color(0, 0, 0, 0.12))  # 眼窝
		if blink:
			ci.draw_line(e - Vector2(11, 0), e + Vector2(11, 0), skin.darkened(0.5), 2)
		else:
			_ellipse(ci, e, 11, 6, Color8(222, 214, 196))
			ci.draw_circle(e, 5, look["eyes"])
			ci.draw_circle(e, 2.5, Color8(20, 16, 14))
			ci.draw_circle(e + Vector2(-1.5, -1.5), 1.2, Color(1, 1, 1, 0.85))
			# 上眼皮盖住眼睛上面一截, 不然像瞪着眼
			var lid := PackedVector2Array()
			for k in 9:
				var t := PI + 0.34 + (PI - 0.68) * k / 8.0
				lid.append(e + Vector2(cos(t) * 11.5, sin(t) * 6.5))
			ci.draw_colored_polygon(lid, skin.darkened(0.12))
			ci.draw_line(e + Vector2(-11, -2), e + Vector2(11, -2), skin.darkened(0.6), 2)
			ci.draw_arc(e + Vector2(0, 2), 12, PI * 1.15, PI * 1.85, 10, Color(0, 0, 0, 0.2), 1.5)  # 眼皮上的褶

	# 鼻子
	ci.draw_line(Vector2(cx + 5, c.y + 2), Vector2(cx + 9, c.y + 30), Color(0, 0, 0, 0.16), 4)
	UIKit.poly(ci, [Vector2(cx - 11, c.y + 31), Vector2(cx - 6, c.y + 25), Vector2(cx + 6, c.y + 25),
			Vector2(cx + 11, c.y + 31), Vector2(cx, c.y + 37)], skin.lightened(0.04))
	ci.draw_line(Vector2(cx - 10, c.y + 35), Vector2(cx + 10, c.y + 35), Color(0, 0, 0, 0.28), 2)
	for side in [-1, 1]:
		_ellipse(ci, Vector2(cx + side * 5, c.y + 33), 3, 1.6, Color8(70, 40, 30))

	# 嘴: 说话时张开
	var my := c.y + 54
	if mouth > 0.05:
		var open := 2.0 + 11.0 * mouth
		_ellipse(ci, Vector2(cx, my + open / 3), 17, open / 2, Color8(54, 24, 20))
		ci.draw_rect(Rect2(cx - 11, my + open / 3 - open / 2, 22, minf(3, open / 3)), Color8(212, 204, 184))
	ci.draw_polyline(PackedVector2Array([Vector2(cx - 20, my + 1), Vector2(cx - 8, my - 2), Vector2(cx, my - 1),
			Vector2(cx + 8, my - 2), Vector2(cx + 20, my + 1)]), skin.darkened(0.45), 3)
	ci.draw_line(Vector2(cx - 11, my + 8 + mouth * 9), Vector2(cx + 11, my + 8 + mouth * 9), Color(0, 0, 0, 0.16), 3)  # 下嘴唇的影子

	# 伤疤: 左脸一道, 带缝过的针脚
	if look["scar"]:
		var a := c + Vector2(-46, 8)
		var z := c + Vector2(-31, 40)
		ci.draw_line(a, z, Color8(150, 94, 82), 3)
		for k in 3:
			var m := a.lerp(z, 0.25 + k * 0.25)
			ci.draw_line(m + Vector2(-4, 2), m + Vector2(4, -2), Color8(120, 74, 64), 1)

	_base = Transform2D.IDENTITY
	ci.draw_set_transform_matrix(_base)
	ci.draw_texture_rect(vignette_texture(), rect, false)  # 最后盖一层: 四周暗、脸亮
