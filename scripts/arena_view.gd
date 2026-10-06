class_name ArenaView
extends Control
## 练习场打仗的画面: 斜着看的方格地面、人、排队头像、战斗记录、按钮、瞄准窗口。全部用代码画, 不用图片。
## 鼠标: 点空格子走过去, 点敌人打他, 右键点敌人 (或者先按「瞄准」) 选部位打, 点地上的武器捡起来,
##       点武器格子换单发 / 连发 (冲锋枪)。
## 键盘: 空格 结束回合, R 换子弹, Q 换手, A 瞄准, F 单发 / 连发,
##       打完按回车再来一局、按 S 重新准备, Esc 关掉瞄准窗口 / 退出。

signal setup_requested  ## 打完以后点了「重新准备」
signal quit_requested   ## 按了 Esc (瞄准窗口没开的时候)

const W := 1200
const H := 720
const TILE_W := 64.0       # 一格菱形的宽和高
const TILE_H := 32.0
const PANEL_Y := 540.0     # 下面面板从这里开始 (上面全是地图, 跟原版一样没有顶上那一条)
const ORIGIN := Vector2(W / 2.0, 46)  # 格子 (0, 0) 菱形最上面那个角在画面上的位置

const STEP_TIME := 0.11    # 走一格的动画几秒
const AI_DELAY := 0.3      # 敌人每做一件事之间停几秒, 让玩家看清楚
const HINT_TIME := 2.0     # 提示 (比如「行动点不够」) 显示几秒

const SAND := [Color8(122, 104, 74), Color8(128, 109, 78), Color8(116, 99, 70), Color8(125, 106, 72)]
const TILE_LINE := Color8(100, 85, 61)
const GREEN := Color8(110, 200, 110)
const SIDE_COLORS := {"player": Color8(70, 120, 100), "enemy": Color8(150, 60, 45)}
## 战斗记录的颜色: 跟老式屏幕一样都是绿色系, 坏消息是橙红色
const LOG_COLORS := {"info": Color8(70, 150, 64), "player": Color8(110, 230, 96), "enemy": Color8(196, 214, 84),
		"good": Color8(160, 255, 140), "bad": Color8(240, 110, 70)}
const LOG_LINE := 15.0

## 下面一整条, 照《辐射》二代的摆法和比例 (原版 640×99, 放大到 1200 宽), 从左到右:
const MONITOR := Rect2(8, 545, 384, 170)          # 带螺丝的显示器外框
const LOG_BOX := Rect2(30, 566, 340, 128)         # 里面的绿屏幕: 战斗记录
const SWITCH_AT := Vector2(427, 568)              # 红圆按钮: 换手
const INV_BTN := Rect2(401, 607, 54, 34)          # 背包 (以后才有)
const OPT_AT := Vector2(428, 676)                 # 圆的格栅按钮: 设置 (以后才有)
const ROUND_R := 21.0                             # 圆按钮多大
const CENTER_PLATE := Rect2(462, 544, 400, 172)   # 中间那块板
const AP_STRIP := Rect2(522, 553, 300, 24)        # 一排行动点灯
const WEAPON_SLOT := Rect2(488, 584, 366, 126)    # 大武器格子
const AMMO_BAR := Rect2(488 + 366 - 24, 590, 18, 114)  # 武器格子右边一竖条: 子弹 (点它换子弹)
const HP_BOX := Rect2(876, 604, 92, 38)           # 生命计数器
const DEF_BOX := Rect2(876, 672, 92, 38)          # 防御计数器
const MAP_BTN := Rect2(986, 612, 78, 28)          # 地图 (以后才有)
const CHA_BTN := Rect2(986, 646, 78, 28)          # 角色 (以后才有)
const PAP_BTN := Rect2(986, 680, 78, 28)          # PAP: 个人分析与防护 (以后才有)
const PERK_AT := Vector2(1003, 568)               # 红圆按钮: 特长 (以后才有)
const PERK_PLATE := Rect2(1030, 551, 160, 36)
const END_PANEL := Rect2(1078, 604, 114, 108)     # 结束回合 / 结束战斗
const END_TURN_BTN := Rect2(1078, 604, 114, 54)
const END_COMBAT_BTN := Rect2(1078, 658, 114, 54)
const RECT_BUTTONS := {"inv": INV_BTN, "map": MAP_BTN, "cha": CHA_BTN, "pap": PAP_BTN,
		"end": END_TURN_BTN, "end_combat": END_COMBAT_BTN}
const ROUND_BUTTONS := {"switch": SWITCH_AT, "options": OPT_AT, "perks": PERK_AT}
## 还没做的功能: 按钮先摆上, 点了提示
const LATER := {"inv": "背包: 以后才有", "options": "设置: 以后才有", "map": "地图: 以后才有",
		"cha": "角色: 以后才有", "pap": "PAP (个人分析与防护): 以后才有", "perks": "特长: 以后才有"}

## 地图左上角一小排: 第几轮、排队头像 (原版没有这个, 我们留着, 但缩小了)
const TURN_STRIP := Rect2(8, 8, 300, 46)
# 打完以后的两个按钮
const END_AGAIN := Rect2(W / 2.0 - 230, H / 2.0 + 20, 210, 50)
const END_SETUP := Rect2(W / 2.0 + 20, H / 2.0 + 20, 210, 50)
# 瞄准窗口; 两边的部位按钮: 他的右手、右腿在你的左边 (他是面对着你的)
const AIM_WIN := Rect2(W / 2.0 - 330, 44, 660, 452)
const AIM_FIGURE_TOP := 44.0 + 92
const AIM_CANCEL := Rect2(W / 2.0 + 330 - 22 - 176, 44 + 452 - 50, 176, 36)
const AIM_LEFT := ["head", "right_arm", "torso", "right_leg"]
const AIM_RIGHT := ["eyes", "left_arm", "groin", "left_leg"]
const AIM_ROWS := [AIM_FIGURE_TOP + 22, AIM_FIGURE_TOP + 104, AIM_FIGURE_TOP + 176, AIM_FIGURE_TOP + 246]


## 地面单独一层: 每局只画一次 (Godot 会记住画好的样子, 不用每帧重画)
class GroundLayer:
	extends Control
	var arena: ArenaView

	func _draw() -> void:
		arena.draw_ground(self)


