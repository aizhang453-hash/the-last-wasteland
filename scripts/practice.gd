class_name Practice
## 练习场的布置: 一小块空地, 你和两个强盗。
## 这些只是用来试战斗规则的假人, 不是正式剧情。
## 开打前可以在「准备」画面里自己分能力值, 在武器架上挑带什么 (见 Setup)。

const MAP_SIZE := 14
const START_POINTS := 18  # 每项先给 1 分, 再自己分 18 点 (加起来 24)
const MIN_STAT := 1
const MAX_STAT := 10


## 六个能力值 (开局每项 1 分, 再分 18 点, 加起来 24)
static func stats(survival: int, agility: int, vigor: int, intellect: int, observation: int, resolve: int) -> Dictionary:
	return {"survival": survival, "agility": agility, "vigor": vigor,
			"intellect": intellect, "observation": observation, "resolve": resolve}


## 你开打前的准备: 能力值, 还有带的东西 (两只手、护甲、背包、子弹; 在武器架、背包画面里改)
class Setup:
	var stats: Dictionary
	## 你带的东西, 用一个「人」装着 (背包画面、武器架画面直接改它); 开打时照着它做一个新的你
	var kit: Unit

	func _init() -> void:
		reset()

	## 恢复默认: 手枪、小刀、皮甲, 一盒手枪子弹
	func reset() -> void:
		stats = Practice.stats(3, 6, 5, 2, 5, 3)
		choose(["pistol", "knife"], "leather")

	## 照这样配好: 两只手拿什么 ("fist" 是空手)、穿什么; 枪配一盒备用子弹, 手雷拿 3 个; 背包里没别的
	func choose(hands: Array, armor := "leather") -> void:
		var real_hands := []
		var ammo := {}
		for w in hands:
			var wid: String = "" if w == "fist" else w
			real_hands.append(wid)
			if Gear.SPARE_AMMO.has(wid):
				ammo[wid] = ammo.get(wid, 0) + Gear.SPARE_AMMO[wid]
		kit = Unit.new("你", Unit.PLAYER, stats, real_hands, armor, ammo, Vector2i(3, 10), "你")
		for hand in 2:
			if real_hands[hand] == "grenade":
				kit.loaded[hand] = Gear.GRENADES
		kit.stats = stats  # 跟准备画面的能力值是同一份: 改了体魄, 能背多少马上跟着变

	func points_left() -> int:
		var used := 0
		for v in stats.values():
			used += v
		return Practice.MIN_STAT * 6 + Practice.START_POINTS - used

	## 能力值加 1 或减 1 (不能低于 1、高于 10, 也不能超过能分的点数)
	func change(stat: String, delta: int) -> bool:
		var value: int = stats[stat] + delta
		if value < Practice.MIN_STAT or value > Practice.MAX_STAT:
			return false
		if delta > 0 and points_left() < delta:
			return false
		stats[stat] = value
		return true

	## 还不能开打的原因 (能开打就是 ""): 点数没分完, 或者背的东西太重
	func problem() -> String:
		if points_left() != 0:
			return "还有 %d 点没分完" % points_left()
		if Inventory.room(kit) < 0:
			return "背太多了 (最多背 %s 公斤), 先放下一些" % Inventory.kg(Inventory.capacity_of(kit))
		return ""

	func ready() -> bool:
		return problem() == ""

	func make_player() -> Unit:
		var you := Unit.new("你", Unit.PLAYER, stats, kit.hands, kit.armor.id, kit.spare, Vector2i(3, 10), "你")
		you.loaded = kit.loaded.duplicate()
		you.burst = kit.burst.duplicate()
		you.pack = kit.pack.map(func(it: Inventory.Item) -> Inventory.Item: return it.copy())
		return you


static func make_battle(dice: Dice = null, setup: Setup = null) -> Battle:
	var you := (setup if setup != null else Setup.new()).make_player()
	# 强盗比你弱 (能力值加起来不到 24), 枪手也没穿护甲。
	# 用默认的准备, 电脑用敌人那套简单想法替你打, 大约七成能赢; 会动脑子的话赢面更大。
	var knife := Unit.new("持刀强盗", Unit.ENEMY, stats(3, 4, 4, 1, 3, 3), ["knife", ""], "leather", {},
			Vector2i(10, 3), "刀")
	var gunner := Unit.new("持枪强盗", Unit.ENEMY, stats(3, 3, 4, 1, 3, 3), ["pistol", ""], "none",
			{"pistol": 16}, Vector2i(11, 6), "枪")
	return Battle.new([you, knife, gunner], MAP_SIZE, MAP_SIZE, dice, you)
