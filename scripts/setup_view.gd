class_name SetupView
extends Control
## 开打前的「准备」画面: 照《辐射》二代建角色那一页的感觉 (左边能力值加加减减, 中间算出来的数, 右边是带的东西)。
## - 救世主系统六项, 每项 1～10 分, 一开始每项 1 分, 再分 18 点
## - 右边「你带的东西」: 两只手、护甲、背包里有什么、总重量; 点「武器架」挑带什么 (loot_view.gd),
##   点「背包」把东西拿在手上、穿上 (inventory_view.gd)。用户 2026-10-09 定的: 照原版那样拖东西
## - 鼠标指着什么, 中间下面的绿屏幕就说明什么
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
const RACK_BTN := Rect2(802, 538, 176, 58)
const PACK_BTN := Rect2(990, 538, 176, 58)
## 「你带的东西」里两只手、护甲那三行的格子
const KIT_SLOTS := {"hand0": Rect2(862, 130, 110, 62), "hand1": Rect2(862, 200, 110, 62), "armor": Rect2(862, 270, 110, 62)}

const STAT_LETTERS := {"survival": "S", "agility": "A", "vigor": "V", "intellect": "I", "observation": "O", "resolve": "R"}
const STAT_HELP := {
	"survival": "适应: 在废土上活下去的本事。抗毒、抗辐射、抗病、耐饥渴、伤好得快。练习场里还用不到。",
	"agility": "灵巧: 每回合的行动点数 (5 + 灵巧 ÷ 2), 用枪的命中 (每分 +5%), 近身的命中 (每分 +3%), 还有防御。",
	"vigor": "体魄: 生命值 (15 + 体魄 × 3), 近身的命中 (每分 +2%) 和伤害 (加 体魄 ÷ 2), 手雷扔多远 (体魄 × 2 格)。大锤要体魄 6, 步枪要 4 (不够会怎样以后再定)。",
	"intellect": "学识: 医疗、科学、破解、修东西、聪明的对话选项。练习场里还用不到。",
	"observation": "洞察: 谁先动 (反应值), 远处打得准 (洞察几分, 就几格之内不扣命中), 暴击几率 (洞察 × 2)。",
	"resolve": "意志: 扛压力、说服人、能带几个同伴。练习场里还用不到。",
}
var setup: Practice.Setup
var mouse := Vector2.ZERO
var hint := ""
var pack_view: InventoryView  # 背包画面 (盖在准备画面上面; 第一次打开时才做)
var rack_view: LootView       # 武器架画面


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


## 「你带的东西」里那三行上的东西 (空着是 null)
func kit_item(key: String) -> Inventory.Item:
	var kit := setup.kit
	match key:
		"hand0":
			return Inventory.hand_item(kit, 0)
		"hand1":
			return Inventory.hand_item(kit, 1)
	return Inventory.Item.new("armor", kit.armor.id) if kit.armor.id != "none" else null


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
	if RACK_BTN.has_point(p):
		open_rack()
	elif PACK_BTN.has_point(p):
		open_pack()
	elif RESET_BTN.has_point(p):
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
	var why := setup.problem()
	if why != "":
		hint = why
		return
	start_requested.emit()


## 打开背包画面 (盖在准备画面上面)
func open_pack() -> void:
	if pack_view == null:
		pack_view = InventoryView.new()
		add_child(pack_view)
	pack_view.open(setup.kit)


func open_rack() -> void:
	if rack_view == null:
		rack_view = LootView.new()
		add_child(rack_view)
	rack_view.open(setup.kit)


## 开着的背包或武器架画面 (都没开是 null)
func overlay() -> ItemScreen:
	for v in [pack_view, rack_view]:
		if v != null and v.visible:
			return v
	return null


## 键盘: 背包、武器架开着就交给它 (返回 true); 没开返回 false
func press_key(key: Key) -> bool:
	var o := overlay()
	if o == null:
		return false
	o.press_key(key)
	return true