var setup: Practice.Setup
var seed_value := -1      # 测试用: 固定的随机数 (每局在上面加一)
var battle: Battle
var mouse := Vector2.ZERO
var anims: Array = []      # 排着队播的动画 (走路、攻击……), 播完一个再播下一个
var floats: Array = []     # 飘在人头上的字 (「-6」「没打中」)
var facing := {}           # 1 朝右, -1 朝左
var ai_wait := 0.0
var hint := ""
var hint_left := 0.0
var aiming := false        # 按了「瞄准」: 下一次点敌人会弹出瞄准窗口
var aim_target: Unit = null  # 瞄准窗口开着的时候, 瞄的是谁
var hidden_items: Array = []  # 刚掉下来、掉落动画还没播到的武器 (先不画)
## 画面上看到的样子 ([活着没有, 躺着没有]): 挨打的动画播完才改, 不然子弹还没飞到人就先倒了
var pending := {}          # 每个人还有几个跟他有关的动画没播完
var shown := {}
var hovered: Unit = null   # 这一帧鼠标指着的人 (每帧只算一次)
var ground_layer: GroundLayer
var games := 0


func _init(p_setup: Practice.Setup = null, p_seed := -1) -> void:
	setup = p_setup if p_setup != null else Practice.Setup.new()
	seed_value = p_seed
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	ground_layer = GroundLayer.new()
	ground_layer.arena = self
	ground_layer.size = size
	ground_layer.show_behind_parent = true
	ground_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground_layer)
	new_battle()


func new_battle() -> void:
	games += 1
	battle = Practice.make_battle(Dice.new(seed_value + games) if seed_value >= 0 else Dice.new(), setup)
	anims = []
	floats = []
	facing = {}
	pending = {}
	shown = {}
	for u in battle.units:
		facing[u] = 1 if u.side == Unit.PLAYER else -1
		shown[u] = [u.alive(), u.knocked_down or u.knocked_out]
	ai_wait = 0.0
	hint = ""
	aiming = false
	aim_target = null
	hidden_items = []
	battle.say("小提示: 点空地走过去, 点敌人打他, 右键瞄准, 空格结束回合。", "info")
	ground_layer.queue_redraw()


# ---------- 状态 ----------

## 还在播动画 (或者刚发生的事还没排进动画)
func busy() -> bool:
	return not anims.is_empty() or not battle.events.is_empty()


func players_turn() -> bool:
	return battle.result == "" and not busy() and battle.current().side == Unit.PLAYER


func show_hint(words: String) -> void:
	hint = words
	hint_left = HINT_TIME


func player() -> Unit:
	for u in battle.units:
		if u.side == Unit.PLAYER:
			return u
	return null


# ---------- 斜着看的格子: 格子坐标 <-> 画面坐标 ----------

## 格子 (x, y) 菱形最上面那个角在画面上的位置 (x, y 可以是小数, 走路动画用)
static func tile_top(t: Vector2) -> Vector2:
	return ORIGIN + Vector2((t.x - t.y) * TILE_W / 2, (t.x + t.y) * TILE_H / 2)


static func tile_center(t: Vector2) -> Vector2:
	return tile_top(t) + Vector2(0, TILE_H / 2)


static func tile_diamond(t: Vector2) -> PackedVector2Array:
	var p := tile_top(t)
	return PackedVector2Array([p, p + Vector2(TILE_W / 2, TILE_H / 2), p + Vector2(0, TILE_H), p + Vector2(-TILE_W / 2, TILE_H / 2)])


## 画面上的一个点在哪个格子里
static func screen_to_tile(p: Vector2) -> Vector2i:
	var u := (p.x - ORIGIN.x) / (TILE_W / 2)
	var v := (p.y - ORIGIN.y) / (TILE_H / 2)
	return Vector2i(floori((u + v) / 2), floori((v - u) / 2))


