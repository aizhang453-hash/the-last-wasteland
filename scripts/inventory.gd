class_name Inventory
## 背包的规则: 东西多重、能背多少、拿到手上、穿上、放回背包、从武器架拿。只管规则, 不管画
## (画在 inventory_view.gd 背包画面、loot_view.gd 武器架画面)。
## 用户 2026-10-09 定的: 照原版按重量算, 体魄越高背得越多, 背满了就捡不起来、拿不了;
## 战斗里打开背包要花点数 (Rules.PACK_AP), 在里面换东西不花。
## 一个人身上的东西: 两只手 (unit.hands / unit.loaded)、护甲 (unit.armor)、背包里的武器和护甲 (unit.pack)、子弹 (unit.spare)。

const KIND_NAMES := {"unarmed": "空手", "melee": "近身武器", "gun": "枪", "throw": "投掷"}


## 一样东西
class Item:
	var kind := "weapon"   ## "weapon" 武器 (手雷也算) / "ammo" 子弹 / "armor" 护甲
	var id := ""           ## 武器: Gear.WEAPONS 里的名字; 子弹: 哪种枪用的 (pistol / rifle / smg); 护甲: leather / metal
	var count := 1         ## 几个: 子弹几发、手雷几个; 别的都是 1
	var loaded := 0        ## 枪里还有几发 (只有枪用)

	func _init(p_kind := "weapon", p_id := "", p_count := 1, p_loaded := 0) -> void:
		kind = p_kind
		id = p_id
		count = p_count
		loaded = p_loaded

	func copy() -> Inventory.Item:
		return Inventory.Item.new(kind, id, count, loaded)

	func name() -> String:
		match kind:
			"ammo":
				return Gear.AMMO_NAMES[id]
			"armor":
				return Gear.ARMORS[id].name
		return Gear.WEAPONS[id].name

	## 子弹、手雷是一堆一堆的 (画面上写「×24」)
	func stacks() -> bool:
		return kind == "ammo" or id == "grenade"

	func weight() -> int:
		match kind:
			"ammo":
				return Gear.ROUND_WEIGHT * count
			"armor":
				return Gear.ARMOR_WEIGHT[id]
		return Gear.WEAPON_WEIGHT[id] * count + Gear.ROUND_WEIGHT * loaded

	func _to_string() -> String:
		return "<%s%s>" % [name(), " ×%d" % count if stacks() else ""]


## 一把武器 (枪是装满的)
static func weapon(id: String) -> Item:
	var w: Gear.Weapon = Gear.WEAPONS[id]
	return Item.new("weapon", id, 1, w.magazine)


## 能背多重 (克) = 10 + 体魄 × 10 公斤 (照原版「25 + 力量 × 25 磅」的比例)
static func capacity(vigor: int) -> int:
	return (10 + vigor * 10) * 1000


static func capacity_of(unit: Unit) -> int:
	return capacity(unit.stats["vigor"])


## 克 -> 公斤, 画面上写的 (7700 -> "7.7", 60000 -> "60")
static func kg(grams: int) -> String:
	if grams % 1000 == 0:
		return str(grams / 1000)
	return "%.1f" % (grams / 1000.0)


## 这只手上拿的东西 (空手是 null)
static func hand_item(unit: Unit, hand: int) -> Item:
	var wid: String = unit.hands[hand]
	if wid == "":
		return null
	if wid == "grenade":
		return Item.new("weapon", wid, unit.loaded[hand], 0)
	return Item.new("weapon", wid, 1, unit.loaded[hand])


## 把东西放到这只手上 (null 是空手)。不检查能不能拿, 先用 hand_problem 看
static func put_in_hand(unit: Unit, hand: int, item: Item) -> void:
	unit.burst[hand] = false  # 刚拿到手上的枪先是单发
	if item == null:
		unit.hands[hand] = ""
		unit.loaded[hand] = 0
	else:
		unit.hands[hand] = item.id
		unit.loaded[hand] = item.count if item.id == "grenade" else item.loaded


## 背包里的东西 (画面上左边那一列): 武器和护甲, 后面是子弹 (每种一堆)
static func entries(unit: Unit) -> Array:
	var list := unit.pack.duplicate()
	for gun in Gear.AMMO_NAMES:
		if unit.spare.get(gun, 0) > 0:
			list.append(Item.new("ammo", gun, unit.spare[gun]))
	return list


## 身上东西一共多重 (手上的、穿着的也算, 原版也是这样)
static func weight(unit: Unit) -> int:
	var total: int = Gear.ARMOR_WEIGHT[unit.armor.id]
	for hand in 2:
		var it := hand_item(unit, hand)
		if it != null:
			total += it.weight()
	for it in entries(unit):
		total += it.weight()
	return total


## 还能背多重 (负数是背多了)
static func room(unit: Unit) -> int:
	return capacity_of(unit) - weight(unit)


## 放进背包 (要背得动)
static func add(unit: Unit, item: Item) -> String:
	if item.weight() > room(unit):
		return "背不动了 (最多背 %s 公斤)" % kg(capacity_of(unit))
	_put_in(unit, item)
	return ""


## 放进背包, 不看重量 (身上的东西挪来挪去用)。子弹放进 spare; 手雷跟背包里的手雷合成一堆
static func _put_in(unit: Unit, item: Item) -> void:
	if item.kind == "ammo":
		unit.spare[item.id] = unit.spare.get(item.id, 0) + item.count
		return
	if item.id == "grenade":
		for it in unit.pack:
			if it.id == "grenade":
				it.count += item.count
				return
	unit.pack.append(item.copy())


