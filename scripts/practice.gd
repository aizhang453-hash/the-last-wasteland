class_name Practice
## 练习场的布置: 一小块空地, 你和两个强盗。
## 这些只是用来试战斗规则的假人, 不是正式剧情。
## 开打前可以在「准备」画面里自己分能力值、挑两只手的武器和护甲 (见 Setup)。

const MAP_SIZE := 14
const START_POINTS := 18  # 每项先给 1 分, 再自己分 18 点 (加起来 24)
const MIN_STAT := 1
const MAX_STAT := 10


## 六个能力值 (开局每项 1 分, 再分 18 点, 加起来 24)
static func stats(survival: int, agility: int, vigor: int, intellect: int, observation: int, resolve: int) -> Dictionary:
	return {"survival": survival, "agility": agility, "vigor": vigor,
			"intellect": intellect, "observation": observation, "resolve": resolve}


## 你开打前的准备: 能力值、右手左手拿什么、穿什么护甲
class Setup:
	var stats: Dictionary
	var hands: Array
	var armor: String

	func _init() -> void:
		reset()

	## 恢复默认
	func reset() -> void:
		stats = Practice.stats(3, 6, 5, 2, 5, 3)
		hands = ["pistol", "knife"]
		armor = "leather"

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

	## 点数分完了才能开打
	func ready() -> bool:
		return points_left() == 0

	func make_player() -> Unit:
		var real_hands := []
		var ammo := {}
		for w in hands:
			var wid: String = "" if w == "fist" else w
			real_hands.append(wid)
			if Gear.SPARE_AMMO.has(wid):
				ammo[wid] = ammo.get(wid, 0) + Gear.SPARE_AMMO[wid]
		var unit := Unit.new("你", Unit.PLAYER, stats, real_hands, armor, ammo, Vector2i(3, 10), "你")
		for hand in 2:
			if real_hands[hand] == "grenade":
				unit.loaded[hand] = Gear.GRENADES
		return unit


static func make_battle(dice: Dice = null, setup: Setup = null) -> Battle:
	var you := (setup if setup != null else Setup.new()).make_player()
	# 强盗比你弱 (能力值加起来不到 24), 枪手也没穿护甲。
	# 用默认的准备, 电脑用敌人那套简单想法替你打, 大约七成能赢; 会动脑子的话赢面更大。
	var knife := Unit.new("持刀强盗", Unit.ENEMY, stats(3, 4, 4, 1, 3, 3), ["knife", ""], "leather", {},
			Vector2i(10, 3), "刀")
	var gunner := Unit.new("持枪强盗", Unit.ENEMY, stats(3, 3, 4, 1, 3, 3), ["pistol", ""], "none",
			{"pistol": 16}, Vector2i(11, 6), "枪")
	return Battle.new([you, knife, gunner], MAP_SIZE, MAP_SIZE, dice, you)