# ---------- 鼠标键盘 ----------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse = event.position
	elif event is InputEventMouseButton and event.pressed:
		mouse = event.position
		if event.button_index == MOUSE_BUTTON_LEFT:
			click(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			right_click(event.position)


func press_key(key: Key) -> void:
	if key == KEY_ESCAPE:
		if aim_target != null:  # 先关瞄准窗口, 再关瞄准, 最后才退出
			aim_target = null
		elif aiming:
			aiming = false
		else:
			quit_requested.emit()
	elif battle.result != "":
		if (key == KEY_ENTER or key == KEY_KP_ENTER) and not busy():
			new_battle()
		elif key == KEY_S and not busy():
			setup_requested.emit()
	elif key == KEY_F:
		do_button("burst")
	elif key == KEY_SPACE:
		do_button("end")
	elif key == KEY_R:
		do_button("reload")
	elif key == KEY_Q:
		do_button("switch")
	elif key == KEY_A:
		do_button("aim")


## 现在的攻击方式 (写在武器格子右上角): 单发 / 瞄准 / 连发
func attack_mode() -> String:
	var you := player()
	if you.bursting():
		return "连发"
	if aiming:
		return "瞄准"
	return "单发"


func do_button(which: String) -> void:
	if LATER.has(which):  # 还没做的功能
		show_hint(LATER[which])
		return
	if which == "end_combat":
		if battle.result == "":
			show_hint("敌人还在, 不能结束战斗")
		return
	if not players_turn() or aim_target != null:
		return
	var you := battle.current()
	match which:
		"aim":  # 瞄准模式: 开着的时候, 点敌人就弹出瞄准窗口 (一直开着, 直到你换掉)
			if you.weapon().kind == "throw":
				show_hint("手雷不能瞄准")
			elif you.bursting():
				show_hint("连发不能瞄准 (按 F 换成单发)")
			else:
				aiming = not aiming
				if aiming:
					show_hint("瞄准: 点一个敌人, 选打哪里")
		"burst":
			if you.weapon().burst_ap == 0:
				show_hint("%s不能连发" % you.weapon().name)
			else:
				aiming = false
				battle.toggle_burst(you)
		"mode":  # 点武器格子: 照原版轮着换攻击方式 单发 → 瞄准 → 连发 (这把武器有的才换得到)
			var modes := ["单发"]
			if you.weapon().kind != "throw":
				modes.append("瞄准")
			if you.weapon().burst_ap > 0:
				modes.append("连发")
			var now := attack_mode()
			var nxt: String = modes[(modes.find(now) + 1) % modes.size()]
			if now == "连发" or nxt == "连发":
				battle.toggle_burst(you)
			aiming = nxt == "瞄准"
			if modes.size() == 1:
				show_hint("%s只有一种打法" % you.weapon().name)
		"end":
			battle.end_turn()
		"reload":
			var problem := battle.reload_problem(you)
			if problem != "":
				show_hint(problem)
			else:
				battle.reload(you)
		"switch":
			battle.switch_hand(you)
			aiming = false  # 换了武器, 攻击方式回到单发


## 鼠标点到的是哪个按钮 (没点到返回 "")
func button_at(p: Vector2) -> String:
	for which in ROUND_BUTTONS:
		if p.distance_to(ROUND_BUTTONS[which]) <= ROUND_R + 3:
			return which
	for which in RECT_BUTTONS:
		if RECT_BUTTONS[which].has_point(p):
			return which
	if AMMO_BAR.has_point(p):
		return "reload"
	if WEAPON_SLOT.has_point(p):
		return "mode"
	return ""


func click(p: Vector2) -> void:
	if aim_target != null:
		click_aim_window(p)
		return
	if battle.result != "":
		if not busy() and END_AGAIN.has_point(p):
			new_battle()
		elif not busy() and END_SETUP.has_point(p):
			setup_requested.emit()
		return
	if p.y >= PANEL_Y:
		var which := button_at(p)
		if which != "":
			do_button(which)
		return
	if not players_turn():
		return
	var you := battle.current()
	var target := unit_under(p)
	if target != null:
		if target.side != you.side:
			if aiming:
				open_aim(target)
				return
			var problem := battle.attack_problem(you, target)
			if problem != "":
				show_hint(problem)
			else:
				battle.attack(you, target)
		return
	var tile := screen_to_tile(p)
	if not battle.in_bounds(tile):
		return
	var item := battle.item_at(tile)
	if item != null and not hidden_items.has(item):
		var problem := battle.pickup_problem(you, item)
		if problem == "":
			battle.pickup(you, item)
			return
		if problem != "要走到旁边才能捡":
			show_hint(problem)
			return
	if tile == you.pos:
		return
	var path = battle.find_path(you, tile)
	if path == null:
		show_hint("走不过去")
	elif battle.move_cost(you, path) > you.ap:
		show_hint("行动点不够 (要 %d 点)" % battle.move_cost(you, path))
	else:
		battle.move(you, tile)


## 右键: 关掉瞄准窗口 / 关掉瞄准模式; 或者直接瞄准鼠标下面的敌人
func right_click(p: Vector2) -> void:
	if aim_target != null:
		aim_target = null
		return
	if aiming:
		aiming = false
		return
	if not players_turn():
		return
	var target := unit_under(p)
	if target != null and target.side != battle.current().side:
		open_aim(target)


# ---------- 瞄准窗口 ----------

func open_aim(target: Unit) -> void:
	var you := battle.current()
	if you.bursting():
		show_hint("连发不能瞄准 (按 F 换成单发)")
		return
	if you.weapon().kind == "throw":
		show_hint("手雷不能瞄准")
		return
	aim_target = target


## 瞄准窗口里八个部位按钮的位置: {部位: 方块}
func aim_buttons() -> Dictionary:
	var rects := {}
	for col in [[AIM_LEFT, AIM_WIN.position.x + 22], [AIM_RIGHT, AIM_WIN.end.x - 22 - 176]]:
		for i in 4:
			rects[col[0][i]] = Rect2(col[1], AIM_ROWS[i] - 21, 176, 42)
	return rects


## 鼠标指着的部位 (按钮或者画上的身体)
func aim_part_under(p: Vector2) -> String:
	var buttons := aim_buttons()
	for part in buttons:
		if buttons[part].has_point(p):
			return part
	var parts := UIKit.figure_parts(AIM_WIN.get_center().x, AIM_FIGURE_TOP)
	for part in ["eyes", "head", "right_arm", "left_arm", "groin", "right_leg", "left_leg", "torso"]:
		if parts[part].has_point(p):
			return part
	return ""


func click_aim_window(p: Vector2) -> void:
	if AIM_CANCEL.has_point(p) or not AIM_WIN.has_point(p):
		aim_target = null
		return
	var part := aim_part_under(p)
	if part == "":
		return
	var problem := battle.attack_problem(battle.current(), aim_target, part)
	if problem != "":
		show_hint(problem)
		return
	battle.attack(battle.current(), aim_target, part)
	aim_target = null


## 瞄准窗口的部位按钮放不下长句子, 换个短说法 (鼠标指着时下面会写全)
static func short_reason(problem: String) -> String:
	for pair in [["行动点不够", "点数不够"], ["太远", "太远了"], ["走到旁边", "要走过去"], ["没子弹", "没子弹"],
			["废了", "手废了"], ["两只手", "要两只手"]]:
		if problem.contains(pair[0]):
			return pair[1]
	return problem.left(5)


# ---------- 每一帧更新 ----------

func _process(delta: float) -> void:
	step(minf(delta, 0.1))
	queue_redraw()


## 往前走一小段时间 (测试里可以直接调它, 不用等真的时间)
func step(delta: float) -> void:
	for event in battle.take_events():
		var a := make_anim(event)
		for u in a["affects"]:
			pending[u] = pending.get(u, 0) + 1
		anims.append(a)
	if not anims.is_empty():
		var a: Dictionary = anims[0]
		if not a["started"]:
			a["started"] = true
			start_anim(a)
		a["t"] += delta
		if a["t"] >= a["dur"]:
			anims.pop_front()
			for u in a["affects"]:
				pending[u] -= 1
	for u in battle.units:  # 没有动画在等的人, 画面上就照现在的样子画
		if pending.get(u, 0) <= 0:
			shown[u] = [u.alive(), u.knocked_down or u.knocked_out]
	for f in floats:
		f["t"] += delta
	floats = floats.filter(func(f): return f["t"] < f["delay"] + f["dur"])
	if hint != "":
		hint_left -= delta
		if hint_left <= 0:
			hint = ""
	# 轮到敌人: 等一下做一件事, 没事可做就结束回合
	if battle.result == "" and not busy() and battle.current().side == Unit.ENEMY:
		ai_wait += delta
		if ai_wait >= AI_DELAY:
			ai_wait = 0.0
			if not AI.act(battle, battle.current()):
				battle.end_turn()
	else:
		ai_wait = 0.0


func make_anim(event: Dictionary) -> Dictionary:
	var kind: String = event["kind"]
	var a := {"kind": kind, "t": 0.0, "started": false, "affects": [], "dur": 0.0}  # affects: 挨打的人 (动画播完才倒下)
	match kind:
		"move":
			a["unit"] = event["unit"]
			a["path"] = event["path"]
			a["dur"] = STEP_TIME * (event["path"].size() - 1)
		"attack":
			var r: Battle.AttackResult = event["result"]
			a["result"] = r
			a["dur"] = 0.65 if r.shots > 1 else 0.45
			a["affects"] = [r.target]
			for s in r.strays:
				a["affects"].append(s[0])
		"throw":
			var r: Battle.ThrowResult = event["result"]
			a["result"] = r
			a["dur"] = 0.95
			for v in r.victims:
				a["affects"].append(v[0])
		"drop", "pickup":
			a["unit"] = event["unit"]
			a["item"] = event["item"]
			a["dur"] = 0.3
			if kind == "drop":
				hidden_items.append(event["item"])
		_:  # reload / switch / getup / stunned
			a["unit"] = event["unit"]
			a["dur"] = {"reload": 0.35, "getup": 0.4, "stunned": 0.6}.get(kind, 0.0)
	return a


## 动画开始播的时候: 转身、飘字
func start_anim(a: Dictionary) -> void:
	match a["kind"]:
		"move":
			turn_to(a["unit"], tile_center(a["path"][0]), tile_center(a["path"][-1]))
		"attack":
			var r: Battle.AttackResult = a["result"]
			turn_to(r.attacker, tile_center(r.attacker.pos), tile_center(r.target.pos))
			if r.shots > 1:  # 连发: 写打中他几发; 子弹打中别人, 别人头上也飘字
				if r.hits == 0:
					float_text(r.target, "没打中 (0/%d)" % r.shots, UIKit.TEXT, 0.3)
				else:
					float_text(r.target, "-%d (%d/%d 发)" % [r.damage, r.hits, r.shots], UIKit.YELLOW if r.crit else UIKit.RED, 0.3)
				for s in r.strays:
					float_text(s[0], "-%d" % s[1], UIKit.RED, 0.35)
			elif not r.hit:
				float_text(r.target, "没打中", UIKit.TEXT)
			elif r.crit:
				float_text(r.target, "暴击 -%d" % r.damage, UIKit.YELLOW)
			elif r.damage == 0:
				float_text(r.target, "挡住了", UIKit.DIM)
			else:
				float_text(r.target, "-%d" % r.damage, UIKit.RED)
			if r.effect_short != "":  # 暴击打中部位的效果, 比如「左腿瘸了」
				float_text(r.target, r.effect_short, UIKit.WARN, 0.5)
		"throw":
			var r: Battle.ThrowResult = a["result"]
			turn_to(r.attacker, tile_center(r.attacker.pos), tile_center(r.landing))
			for v in r.victims:
				float_text(v[0], "-%d" % v[1], UIKit.RED, 0.55)
		"reload":
			float_text(a["unit"], "换子弹", UIKit.DIM, 0)
		"drop":
			hidden_items.erase(a["item"])
		"pickup":
			float_text(a["unit"], "捡起来", UIKit.DIM, 0)
		"getup":
			float_text(a["unit"], "爬起来", UIKit.DIM, 0)
		"stunned":
			float_text(a["unit"], "晕着……", UIKit.WARN, 0)


func turn_to(unit: Unit, from: Vector2, to: Vector2) -> void:
	if to.x > from.x + 1:
		facing[unit] = 1
	elif to.x < from.x - 1:
		facing[unit] = -1


func float_text(unit: Unit, words: String, color: Color, delay := 0.12) -> void:
	floats.append({"unit": unit, "text": words, "color": color, "t": 0.0, "delay": delay, "dur": 0.9})


# ---------- 人在画面上的位置 ----------

## 这个人现在画在哪 (格子坐标, 走路动画时是小数)
func unit_tile_pos(unit: Unit) -> Vector2:
	if not anims.is_empty() and anims[0]["kind"] == "move" and anims[0]["unit"] == unit:
		var a: Dictionary = anims[0]
		var path: Array = a["path"]
		var k := minf(a["t"] / STEP_TIME, path.size() - 1)
		var i := mini(int(k), path.size() - 2)
		return Vector2(path[i]).lerp(Vector2(path[i + 1]), k - i)
	for a in anims:  # 还没轮到播的走路动画: 先画在出发的地方
		if a["kind"] == "move" and a["unit"] == unit:
			return Vector2(a["path"][0])
	return Vector2(unit.pos)


## 这个人脚底在画面上的位置
func unit_screen_pos(unit: Unit) -> Vector2:
	var c := tile_center(unit_tile_pos(unit))
	if not anims.is_empty() and anims[0]["kind"] == "attack":
		var a: Dictionary = anims[0]
		var r: Battle.AttackResult = a["result"]
		if r.attacker == unit and Rules.is_close(r.weapon.kind):
			# 近身打: 往对方那边扑一下
			var t := tile_center(Vector2(r.target.pos))
			var push := sin(minf(a["t"] / 0.25, 1) * PI) * 10
			c += (t - c).normalized() * push
	return c


## 鼠标下面的人 (只算活人; 前面的人挡住后面的)
func unit_under(p: Vector2) -> Unit:
	var found: Unit = null
	var best := -1e9
	for u in battle.units:
		if not u.alive():
			continue
		var c := unit_screen_pos(u)
		if Rect2(c.x - 13, c.y - 50, 26, 54).has_point(p):
			var tp := unit_tile_pos(u)
			if tp.x + tp.y > best:
				found = u
				best = tp.x + tp.y
	return found


# ---------- 画 ----------

## 地面 (每格的沙子、石子、裂缝): 画在 GroundLayer 上, 每局只画一次
func draw_ground(ci: CanvasItem) -> void:
	for y in battle.height:
		for x in battle.width:
			var n := (x * 73856093) ^ (y * 19349663)
			var pts := tile_diamond(Vector2(x, y))
			ci.draw_colored_polygon(pts, SAND[n % SAND.size()])
			var outline := pts.duplicate()
			outline.append(pts[0])
			ci.draw_polyline(outline, TILE_LINE)
			var c := tile_center(Vector2(x, y))  # 地上的小石子和裂缝, 每格固定, 不会一闪一闪
			if n % 5 == 0:
				ci.draw_circle(c + Vector2((n % 17) - 8, (n % 7) - 3), 2, Color8(96, 82, 60))
			if n % 11 == 3:
				ci.draw_line(c + Vector2(-10, 2), c + Vector2(4, -3), Color8(100, 86, 62))


func _draw() -> void:
	hovered = unit_under(mouse)
	draw_planning()
	for item in battle.ground:
		if not hidden_items.has(item):
			UIKit.ground_item(self, tile_center(Vector2(item.pos)), item.weapon_id)
	draw_units()
	draw_effects()
	draw_turn_strip()
	draw_status()
	draw_panel()
	if aim_target != null:
		draw_aim_window()
	else:
		draw_tooltip()
		draw_panel_tip()
	if hint != "":
		var at := Vector2(W / 2.0, PANEL_Y - 22)
		for d in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(2, 2)]:
			UIKit.text(self, 20, hint, Color.BLACK, at + d, "center")
		UIKit.text(self, 20, hint, UIKit.AMBER, at, "center")
	if battle.result != "" and not busy():
		draw_end()