# ---------- 说明 ----------

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
	for key in KIT_SLOTS:
		if KIT_SLOTS[key].grow_individual(70, 0, 200, 0).has_point(mouse):
			var it := kit_item(key)
			return Inventory.describe(it) if it != null else ("空手: 手里不拿东西就用拳头打。" if key != "armor" else Inventory.armor_help("none"))
	if RACK_BTN.has_point(mouse):
		return "武器架: 练习场的武器、子弹、护甲随便拿, 拖到你的背包里就行, 背得动就行 (能背 10 + 体魄 × 10 公斤)。不要的拖回去。"
	if PACK_BTN.has_point(mouse):
		return "背包 (I): 把背包里的武器拖到手上、护甲拖到身上。战斗里也能开, 不过要花 %d 点。" % Rules.PACK_AP
	if TALK_BTN.has_point(mouse):
		return "找教官说话 (T): 试一试跟人说话。学识、意志不一样, 能说的话也不一样; 说着说着也可能直接开打。"
	return "鼠标指着能力值、带的东西或者按钮, 这里会说明它管什么。"


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
	var armor: Gear.Armor = s.kit.armor
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

	# 右边: 你带的东西 (两只手、护甲、背包里有什么、总重量), 下面「武器架」「背包」两个按钮
	var kit := s.kit
	UIKit.text(self, 24, "你带的东西", UIKit.AMBER, GEAR_BOX.position + Vector2(16, 14))
	for key in KIT_SLOTS:
		var rect: Rect2 = KIT_SLOTS[key]
		var row := rect.grow_individual(70, 0, 200, 0)
		if row.has_point(mouse):
			draw_rect(row.grow(3), Color8(52, 48, 38))
		var label: String = {"hand0": "右手", "hand1": "左手", "armor": "护甲"}[key]
		UIKit.text(self, 24, label, UIKit.AMBER, Vector2(GEAR_BOX.position.x + 16, rect.get_center().y), "midleft")
		UIKit.slot(self, rect)
		var it := kit_item(key)
		var name := "空手" if key != "armor" else "没穿"
		var detail := ""
		if it != null:
			UIKit.item_picture(self, rect.get_center(), it, 0.42)
			name = it.name()
			var w: Gear.Weapon = Gear.WEAPONS.get(it.id) if it.kind == "weapon" else null
			if w != null and w.magazine > 0:
				detail = "枪里 %d/%d 发" % [it.loaded, w.magazine]
			elif it.stacks():
				detail = "%d 个" % it.count
		UIKit.text(self, 24, name, UIKit.TEXT if it != null else UIKit.DIM, Vector2(rect.end.x + 14, rect.position.y + 6))
		if detail != "":
			UIKit.text(self, 12, detail, UIKit.DIM, Vector2(rect.end.x + 14, rect.position.y + 38))
	var pack := Inventory.entries(kit)
	UIKit.text(self, 24, "背包里", UIKit.AMBER, Vector2(GEAR_BOX.position.x + 16, 346))
	var names := pack.map(func(it: Inventory.Item) -> String: return it.name() + (" ×%d" % it.count if it.stacks() else ""))
	if names.is_empty():
		names = ["(空的)"]
	var shown := mini(names.size(), 12)
	for i in shown:
		var text: String = names[i]
		if i == 11 and names.size() > 12:
			text = "……还有 %d 样" % (names.size() - 11)
		UIKit.text(self, 12, text, UIKit.TEXT, Vector2(GEAR_BOX.position.x + 18 + (i % 2) * 186, 380 + floori(i / 2.0) * 17))
	var room := Inventory.room(kit)
	UIKit.text(self, 24, "总重 %s / %s 公斤" % [Inventory.kg(Inventory.weight(kit)), Inventory.kg(Inventory.capacity_of(kit))],
			UIKit.TEXT if room >= 0 else UIKit.ORANGE, Vector2(GEAR_BOX.position.x + 16, 486))
	for hand in 2:
		var held: String = kit.hands[hand]
		if held != "" and Gear.WEAPONS[held].vigor_req > s.stats["vigor"]:
			UIKit.text(self, 12, "体魄不够: %s要 %d (不够会怎样以后再定)" % [Gear.WEAPONS[held].name, Gear.WEAPONS[held].vigor_req],
					UIKit.ORANGE, Vector2(GEAR_BOX.position.x + 16, 518))
			break
	for b in [[RACK_BTN, "武器架"], [PACK_BTN, "背包"]]:
		var rect: Rect2 = b[0]
		UIKit.metal_button(self, rect, rect.has_point(mouse))
		UIKit.text(self, 24, b[1], UIKit.AMBER, rect.get_center(), "center")

	# 下面: 恢复默认、找教官说话、开打
	UIKit.metal_button(self, RESET_BTN, RESET_BTN.has_point(mouse))
	UIKit.text(self, 20, "恢复默认", UIKit.AMBER, RESET_BTN.get_center(), "center")
	UIKit.metal_button(self, TALK_BTN, TALK_BTN.has_point(mouse))
	UIKit.text(self, 20, "找教官说话", UIKit.AMBER, TALK_BTN.get_center(), "center")
	UIKit.text(self, 16, "回车 开打 · T 说话 · I 背包 · Esc 退出", Color8(170, 160, 130), Vector2(W / 2.0 + 80, RESET_BTN.get_center().y), "center")
	var ready_now := s.ready()
	UIKit.red_button(self, Vector2(START_BTN.position.x + 40, START_BTN.get_center().y), 24,
			START_BTN.has_point(mouse) and ready_now)
	UIKit.text(self, 28, "开打", UIKit.AMBER if ready_now else Color8(130, 120, 96),
			Vector2(START_BTN.position.x + 84, START_BTN.get_center().y), "midleft")
