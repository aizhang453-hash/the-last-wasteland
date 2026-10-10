class_name SetupView
extends Control
## 开打前的「准备」画面: 照《辐射》二代建角色那一页的感觉 (左边能力值加加减减, 中间算出来的数, 右边挑东西)。
## - 救世主系统六项, 每项 1～10 分, 一开始每项 1 分, 再分 18 点
## - 右手、左手拿什么 (8 种武器), 穿什么护甲 (3 种)
## - 鼠标指着什么, 下面的绿屏幕就说明什么
## - 「找教官说话」: 试一试跟人说话 (画面在 dialogue_view.gd)

signal start_requested  ## 点了「开打」, 点数也分完了
signal talk_requested   ## 点了「找教官说话」

const W := 1200
const H := 720
const TITLE := Rect2(20, 14, W - 40, 50)
const STATS_BOX := Rect2(20, 78, 400, 532)
const DERIVED_BOX := Rect2(436, 78, 336, 300)
const HELP_BOX := Rect2(436, 390, 336, 220)
const GEAR_BOX := Rect2(788, 78, 392, 532)
const RESET_BTN := Rect2(20, 628, 170, 64)
const TALK_BTN := Rect2(206, 628, 190, 64)
const START_BTN := Rect2(W - 220, 624, 200, 76)

const STAT_LETTERS := {"survival": "S", "agility": "A", "vigor": "V", "intellect": "I", "observation": "O", "resolve": "R"}
const STAT_HELP := {
	"survival": "适应: 在废土上活下去的本事。抗毒、抗辐射、抗病、耐饥渴、伤好得快。练习场里还用不到。",
	"agility": "灵巧: 每回合的行动点数 (5 + 灵巧 ÷ 2), 用枪的命中 (每分 +5%), 近身的命中 (每分 +3%), 还有防御。",
	"vigor": "体魄: 生命值 (15 + 体魄 × 3), 近身的命中 (每分 +2%) 和伤害 (加 体魄 ÷ 2), 手雷扔多远 (体魄 × 2 格)。大锤要体魄 6, 步枪要 4 (不够会怎样以后再定)。",
	"intellect": "学识: 医疗、科学、破解、修东西、聪明的对话选项。练习场里还用不到。",
	"observation": "洞察: 谁先动 (反应值), 远处打得准 (洞察几分, 就几格之内不扣命中), 暴击几率 (洞察 × 2)。",
	"resolve": "意志: 扛压力、说服人、能带几个同伴。练习场里还用不到。",
}
const KIND_NAMES := {"unarmed": "空手", "melee": "近身武器", "gun": "枪", "throw": "投掷"}

var setup: Practice.Setup
var mouse := Vector2.ZERO
var hint := ""


func _init(p_setup: Practice.Setup = null) -> void:
	setup = p_setup if p_setup != null else Practice.Setup.new()
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(_delta: float) -> void:
	queue_redraw()


# ---------- 位置 ----------

func row_y(i: int) -> float:
	return STATS_BOX.position.y + 70 + i * 66


## {[能力值, -1 或 +1]: 方块}
func stat_buttons() -> Dictionary:
	var rects := {}
	for i in Rules.STAT_ORDER.size():
		var stat: String = Rules.STAT_ORDER[i]
		rects[[stat, -1]] = Rect2(STATS_BOX.position.x + 294, row_y(i) - 18, 40, 36)
		rects[[stat, 1]] = Rect2(STATS_BOX.position.x + 342, row_y(i) - 18, 40, 36)
	return rects


func stat_rows() -> Dictionary:
	var rects := {}
	for i in Rules.STAT_ORDER.size():
		rects[Rules.STAT_ORDER[i]] = Rect2(STATS_BOX.position.x + 10, row_y(i) - 30, STATS_BOX.size.x - 20, 60)
	return rects