## 轮到你的时候: 能走到的格子发绿; 鼠标指着的格子画出要走的路; 拿着手雷指着敌人, 画出会炸到的 3×3
func draw_planning() -> void:
	if not players_turn() or aim_target != null:
		return
	var you := battle.current()
	for tile in battle.reachable(you):
		draw_colored_polygon(tile_diamond(Vector2(tile)), Color(0.47, 0.86, 0.47, 0.16))
	var target := hovered
	if target != null and target.side != you.side and you.weapon().kind == "throw":
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				var tile: Vector2i = target.pos + Vector2i(dx, dy)
				if battle.in_bounds(tile):
					draw_colored_polygon(tile_diamond(Vector2(tile)), Color(1, 0.43, 0.2, 0.27))
	if mouse.y >= PANEL_Y or target != null:
		return
	var tile := screen_to_tile(mouse)
	if not battle.in_bounds(tile) or tile == you.pos:
		return
	var path = battle.find_path(you, tile)
	if path == null:
		return
	var cost := battle.move_cost(you, path)
	var color := GREEN if cost <= you.ap else UIKit.RED
	for i in path.size() - 1:
		draw_circle(tile_center(Vector2(path[i])), 3, color)
	var outline := tile_diamond(Vector2(tile))
	outline.append(outline[0])
	draw_polyline(outline, color, 2)
	UIKit.text(self, 16, "%d 点" % cost, color, tile_center(Vector2(tile)) + Vector2(0, 24), "center")


