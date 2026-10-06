class_name AI
## 敌人怎么行动 (电脑控制的人)。
## 每次只做一件事 (走一步、打一下、换子弹……), 画面好一件一件放给玩家看。测试里也用它来替玩家打。

const AIM_AT := 35  # 瞄准某个部位的命中几率到这么多, 才值得瞄


## 离这个人最近的、还活着的对头
static func nearest_foe(battle: Battle, unit: Unit) -> Unit:
	var best: Unit = null
	for u in battle.units:
		if u.alive() and u.side != unit.side:
			if best == null or Rules.distance(unit.pos, u.pos) < Rules.distance(unit.pos, best.pos):
				best = u
	return best


## 让这个人做一件事。做了返回 true; 没什么能做的了返回 false (该结束回合了)。
## 想法很简单:
## - 枪里没子弹: 能换子弹就换
## - 手上没武器、旁边地上有: 捡起来 (离得不远就走过去)
## - 挑一只最好用的手 (见 _best_hand); 不是现在这只就换过去。
##   挑法每次都一样, 换过去以后就不会再换回来 (换手不花点数, 来回换会没完没了)
## - 能打就打 (这回合点数只够打一下, 还多出瞄准的 1 点, 就瞄准头或者腿)
##   用枪的话, 太难打中而且点数够, 先走近一步
## - 打不着就往对头那边走一步
static func act(battle: Battle, unit: Unit) -> bool:
	if battle.result != "" or unit != battle.current() or not unit.alive():
		return false
	var target := nearest_foe(battle, unit)
	if target == null:
		return false

	if unit.weapon().magazine > 0 and unit.ammo_in_hand() == 0 and battle.reload_problem(unit) == "":
		return battle.reload(unit)

	if unit.hands[unit.active] == "" and unit.arms_crippled() < 2:
		var item := _nearest_item(battle, unit)
		if item != null and battle.pickup_problem(unit, item) == "":
			return battle.pickup(unit, item)
		if item != null and Rules.distance(unit.pos, item.pos) <= 3 and battle.free_hand(unit) >= 0:
			var path = battle.path_within(unit, item.pos, 1)
			if path != null and not path.is_empty() and battle.move(unit, path[0]):
				return true

	var best := _best_hand(unit, target)
	if best != unit.active:
		return battle.switch_hand(unit)
	var w := unit.weapon()
	if _hand_score(unit, unit.active, target) < 0:
		return false  # 两只手都没法用 (比如手雷离得太近、枪没子弹), 这回合算了

	if battle.attack_problem(unit, target) == "":
		var d := Rules.distance(unit.pos, target.pos)
		var far_gun := not Rules.is_close(w.kind)
		if far_gun and battle.hit_chance(unit, target) < 30 and d > 2 and unit.ap >= unit.step_cost() + w.ap:
			if _step_toward(battle, unit, target):
				return true
		var part := _pick_part(battle, unit, target)
		return battle.attack(unit, target, part) != null

	# 打不着: 往前走一步。用枪、扔手雷的人在够得着的地方只是点数不够 (或者要换子弹), 就不走了 (留着点数当防御)
	if not Rules.is_close(w.kind) and Rules.distance(unit.pos, target.pos) <= battle.attack_range(unit):
		return false
	if unit.ap >= unit.step_cost():
		return _step_toward(battle, unit, target)
	return false


## 这只手现在好不好用: 不能用返回 -1; 拳头 1 分; 拿着能用的武器 3 分
## (枪空了但还有备用子弹也算 3 分: 点数不够换就等下回合换, 不为这个换到别的手上去)。
## 两只手都废了就只能踢, 算 1 分。
static func _hand_score(unit: Unit, hand: int, target: Unit) -> int:
	if unit.arms_crippled() == 2:
		return 1
	if not unit.hand_ok(hand):
		return -1
	var wid: String = unit.hands[hand]
	if wid == "":
		return 1
	var w: Gear.Weapon = Gear.WEAPONS[wid]
	if w.hands == 2 and unit.arms_crippled() > 0:
		return -1
	if w.kind == "throw" and Rules.distance(unit.pos, target.pos) <= Rules.BLAST_RADIUS + 1:
		return -1  # 对头离得太近, 扔手雷会连自己一起炸
	if w.magazine > 0 and unit.loaded[hand] == 0 and unit.spare.get(wid, 0) == 0:
		return -1  # 枪空了, 也没有备用子弹
	return 3


## 最好用的那只手; 一样好就留在现在这只 (不白换)
static func _best_hand(unit: Unit, target: Unit) -> int:
	var other := 1 - unit.active
	if _hand_score(unit, other, target) > _hand_score(unit, unit.active, target):
		return other
	return unit.active


## 点数只够打一下、还多出瞄准的 1 点时, 瞄准头 (能打晕) 或者腿 (能打瘸)
static func _pick_part(battle: Battle, unit: Unit, target: Unit) -> String:
	if unit.bursting() or unit.weapon().kind == "throw":
		return ""
	var cost := unit.weapon().ap
	if not (cost + Rules.AIM_AP <= unit.ap and unit.ap < cost * 2):
		return ""
	if battle.hit_chance(unit, target, "head") >= AIM_AT:
		return "head"
	var legs := Rules.LEGS.filter(func(leg: String) -> bool: return not target.crippled.has(leg))
	if not legs.is_empty():
		var leg: String = battle.dice.pick(legs)
		if battle.hit_chance(unit, target, leg) >= AIM_AT:
			return leg
	return ""


static func _nearest_item(battle: Battle, unit: Unit) -> Battle.GroundItem:
	var best: Battle.GroundItem = null
	for item in battle.ground:
		if best == null or Rules.distance(unit.pos, item.pos) < Rules.distance(unit.pos, best.pos):
			best = item
	return best


static func _step_toward(battle: Battle, unit: Unit, target: Unit) -> bool:
	var path = battle.path_next_to(unit, target)
	if path == null or path.is_empty():
		return false
	return battle.move(unit, path[0])