## {["hand", 0 或 1, 武器] 或 ["armor", 护甲]: 方块}
func gear_buttons() -> Dictionary:
	var rects := {}
	for hand in 2:
		var top := GEAR_BOX.position.y + 52 + hand * 168
		for i in Gear.CHOICES.size():
			rects[["hand", hand, Gear.CHOICES[i]]] = Rect2(GEAR_BOX.position.x + 14 + (i % 4) * 92,
					top + floori(i / 4.0) * 50, 86, 42)
	for i in Gear.ARMOR_ORDER.size():
		rects[["armor", Gear.ARMOR_ORDER[i]]] = Rect2(GEAR_BOX.position.x + 14 + i * 124, GEAR_BOX.position.y + 400, 116, 44)
	return rects


# ---------- 鼠标键盘 ----------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		mouse = event.position
		click(event.position)


func click(p: Vector2) -> void:
	var sb := stat_buttons()
	for key in sb:
		if sb[key].has_point(p):
			var stat: String = key[0]
			var delta: int = key[1]
			if setup.change(stat, delta):
				hint = ""
			elif delta > 0 and setup.stats[stat] < Practice.MAX_STAT:
				hint = "点数分完了, 先减掉别的"
			elif delta < 0:
				hint = "%s最低 %d 分" % [Rules.STAT_NAMES[stat], Practice.MIN_STAT]
			else:
				hint = "%s最高 %d 分" % [Rules.STAT_NAMES[stat], Practice.MAX_STAT]
			return
	var gb := gear_buttons()
	for key in gb:
		if gb[key].has_point(p):
			if key[0] == "hand":
				setup.hands[key[1]] = key[2]
			else:
				setup.armor = key[1]
			return
	if RESET_BTN.has_point(p):
		setup.reset()
		hint = ""
	elif TALK_BTN.has_point(p):
		talk_requested.emit()
	elif START_BTN.has_point(p):
		start()


## 回车 = 开打
func press_enter() -> void:
	start()


func start() -> void:
	if not setup.ready():
		hint = "还有 %d 点没分完" % setup.points_left()
		return
	start_requested.emit()


# ---------- 说明 ----------

static func weapon_help(wid: String) -> String:
	var w: Gear.Weapon = Gear.WEAPONS[wid]
	if wid == "fist":
		return "拳头: 手里不拿东西。伤害 1～3, 打一下 3 点, 只能打挨着的人, 伤害再加 体魄 ÷ 2。"
	var words := "%s: %s, %s。伤害 %d～%d, 打一下 %d 点。" % [w.name, KIND_NAMES[w.kind],
			"双手" if w.hands == 2 else "单手", w.dmg_min, w.dmg_max, w.ap]
	if w.kind == "melee":
		words += "只能打挨着的人, 伤害再加 体魄 ÷ 2。"
	elif w.kind == "gun":
		words += "射程 %d 格。弹夹 %d 发, 备用子弹 %d 发。" % [w.reach, w.magazine, Gear.SPARE_AMMO.get(wid, 0)]
	if w.accuracy != 0:
		words += "准头 %s%d%%。" % ["+" if w.accuracy > 0 else "", w.accuracy]
	if w.burst_ap > 0:
		var split := Rules.burst_split(Rules.BURST_ROUNDS)
		words += "可以连发: 一次 %d 发, 花 %d 点, %d 发对准、%d 发往两边散, 不能瞄准。" % [
				Rules.BURST_ROUNDS, w.burst_ap, split[0], split[1] + split[2]]
	if w.kind == "throw":
		words += "一次带 %d 个。扔多远看体魄 (体魄 × 2 格), 炸 3×3, 范围里的人都受伤, 包括你自己。扔偏了会落到旁边。" % Gear.GRENADES
	if w.vigor_req > 0:
		words += "要体魄 %d。" % w.vigor_req
	return words


static func armor_help(aid: String) -> String:
	var a: Gear.Armor = Gear.ARMORS[aid]
	if aid == "none":
		return "没穿护甲: 什么都不挡, 不过也不占地方。"
	return "%s: 防御 +%d (更难被打中), 先挡掉 %d 点伤害, 剩下的再挡 %d%%。" % [a.name, a.defense, a.threshold, a.resist]