func draw_units() -> void:
	# 倒下的人先画 (垫在下面), 活人按远近画, 近的挡住远的
	var order := battle.units.duplicate()
	order.sort_custom(func(a: Unit, b: Unit) -> bool:
		var aa: bool = shown[a][0]
		var ba: bool = shown[b][0]
		if aa != ba:
			return not aa
		var ta := unit_tile_pos(a)
		var tb := unit_tile_pos(b)
		return ta.x + ta.y < tb.x + tb.y)
	var hover := hovered if players_turn() else null
	for u in order:
		var alive: bool = shown[u][0]
		var c := unit_screen_pos(u)
		if alive and u == battle.current() and battle.result == "":
			_ring(c, UIKit.YELLOW)
		if u == hover and u.side != battle.current().side:
			_ring(c, UIKit.RED)
		UIKit.person(self, c, UIKit.look_of(u.short), facing[u], u.weapon_id(), alive, shown[u][1])


func _ring(c: Vector2, color: Color) -> void:
	draw_set_transform(c, 0, Vector2(1, 0.47))
	draw_arc(Vector2.ZERO, 17, 0, TAU, 32, color, 2)
	draw_set_transform(Vector2.ZERO)


func draw_effects() -> void:
	var a: Dictionary = anims[0] if not anims.is_empty() else {}
	# 开枪: 一道黄线; 连发是一串, 一发一发地闪
	if a.get("kind") == "attack" and not Rules.is_close(a["result"].weapon.kind):
		var r: Battle.AttackResult = a["result"]
		var att := unit_screen_pos(r.attacker)
		var tgt := unit_screen_pos(r.target)
		var start := att + Vector2(facing[r.attacker] * 15, -26)
		if not r.paths.is_empty():
			for i in r.paths.size():
				var t0 := i * 0.06
				if a["t"] < t0 or a["t"] >= t0 + 0.05:
					continue
				var who: Unit = r.paths[i][1]
				var end := (unit_screen_pos(who) if who != null else tile_center(r.paths[i][0])) + Vector2(0, -26)
				draw_line(start, end, UIKit.YELLOW, 2)
				draw_circle(start, 4, Color8(255, 240, 160))
		elif a["t"] < 0.12:
			var end := tgt + Vector2(0, -26) if r.hit else tgt + Vector2(18, -44)
			draw_line(start, end, UIKit.YELLOW, 2)
			draw_circle(start, 4, Color8(255, 240, 160))
	if a.get("kind") == "throw":
		draw_throw(a)
	for f in floats:
		if f["t"] < f["delay"]:
			continue
		var c := unit_screen_pos(f["unit"])
		var at := c + Vector2(0, -62 - (f["t"] - f["delay"]) * 26)
		UIKit.text(self, 20, f["text"], Color.BLACK, at + Vector2(1, 1), "center")
		UIKit.text(self, 20, f["text"], f["color"], at, "center")


## 手雷: 前半段画它飞过去 (一道弧线), 后半段画 3×3 炸开
func draw_throw(a: Dictionary) -> void:
	var r: Battle.ThrowResult = a["result"]
	var att := unit_screen_pos(r.attacker)
	var land := tile_center(Vector2(r.landing))
	if a["t"] < 0.5:
		var f: float = a["t"] / 0.5
		var start := att + Vector2(0, -30)
		var p := start.lerp(land, f) - Vector2(0, sin(f * PI) * 70)
		draw_circle(p, 5, Color8(60, 80, 40))
		draw_circle(p - Vector2(1, 1), 2, Color8(120, 150, 80))
		return
	var e := minf(1.0, (a["t"] - 0.5) / 0.45)
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var tile: Vector2i = r.landing + Vector2i(dx, dy)
			if battle.in_bounds(tile):
				draw_colored_polygon(tile_diamond(Vector2(tile)), Color(1, 0.59, 0.16, 0.59 * (1 - e)))
	draw_circle(land + Vector2(0, -10), 14 + 70 * e, Color(1, 0.86, 0.47, 0.86 * (1 - e)))
	draw_circle(land + Vector2(0, -10), 8 + 40 * e, Color(1, 0.47, 0.12, 0.78 * (1 - e)))


## 地图左上角一小排: 第几轮、排队头像 (原版没有, 缩小了留着, 免得不知道下一个轮到谁)
func draw_turn_strip() -> void:
	var alive_order := battle.order.filter(func(u: Unit) -> bool: return u.alive())
	var box := Rect2(TURN_STRIP.position, Vector2(82 + alive_order.size() * 44, TURN_STRIP.size.y))
	UIKit.rounded(self, box, Color(0.05, 0.06, 0.04, 0.78), 8, 2, UIKit.METAL_DARK)
	UIKit.text(self, 12, "第 %d 轮" % battle.round_no, UIKit.AMBER, Vector2(box.position.x + 12, box.get_center().y), "midleft")
	var x := box.position.x + 82
	for u in alive_order:
		var now: bool = u == battle.current() and battle.result == ""
		var done := battle.has_acted(u)
		var color: Color = SIDE_COLORS[u.side]
		if done:
			color = color.darkened(0.5)
		var c := Vector2(x, box.position.y + 18)
		draw_circle(c, 12, color)
		draw_arc(c, 12, 0, TAU, 24, UIKit.YELLOW if now else UIKit.METAL_DARK, 2 if now else 1)
		UIKit.text(self, 12, u.short, UIKit.TEXT if not done else UIKit.DIM, c, "center")
		x += 44


## 你身上的伤, 写在地图左上角
func draw_status() -> void:
	var you := player()
	var words := you.statuses()
	if words.is_empty() or not you.alive():
		return
	var line := "你: " + "、".join(words)
	UIKit.text(self, 12, line, Color.BLACK, Vector2(13, TURN_STRIP.end.y + 9))
	UIKit.text(self, 12, line, UIKit.WARN, Vector2(12, TURN_STRIP.end.y + 8))