## 从背包里拿走 (item 是 entries 里的一样)
static func remove(unit: Unit, item: Item) -> void:
	if item.kind == "ammo":
		unit.spare[item.id] = unit.spare.get(item.id, 0) - item.count
		if unit.spare[item.id] <= 0:
			unit.spare.erase(item.id)
	else:
		unit.pack.erase(item)


## 这样东西能不能拿到这只手上 (能就是 "")
static func hand_problem(unit: Unit, hand: int, item: Item) -> String:
	if item.kind != "weapon":
		return "只有武器能拿在手上"
	if not unit.hand_ok(hand):
		return "%s废了, 拿不了东西" % Unit.HAND_NAMES[hand]
	if Gear.WEAPONS[item.id].hands == 2 and unit.arms_crippled() > 0:
		return "%s要两只手都好才能用" % item.name()
	return ""


## 背包里的武器拿到手上; 手上原来的东西放回背包
static func equip(unit: Unit, item: Item, hand: int) -> String:
	var why := hand_problem(unit, hand, item)
	if why != "":
		return why
	var old := hand_item(unit, hand)
	remove(unit, item)
	put_in_hand(unit, hand, item)
	if old != null:
		_put_in(unit, old)
	return ""


## 手上的东西放回背包
static func unequip(unit: Unit, hand: int) -> String:
	var old := hand_item(unit, hand)
	if old == null:
		return "这只手是空的"
	put_in_hand(unit, hand, null)
	_put_in(unit, old)
	return ""


## 两只手上的东西换一下
static func swap_hands(unit: Unit) -> String:
	var a := hand_item(unit, 0)
	var b := hand_item(unit, 1)
	if a != null and hand_problem(unit, 1, a) != "":
		return hand_problem(unit, 1, a)
	if b != null and hand_problem(unit, 0, b) != "":
		return hand_problem(unit, 0, b)
	unit.hands.reverse()
	unit.loaded.reverse()
	unit.burst.reverse()
	return ""


## 穿上背包里的护甲; 原来穿的放回背包
static func wear(unit: Unit, item: Item) -> String:
	if item.kind != "armor":
		return "这个不能穿"
	var old: String = unit.armor.id
	remove(unit, item)
	unit.armor = Gear.ARMORS[item.id]
	if old != "none":
		_put_in(unit, Item.new("armor", old))
	return ""


## 脱下护甲放回背包
static func take_off(unit: Unit) -> String:
	if unit.armor.id == "none":
		return "没穿护甲"
	_put_in(unit, Item.new("armor", unit.armor.id))
	unit.armor = Gear.ARMORS["none"]
	return ""


## 练习场武器架上的东西 (拿不完): 每种武器一把 (手雷一个)、每种子弹一盒、两种护甲
static func rack() -> Array:
	var list := []
	for wid in Gear.CHOICES:
		if wid != "fist":
			list.append(weapon(wid))
	for gun in Gear.AMMO_NAMES:
		list.append(Item.new("ammo", gun, Gear.SPARE_AMMO[gun]))
	for aid in Gear.ARMOR_ORDER:
		if aid != "none":
			list.append(Item.new("armor", aid))
	return list


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
		words += "射程 %d 格。弹夹 %d 发, 用%s。" % [w.reach, w.magazine, Gear.AMMO_NAMES[wid]]
	if w.accuracy != 0:
		words += "准头 %s%d%%。" % ["+" if w.accuracy > 0 else "", w.accuracy]
	if w.burst_ap > 0:
		var split := Rules.burst_split(Rules.BURST_ROUNDS)
		words += "可以连发: 一次 %d 发, 花 %d 点, %d 发对准、%d 发往两边散, 不能瞄准。" % [
				Rules.BURST_ROUNDS, w.burst_ap, split[0], split[1] + split[2]]
	if w.kind == "throw":
		words += "扔多远看体魄 (体魄 × 2 格), 炸 3×3, 范围里的人都受伤, 包括你自己。扔偏了会落到旁边。"
	if w.vigor_req > 0:
		words += "要体魄 %d。" % w.vigor_req
	return words


static func armor_help(aid: String) -> String:
	var a: Gear.Armor = Gear.ARMORS[aid]
	if aid == "none":
		return "没穿护甲: 什么都不挡, 不过也不占地方。"
	return "%s: 防御 +%d (更难被打中), 先挡掉 %d 点伤害, 剩下的再挡 %d%%。" % [a.name, a.defense, a.threshold, a.resist]


## 画面右边写的说明: 是什么、有几个、多重
static func describe(item: Item) -> String:
	var words := ""
	match item.kind:
		"ammo":
			words = "%s: %s用的, 一共 %d 发。" % [item.name(), Gear.WEAPONS[item.id].name, item.count]
		"armor":
			words = armor_help(item.id)
		_:
			words = weapon_help(item.id)
			var w: Gear.Weapon = Gear.WEAPONS[item.id]
			if w.magazine > 0:
				words += "枪里还有 %d 发。" % item.loaded
			elif item.id == "grenade":
				words += "一共 %d 个。" % item.count
	return words + "重 %s 公斤。" % kg(item.weight())