## 鼠标指着的东西的说明
func hovered_help() -> String:
	var sb := stat_buttons()
	for key in sb:
		if sb[key].has_point(mouse):
			return STAT_HELP[key[0]]
	var rows := stat_rows()
	for stat in rows:
		if rows[stat].has_point(mouse):
			return STAT_HELP[stat]
	var gb := gear_buttons()
	for key in gb:
		if gb[key].has_point(mouse):
			return weapon_help(key[2]) if key[0] == "hand" else armor_help(key[1])
	if TALK_BTN.has_point(mouse):
		return "找教官说话 (T): 试一试跟人说话。学识、意志不一样, 能说的话也不一样; 说着说着也可能直接开打。"
	return "鼠标指着能力值、武器或者护甲, 这里会说明它管什么。"


# ---------- 画 ----------

func _draw() -> void:
	var s := setup
	UIKit.metal(self, Rect2(0, 0, W, H), 4)
	UIKit.bevel(self, Rect2(0, 0, W, H), true, 3)
	for x in [8, W - 9]:
		for y in [8, H - 9]:
			UIKit.rivet(self, Vector2(x, y))
	UIKit.crt(self, TITLE)
	UIKit.slot(self, STATS_BOX)
	UIKit.slot(self, GEAR_BOX)
	UIKit.crt(self, DERIVED_BOX)
	UIKit.crt(self, HELP_BOX)
	UIKit.bevel(self, START_BTN.grow(5), true, 3)

	UIKit.text(self, 22, "练习场 · 开打前的准备", UIKit.GREEN, Vector2(TITLE.position.x + 20, TITLE.get_center().y), "midleft", true)
	var note := hint if hint != "" else "每项先给 1 分, 再分 18 点; 分完了就能开打"
	UIKit.text(self, 16, note, UIKit.AMBER if hint != "" else UIKit.GREEN_DIM,
			Vector2(TITLE.end.x - 20, TITLE.get_center().y), "midright", true)

	# 左边: 救世主系统
	UIKit.text(self, 22, "救世主系统", UIKit.AMBER, STATS_BOX.position + Vector2(18, 16))
	var title_w := UIKit.text_size(22, "救世主系统").x
	UIKit.text(self, 14, "S.A.V.I.O.R.", Color8(150, 140, 110), STATS_BOX.position + Vector2(30 + title_w, 26))
	var rows := stat_rows()
	for i in Rules.STAT_ORDER.size():
		var stat: String = Rules.STAT_ORDER[i]
		var y := row_y(i)
		if rows[stat].has_point(mouse):
			draw_rect(rows[stat], Color8(52, 48, 38))
		UIKit.text(self, 14, STAT_LETTERS[stat], Color8(150, 140, 110), Vector2(STATS_BOX.position.x + 20, y - 9))
		UIKit.text(self, 26, Rules.STAT_NAMES[stat], UIKit.AMBER, Vector2(STATS_BOX.position.x + 46, y - 16))
		var box := Rect2(STATS_BOX.position.x + 200, y - 22, 80, 44)
		UIKit.slot(self, box)
		UIKit.text(self, 28, "%02d" % s.stats[stat], UIKit.AMBER, box.get_center(), "center")
	var sb := stat_buttons()
	for key in sb:
		var rect: Rect2 = sb[key]
		UIKit.metal_button(self, rect, rect.has_point(mouse))
		# 加号减号用线画 (有的字体没有减号, 会显示成方块)
		var c := rect.get_center()
		draw_line(c - Vector2(8, 0), c + Vector2(8, 0), UIKit.AMBER, 3)
		if key[1] > 0:
			draw_line(c - Vector2(0, 8), c + Vector2(0, 8), UIKit.AMBER, 3)
	var left_box := Rect2(STATS_BOX.position.x + 200, STATS_BOX.end.y - 62, 80, 44)
	UIKit.text(self, 20, "还能分", UIKit.AMBER, Vector2(STATS_BOX.position.x + 46, left_box.position.y + 10))
	UIKit.slot(self, left_box)
	var left := s.points_left()
	UIKit.text(self, 28, "%02d" % left, Color8(240, 90, 60) if left != 0 else UIKit.AMBER, left_box.get_center(), "center")

	# 中间: 算出来的数
	var st := s.stats
	var armor: Gear.Armor = Gear.ARMORS[s.armor]
	var derived := [
		["生命", str(Rules.max_hp(st["vigor"]))],
		["行动点", str(Rules.action_points(st["agility"]))],
		["反应 (谁先动)", str(Rules.reaction(st["observation"]))],
		["用枪命中起点", "%d%%" % (40 + st["agility"] * 5)],
		["近身命中起点", "%d%%" % (40 + st["agility"] * 3 + st["vigor"] * 2)],
		["近身伤害", "+%d" % Rules.melee_bonus(st["vigor"])],
		["暴击几率", "%d%%" % Rules.crit_chance(st["observation"])],
		["几格内不扣命中", "%d 格" % st["observation"]],
		["手雷扔多远", "%d 格" % Rules.throw_range(st["vigor"])],
		["防御", str(Rules.defense(st["agility"], armor.defense, 0))],
	]
	var y := DERIVED_BOX.position.y + 16
	for d in derived:
		UIKit.text(self, 17, d[0], UIKit.GREEN, Vector2(DERIVED_BOX.position.x + 20, y), "topleft", true)
		UIKit.text(self, 17, d[1], UIKit.GREEN, Vector2(DERIVED_BOX.end.x - 20, y), "topright", true)
		y += 27

	# 说明
	y = HELP_BOX.position.y + 16
	var lines := UIKit.wrap(16, hovered_help(), HELP_BOX.size.x - 40, false)
	for i in mini(lines.size(), 9):
		UIKit.text(self, 16, lines[i], UIKit.GREEN, Vector2(HELP_BOX.position.x + 20, y), "topleft", true)
		y += 22

	# 右边: 右手、左手、护甲
	UIKit.text(self, 20, "右手", UIKit.AMBER, GEAR_BOX.position + Vector2(16, 18))
	UIKit.text(self, 20, "左手", UIKit.AMBER, GEAR_BOX.position + Vector2(16, 18 + 168))
	UIKit.text(self, 20, "护甲", UIKit.AMBER, GEAR_BOX.position + Vector2(16, 366))
	var gb := gear_buttons()
	for key in gb:
		var rect: Rect2 = gb[key]
		var chosen: bool
		var label: String
		if key[0] == "hand":
			chosen = s.hands[key[1]] == key[2]
			label = "空手" if key[2] == "fist" else Gear.WEAPONS[key[2]].name
		else:
			chosen = s.armor == key[1]
			label = Gear.ARMORS[key[1]].name
		UIKit.metal_button(self, rect, rect.has_point(mouse), chosen)
		if chosen:
			draw_rect(rect, UIKit.AMBER, false, 2)
		UIKit.text(self, 17, label, UIKit.AMBER if chosen else Color8(230, 220, 190), rect.get_center(), "center")
	for w in s.hands:
		var weapon: Gear.Weapon = Gear.WEAPONS[w]
		if weapon.vigor_req > s.stats["vigor"]:
			UIKit.text(self, 14, "体魄不够: %s要 %d (不够会怎样以后再定)" % [weapon.name, weapon.vigor_req],
					UIKit.ORANGE, Vector2(GEAR_BOX.position.x + 16, GEAR_BOX.end.y - 32))
			break

	# 下面: 恢复默认、找教官说话、开打
	UIKit.metal_button(self, RESET_BTN, RESET_BTN.has_point(mouse))
	UIKit.text(self, 20, "恢复默认", UIKit.AMBER, RESET_BTN.get_center(), "center")
	UIKit.metal_button(self, TALK_BTN, TALK_BTN.has_point(mouse))
	UIKit.text(self, 20, "找教官说话", UIKit.AMBER, TALK_BTN.get_center(), "center")
	UIKit.text(self, 16, "回车 开打 · T 说话 · Esc 退出", Color8(170, 160, 130), Vector2(W / 2.0 + 80, RESET_BTN.get_center().y), "center")
	var ready_now := s.ready()
	UIKit.red_button(self, Vector2(START_BTN.position.x + 40, START_BTN.get_center().y), 24,
			START_BTN.has_point(mouse) and ready_now)
	UIKit.text(self, 28, "开打", UIKit.AMBER if ready_now else Color8(130, 120, 96),
			Vector2(START_BTN.position.x + 84, START_BTN.get_center().y), "midleft")