func draw_panel() -> void:
	var you := player()
	var mine: bool = battle.current() == you and battle.result == ""
	var enabled := players_turn()
	var hot := button_at(mouse) if mouse.y >= PANEL_Y else ""

	# 底板: 一整条生锈的金属
	UIKit.metal(self, Rect2(0, PANEL_Y, W, H - PANEL_Y), 1)
	UIKit.bevel(self, Rect2(0, PANEL_Y, W, H - PANEL_Y), true, 3)
	draw_rect(Rect2(0, H - 10, W, 10), Color(0, 0, 0, 0.25))  # 下边暗一点, 有点厚度

	# 左边: 带螺丝的显示器, 里面是绿字的战斗记录
	UIKit.rounded(self, MONITOR, Color8(124, 114, 92), 16, 3, UIKit.METAL_DARK)
	UIKit.metal(self, MONITOR.grow(-6), 7, Color(1.15, 1.1, 1.0))
	UIKit.rounded(self, MONITOR.grow(-6), Color(0, 0, 0, 0), 12, 2, Color8(160, 148, 120))
	UIKit.rounded(self, LOG_BOX.grow(7), UIKit.METAL_DARK, 14)
	UIKit.crt(self, LOG_BOX)
	for p in [MONITOR.position + Vector2(14, 14), Vector2(MONITOR.end.x - 14, MONITOR.position.y + 14),
			Vector2(MONITOR.position.x + 14, MONITOR.end.y - 14), MONITOR.end - Vector2(14, 14)]:
		UIKit.screw(self, p)
	var inner := LOG_BOX.grow_individual(-12, -8, -12, -8)
	var rows := []
	for m in battle.messages.slice(-14):
		var lines := UIKit.wrap(12, m[0], inner.size.x - 12)
		for i in lines.size():
			rows.append([lines[i], m[1], i == 0])
	var fit := floori(inner.size.y / LOG_LINE)
	rows = rows.slice(maxi(0, rows.size() - fit))
	var y := inner.end.y - rows.size() * LOG_LINE
	for row in rows:
		var color: Color = LOG_COLORS.get(row[1], UIKit.GREEN)
		if row[2]:
			draw_rect(Rect2(inner.position.x, y + 5, 4, 4), color)  # 原版每句话前面一个小方点
		UIKit.text(self, 12, row[0], color, Vector2(inner.position.x + 9, y), "topleft", true)
		y += LOG_LINE

	# 红圆按钮: 换手; 背包; 圆格栅按钮: 设置
	UIKit.red_button(self, SWITCH_AT, ROUND_R, enabled and hot == "switch")
	_plate_button(INV_BTN, "背包", hot == "inv")
	draw_circle(OPT_AT + Vector2(2, 2), ROUND_R + 2, UIKit.METAL_DARK)
	draw_circle(OPT_AT, ROUND_R + 2, Color8(130, 120, 96) if hot == "options" else Color8(104, 96, 76))
	draw_circle(OPT_AT, ROUND_R - 3, Color8(48, 44, 36))
	for i in range(-3, 4):  # 格栅
		var dy := i * 5.0
		var half := sqrt(maxf(0, (ROUND_R - 6) * (ROUND_R - 6) - dy * dy))
		draw_line(OPT_AT + Vector2(-half, dy), OPT_AT + Vector2(half, dy), Color8(96, 90, 72), 2)

	# 中间那块板: 一排行动点灯 + 大武器格子
	UIKit.metal(self, CENTER_PLATE, 8, Color(0.82, 0.8, 0.76))
	UIKit.bevel(self, CENTER_PLATE, true, 3)
	UIKit.slot(self, AP_STRIP)
	UIKit.screw(self, Vector2(AP_STRIP.position.x - 14, AP_STRIP.get_center().y), 6)
	UIKit.screw(self, Vector2(AP_STRIP.end.x + 14, AP_STRIP.get_center().y), 6)
	for i in 10:  # 轮到你: 剩几点亮几盏绿灯; 轮到别人: 红灯
		var c := Vector2(AP_STRIP.position.x + 21 + i * 28.5, AP_STRIP.get_center().y)
		if mine:
			UIKit.lamp(self, c, i < you.ap, UIKit.GREEN, 6)
		else:
			UIKit.lamp(self, c, battle.result == "", UIKit.LAMP_RED, 6)
	UIKit.slot(self, WEAPON_SLOT)
	draw_rect(WEAPON_SLOT.grow(-3), Color8(40, 38, 32))
	if hot == "mode" and enabled:
		draw_rect(WEAPON_SLOT.grow(-3), Color(1, 1, 1, 0.05))
	var w := you.weapon()
	UIKit.weapon_picture(self, WEAPON_SLOT.get_center() + Vector2(-4, 8), you.weapon_id())
	var sp := WEAPON_SLOT.position
	var hand_label: String = Unit.HAND_NAMES[you.active]
	var hand_color := UIKit.DIM
	if you.arms_crippled() == 2:
		hand_label = "两只手都废了"
		hand_color = UIKit.ORANGE
	elif not you.hand_ok(you.active):
		hand_label = "%s废了" % Unit.HAND_NAMES[you.active]
		hand_color = UIKit.ORANGE
	UIKit.text(self, 12, "%s · %s" % [hand_label, w.name], hand_color, sp + Vector2(10, 8))
	var other: String = you.hands[1 - you.active]
	UIKit.text(self, 12, "另一只手: %s" % Gear.WEAPONS[other if other != "" else "fist"].name, UIKit.DIM, sp + Vector2(10, 24))
	# 右上角: 攻击方式 (跟原版一样, 点格子轮着换); 左下角: 花几点
	UIKit.text(self, 24, attack_mode(), UIKit.AMBER, Vector2(AMMO_BAR.position.x - 8, sp.y + 6), "topright")
	var cost := battle.attack_cost(you, "torso" if aiming else "")
	UIKit.text(self, 24, "%d 点" % cost, UIKit.AMBER, Vector2(sp.x + 10, WEAPON_SLOT.end.y - 32))
	if w.kind == "throw":
		UIKit.text(self, 12, "还有 %d 个" % you.ammo_in_hand(), UIKit.AMBER, Vector2(AMMO_BAR.position.x - 8, WEAPON_SLOT.end.y - 8), "bottomright")
	if w.magazine > 0:  # 右边一竖条: 枪里还有几发 (点它换子弹)
		draw_rect(AMMO_BAR, Color8(24, 22, 18))
		var seg_h := (AMMO_BAR.size.y - 4) / w.magazine
		for i in w.magazine:
			var r := Rect2(AMMO_BAR.position.x + 3, AMMO_BAR.end.y - 2 - (i + 1) * seg_h, 12, maxf(1, seg_h - (1 if seg_h >= 3 else 0)))
			draw_rect(r, UIKit.AMBER if i < you.ammo_in_hand() else Color8(60, 52, 30))
		if hot == "reload" and enabled:
			draw_rect(AMMO_BAR, UIKit.YELLOW, false, 1)
		UIKit.text(self, 12, "备用 %d" % you.spare.get(you.weapon_id(), 0), UIKit.DIM,
				Vector2(AMMO_BAR.position.x - 8, WEAPON_SLOT.end.y - 8), "bottomright")

	# 生命、防御: 原版那种数字计数器
	var hp_color := Color8(240, 70, 50) if you.hp * 3 < you.max_hp else Color8(232, 226, 210)
	for c in [["生命", you.hp, hp_color, HP_BOX], ["防御", you.defense(), Color8(232, 226, 210), DEF_BOX]]:
		var box: Rect2 = c[3]
		UIKit.text(self, 12, c[0], UIKit.AMBER, Vector2(box.get_center().x, box.position.y - 10), "center")
		_counter(box, c[1], c[2])

	# 地图 / 角色 / PAP
	_plate_button(MAP_BTN, "地图", hot == "map")
	_plate_button(CHA_BTN, "角色", hot == "cha")
	_plate_button(PAP_BTN, "PAP", hot == "pap")

	# 红圆按钮 + 特长的牌子
	UIKit.red_button(self, PERK_AT, ROUND_R, hot == "perks")
	UIKit.rounded(self, PERK_PLATE, Color8(40, 36, 30), 4, 2, Color8(110, 100, 80))
	draw_line(Vector2(PERK_AT.x + ROUND_R + 2, PERK_AT.y), Vector2(PERK_PLATE.position.x, PERK_AT.y), Color8(40, 36, 30), 3)
	UIKit.text(self, 24, "特长", Color8(220, 206, 170), PERK_PLATE.get_center(), "center")

	# 结束回合 / 结束战斗: 深色面板, 四个角有绿灯
	UIKit.rounded(self, END_PANEL, Color8(30, 34, 26), 6, 3, Color8(110, 100, 80))
	draw_line(Vector2(END_PANEL.position.x + 8, END_TURN_BTN.end.y), Vector2(END_PANEL.end.x - 8, END_TURN_BTN.end.y), Color8(70, 66, 52), 2)
	for corner in [END_PANEL.position + Vector2(7, 7), Vector2(END_PANEL.end.x - 7, END_PANEL.position.y + 7),
			Vector2(END_PANEL.position.x + 7, END_PANEL.end.y - 7), END_PANEL.end - Vector2(7, 7)]:
		UIKit.lamp(self, corner, enabled, UIKit.GREEN, 3)
	if enabled and hot == "end":
		draw_rect(END_TURN_BTN.grow(-5), Color(1, 1, 1, 0.06))
	UIKit.text(self, 24, "结束回合", UIKit.AMBER if enabled else UIKit.DIM, END_TURN_BTN.get_center() + Vector2(0, -3), "center")
	UIKit.text(self, 12, "空格", UIKit.DIM, END_TURN_BTN.get_center() + Vector2(0, 17), "center")
	UIKit.text(self, 24, "结束战斗", UIKit.DIM, END_COMBAT_BTN.get_center(), "center")


## 鼠标指着面板上的按钮: 一句说明 (原版按钮上没写字的地方, 靠这个知道是干什么的)
const PANEL_TIPS := {
	"switch": "换手 (Q): 换用另一只手的武器", "mode": "点这里换攻击方式: 单发 → 瞄准 → 连发 (A 瞄准, F 连发)",
	"reload": "换子弹 (R): 花 2 点", "end": "结束回合 (空格)", "end_combat": "结束战斗: 敌人都没了才能用",
}


func draw_panel_tip() -> void:
	if mouse.y < PANEL_Y or aim_target != null or (battle.result != "" and not busy()):
		return
	var which := button_at(mouse)
	if which == "":
		return
	var words: String = PANEL_TIPS.get(which, LATER.get(which, ""))
	if which == "end" or which == "mode" or which == "reload" or which == "switch":
		var you := player()
		if which == "reload" and you.weapon().magazine == 0:
			return
		if which == "end" and players_turn():
			words += ": 还剩 %d 点会变成防御 (+%d)" % [you.ap, you.ap * 2]
	var size := UIKit.text_size(12, words) + Vector2(20, 12)
	var box := Rect2(Vector2(clampf(mouse.x - size.x / 2, 4, W - size.x - 4), PANEL_Y - size.y - 6), size)
	UIKit.crt(self, box)
	UIKit.text(self, 12, words, UIKit.GREEN, box.get_center(), "center", true)


## 原版那种深色小按钮 (背包、地图、角色、PAP)
func _plate_button(rect: Rect2, label: String, hover: bool) -> void:
	draw_rect(rect, Color8(64, 58, 46) if hover else Color8(46, 42, 34))
	UIKit.bevel(self, rect, true, 2)
	UIKit.text(self, 12, label, Color8(220, 206, 170) if hover else Color8(176, 164, 134), rect.get_center(), "center")


## 原版那种数字计数器: 黑底, 三个数字各占一格
func _counter(box: Rect2, value: int, color: Color) -> void:
	UIKit.slot(self, box)
	var digits := "%03d" % clampi(value, 0, 999)
	var cell := (box.size.x - 10) / 3.0
	for i in 3:
		var r := Rect2(box.position.x + 5 + i * cell, box.position.y + 5, cell - 2, box.size.y - 10)
		draw_rect(r, Color8(14, 14, 12))
		draw_line(Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y), Color(0, 0, 0, 0.6), 1)
		UIKit.text(self, 24, digits[i], color, r.get_center(), "center")


## 鼠标指着敌人: 显示生命、命中几率、花几点, 打不了就说为什么; 指着地上的武器: 是什么、能不能捡
func draw_tooltip() -> void:
	if not players_turn():
		return
	var you := battle.current()
	var target := hovered
	var lines := []
	if target == null:
		lines = item_tooltip()
	elif target.side == you.side:
		return
	else:
		lines = [["%s  生命 %d/%d" % [target.name, target.hp, target.max_hp], UIKit.GREEN],
				["%s · %s" % [target.weapon().name, target.armor.name], UIKit.GREEN_DIM]]
		if not target.statuses().is_empty():
			lines.append(["、".join(target.statuses()), UIKit.WARN])
		var problem := battle.attack_problem(you, target)
		if aiming:
			lines.append(["点他, 选打哪里", UIKit.AMBER])
		elif problem != "":
			lines.append([problem, UIKit.ORANGE])
		elif you.bursting():
			var shots := mini(Rules.BURST_ROUNDS, you.ammo_in_hand())
			var split := Rules.burst_split(shots)
			lines.append(["每发命中 %d%% · 花 %d 点" % [battle.hit_chance(you, target), battle.attack_cost(you)], UIKit.AMBER])
			lines.append(["连发 %d 发: %d 发对准他, %d 发往两边散" % [shots, split[0], split[1] + split[2]], UIKit.GREEN_DIM])
		elif you.weapon().kind == "throw":
			lines.append(["命中 %d%% · 花 %d 点 · 炸 3×3" % [battle.hit_chance(you, target), battle.attack_cost(you)], UIKit.AMBER])
			if Rules.distance(you.pos, target.pos) <= Rules.BLAST_RADIUS:
				lines.append(["小心: 你也在爆炸范围里!", UIKit.ORANGE])
		else:
			lines.append(["命中 %d%% · 花 %d 点" % [battle.hit_chance(you, target), battle.attack_cost(you)], UIKit.AMBER])
	if lines.is_empty():
		return
	var width := 0.0
	for l in lines:
		width = maxf(width, UIKit.text_size(16, l[0]).x)
	var box := Rect2(mouse.x + 18, mouse.y - lines.size() * 21 - 22, width + 24, lines.size() * 21 + 16)
	box.position.x = clampf(box.position.x, 0, W - box.size.x)
	box.position.y = clampf(box.position.y, 0, PANEL_Y - box.size.y)
	UIKit.crt(self, box)
	for i in lines.size():
		UIKit.text(self, 16, lines[i][0], lines[i][1], box.position + Vector2(12, 8 + i * 21), "topleft", true)


func item_tooltip() -> Array:
	if mouse.y >= PANEL_Y:
		return []
	var item := battle.item_at(screen_to_tile(mouse))
	if item == null or hidden_items.has(item):
		return []
	var w: Gear.Weapon = Gear.WEAPONS[item.weapon_id]
	var first := "地上: %s" % w.name
	if w.magazine > 0:
		first += " (%d 发)" % item.loaded
	elif w.kind == "throw":
		first += " (%d 个)" % item.loaded
	var lines := [[first, UIKit.GREEN]]
	var problem := battle.pickup_problem(battle.current(), item)
	if problem == "要走到旁边才能捡":
		lines.append(["点这里走过去, 到旁边再点一下捡起来", UIKit.GREEN_DIM])
	elif problem != "":
		lines.append([problem, UIKit.ORANGE])
	else:
		lines.append(["点一下捡起来 · 花 %d 点" % Rules.PICKUP_AP, UIKit.AMBER])
	return lines


## 瞄准窗口: 中间画敌人, 两边八个部位, 写着每个部位的命中几率
func draw_aim_window() -> void:
	var you := battle.current()
	var target := aim_target
	UIKit.metal(self, AIM_WIN, 3)
	UIKit.bevel(self, AIM_WIN, true, 3)
	UIKit.rivets(self, AIM_WIN, 10)
	UIKit.crt(self, Rect2(AIM_WIN.position + Vector2(22, 16), Vector2(AIM_WIN.size.x - 44, 44)))
	UIKit.crt(self, Rect2(AIM_WIN.get_center().x - 100, AIM_FIGURE_TOP - 26, 200, 334))
	UIKit.text(self, 20, "瞄准: %s" % target.name, UIKit.GREEN, Vector2(AIM_WIN.position.x + 34, AIM_WIN.position.y + 38), "midleft", true)
	UIKit.text(self, 16, "%s · 瞄准要花 %d 点 (还剩 %d 点)" % [you.weapon().name, battle.attack_cost(you, "torso"), you.ap],
			UIKit.AMBER, Vector2(AIM_WIN.end.x - 34, AIM_WIN.position.y + 38), "midright", true)
	var hover := aim_part_under(mouse)
	var parts := UIKit.figure(self, AIM_WIN.get_center().x, AIM_FIGURE_TOP, UIKit.look_of(target.short),
			target.crippled, target.blind, hover)
	var buttons := aim_buttons()
	for part in buttons:
		var rect: Rect2 = buttons[part]
		var problem := battle.attack_problem(you, target, part)
		var on: bool = part == hover
		var on_left := rect.get_center().x < AIM_WIN.get_center().x  # 按钮在左边, 线就连到这个部位的左边
		var pr: Rect2 = parts[part]
		var anchor := Vector2(pr.position.x, pr.get_center().y) if on_left else Vector2(pr.end.x, pr.get_center().y)
		if part == "head":
			anchor = Vector2(pr.position.x + 2, pr.get_center().y - 8)
		var start := Vector2(rect.end.x, rect.get_center().y) if on_left else Vector2(rect.position.x, rect.get_center().y)
		draw_line(start, anchor, UIKit.AMBER if on else UIKit.GREEN_DIM, 2 if on else 1)
		UIKit.rounded(self, rect, Color8(40, 52, 30) if on else UIKit.SCREEN_BG, 6, 2, UIKit.AMBER if on else UIKit.GREEN_DIM)
		UIKit.text(self, 19, Rules.part_name(part), UIKit.GREEN, Vector2(rect.position.x + 12, rect.get_center().y), "midleft", true)
		if problem != "":
			UIKit.text(self, 14, short_reason(problem), UIKit.ORANGE, Vector2(rect.end.x - 12, rect.get_center().y), "midright")
		else:
			UIKit.text(self, 20, "%d%%" % battle.hit_chance(you, target, part), UIKit.AMBER,
					Vector2(rect.end.x - 12, rect.get_center().y), "midright", true)
	if hover != "":
		var problem := battle.attack_problem(you, target, hover)
		var at := Vector2(AIM_WIN.position.x + 34, AIM_CANCEL.get_center().y)
		if problem != "":  # 打不了: 把原因写全
			UIKit.text(self, 16, problem, UIKit.ORANGE, at, "midleft", true)
		else:
			var bonus := Rules.aim_crit_bonus(hover)
			var words := "暴击几率 %d%%" % battle.crit_chance(you, hover)
			if bonus > 0:
				words += " (瞄准这里多 %d%%)" % bonus
			UIKit.text(self, 16, words, UIKit.GREEN, at, "midleft", true)
	UIKit.metal_button(self, AIM_CANCEL, AIM_CANCEL.has_point(mouse))
	UIKit.text(self, 17, "取消 (Esc / 右键)", UIKit.AMBER, AIM_CANCEL.get_center(), "center")


func draw_end() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.59))
	var won := battle.result == "won"
	UIKit.text(self, 48, "你赢了!" if won else "你倒下了……", GREEN if won else UIKit.RED, Vector2(W / 2.0, H / 2.0 - 40), "center")
	for b in [[END_AGAIN, "再来一局 (回车)"], [END_SETUP, "重新准备 (S)"]]:
		var rect: Rect2 = b[0]
		UIKit.metal_button(self, rect, rect.has_point(mouse))
		UIKit.bevel(self, rect, true, 3)
		UIKit.text(self, 19, b[1], UIKit.AMBER, rect.get_center(), "center")
	UIKit.text(self, 15, "Esc 退出", UIKit.DIM, Vector2(W / 2.0, END_AGAIN.end.y + 26), "center")
