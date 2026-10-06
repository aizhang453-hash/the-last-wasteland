class_name Battle
extends RefCounted
## 一场战斗: 地图上的人、轮流行动、走路、攻击 (可以瞄准部位、连发、扔手雷)、换子弹、捡武器。
## 这里只管规则和数字, 不管画面 (画面在 arena_view.gd), 所以可以单独测试。
##
## 画面要知道发生了什么 (好放动画), 就看 events (每件事是一个字典, kind 说是什么事):
##   move (unit, path 走过的格子) / attack (result) / throw (result) / reload (unit) / switch (unit)
##   drop (unit, item) / pickup (unit, item) / getup (unit) / stunned (unit)
## 战斗记录在 messages 里: 每句是 [这句话, 种类], 种类是 info / player / enemy / good / bad

## 8 个方向: 横、竖、斜着都能走, 每步都算 1 格
const DIRECTIONS := [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0),
		Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]


## 打一下的结果 (连发也是一个: shots、hits 说打了几发、打中目标几发)
class AttackResult:
	var attacker: Unit
	var target: Unit
	var weapon: Gear.Weapon
	var chance: int        # 命中几率
	var hit: bool
	var crit: bool
	var damage: int
	var killed: bool
	var shots := 1         # 打了几发 (连发最多 10 发)
	var hits := 0          # 打中目标几发
	var part := ""         # 瞄准的部位 (没瞄准是 "")
	var effect := ""       # 暴击打中部位的效果, 写进战斗记录的话 (比如「持枪强盗的左腿瘸了!」)
	var effect_short := "" # 同一件事的短说法, 飘在人头上 (比如「左腿瘸了」)
	var strays := []       # 连发打中的别人: [[人, 伤害, 倒下没有], ...]
	var paths := []        # 连发每发子弹飞到哪: [[终点 (格子坐标, 可以是小数), 打中的人或 null], ...]


## 扔手雷的结果
class ThrowResult:
	var attacker: Unit
	var weapon: Gear.Weapon
	var aim: Vector2i      # 往哪一格扔
	var landing: Vector2i  # 落在哪一格 (扔偏了就不是 aim)
	var chance: int
	var hit: bool
	var victims := []      # 炸到的人: [[人, 伤害, 倒下没有], ...]


## 掉在地上的武器
class GroundItem:
	var pos: Vector2i
	var weapon_id: String
	var loaded: int  # 枪里还有几发 (手雷是有几个)

	func _init(p_pos: Vector2i, p_weapon_id: String, p_loaded: int) -> void:
		pos = p_pos
		weapon_id = p_weapon_id
		loaded = p_loaded


var width: int
var height: int
var units: Array
var dice: Dice
var messages: Array = []
var events: Array = []
var ground: Array = []   # 掉在地上的武器 (GroundItem)
var result := ""         # "" 还在打; "won" 赢了; "lost" 输了
var round_no := 1
var order: Array = []
var turn := 0


func _init(p_units: Array, p_width := 14, p_height := 14, p_dice: Dice = null, initiator: Unit = null) -> void:
	width = p_width
	height = p_height
	units = p_units.duplicate()
	dice = p_dice if p_dice != null else Dice.new()
	# 开打时先动手的一方先打第一下, 之后每一轮按反应值排队
	var first: Unit = initiator if initiator != null else units[0]
	order = _base_order()
	order.erase(first)
	order.insert(0, first)
	turn = 0
	say("第 1 轮。" + ("你先动手。" if first.side == Unit.PLAYER else "%s先动手!" % first.name), "info")
	_begin_turn()


# ---------- 轮流 ----------

## 反应值高的先动; 一样高比灵巧; 还一样就玩家这边先动 (再一样就按原来的先后)
func _base_order() -> Array:
	var alive_units := units.filter(func(u: Unit) -> bool: return u.alive())
	alive_units.sort_custom(func(a: Unit, b: Unit) -> bool:
		var ka := _order_key(a)
		var kb := _order_key(b)
		for i in ka.size():
			if ka[i] != kb[i]:
				return ka[i] < kb[i]
		return false)
	return alive_units


## 排队用的「比较顺序」: 数字小的排前面
func _order_key(u: Unit) -> Array:
	return [-Rules.reaction(u.stats["observation"]), -u.stats["agility"],
			0 if u.side == Unit.PLAYER else 1, units.find(u)]


func current() -> Unit:
	return order[turn]


func _begin_turn() -> void:
	var u := current()
	u.ap = Rules.action_points(u.stats["agility"])
	u.leftover = 0  # 上回合留下的防御, 到自己回合开始就没了
	if u.knocked_down:
		u.knocked_down = false
		u.ap = maxi(0, u.ap - Rules.GET_UP_AP)
		events.append({"kind": "getup", "unit": u})
		say("%s爬了起来 (花 %d 点)。" % [u.name, Rules.GET_UP_AP], _kind(u))


## 结束现在这个人的回合: 没用完的点数变成防御, 轮到下一个还活着的人
func end_turn() -> void:
	if result != "":
		return
	var u := current()
	u.leftover = u.ap
	u.ap = 0
	while true:
		turn += 1
		if turn >= order.size():
			round_no += 1
			order = _base_order()
			turn = 0
			say("第 %d 轮。" % round_no, "info")
		var nxt := current()
		if not nxt.alive():
			continue
		if nxt.knocked_out:  # 晕着: 这回合跳过, 也没有防御加成
			nxt.knocked_out = false
			nxt.leftover = 0
			events.append({"kind": "stunned", "unit": nxt})
			say("%s晕着, 这回合动不了。" % nxt.name, _kind(nxt))
			continue
		break
	_begin_turn()


## 不能行动的原因 (打完了、没轮到、已经倒下了); 能行动返回 ""
func _not_your_turn(unit: Unit) -> String:
	if result != "" or unit != current():
		return "还没轮到"
	if not unit.alive():
		return "已经倒下了"
	return ""


## 这一轮已经轮过了吗 (给排队头像用)
func has_acted(unit: Unit) -> bool:
	var i := order.find(unit)
	return i >= 0 and i < turn


# ---------- 地图和走路 ----------

func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.x < width and p.y >= 0 and p.y < height


## 这格上站着的活人 (倒下的人可以踩过去)
func unit_at(p: Vector2i) -> Unit:
	for u in units:
		if u.alive() and u.pos == p:
			return u
	return null


## 从这个人脚下出发找路 (一格一格往外找, 找到的就是最短的路)。
## is_goal(格子) 说哪些格子算到了; toward 是大概往哪儿走, 一样短的路里先试离它近的方向, 走出来的路比较直。
## 返回走过的格子 (不含起点); 找不到返回 null。
func _search(unit: Unit, is_goal: Callable, toward: Vector2i) -> Variant:
	var start := unit.pos
	if is_goal.call(start):
		return []
	var came_from := {start: start}
	var queue := [start]
	var head := 0
	while head < queue.size():
		var here: Vector2i = queue[head]
		head += 1
		var nexts := []
		for d in DIRECTIONS:
			nexts.append(here + d)
		nexts.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return (a - toward).length_squared() < (b - toward).length_squared())
		for nxt in nexts:
			if came_from.has(nxt) or not in_bounds(nxt) or unit_at(nxt) != null:
				continue
			came_from[nxt] = here
			if is_goal.call(nxt):
				var path := [nxt]
				while came_from[path[-1]] != start:
					path.append(came_from[path[-1]])
				path.reverse()
				return path
			queue.append(nxt)
	return null


## 走到 dest 的路; 走不到 (有人站着、出了地图) 返回 null
func find_path(unit: Unit, dest: Vector2i) -> Variant:
	if not in_bounds(dest) or unit_at(dest) != null:
		return null
	return _search(unit, func(p: Vector2i) -> bool: return p == dest, dest)


## 走到离 pos 不超过 dist 格的最短路 (已经够近了返回 [])
func path_within(unit: Unit, p: Vector2i, dist: int) -> Variant:
	return _search(unit, func(q: Vector2i) -> bool: return Rules.distance(q, p) <= dist, p)


## 走到 target 旁边 (挨着, 斜着也算) 的最短路
func path_next_to(unit: Unit, target: Unit) -> Variant:
	return path_within(unit, target.pos, 1)


## 走这条路要花几点
func move_cost(unit: Unit, path: Array) -> int:
	return path.size() * unit.step_cost()


## 这回合还能走到的格子: {格子: 要几步}
func reachable(unit: Unit) -> Dictionary:
	var found := {}
	var steps := {unit.pos: 0}
	var queue := [unit.pos]
	var head := 0
	var max_steps := floori(unit.ap / float(unit.step_cost()))
	while head < queue.size():
		var here: Vector2i = queue[head]
		head += 1
		if steps[here] >= max_steps:
			continue
		for d in DIRECTIONS:
			var nxt: Vector2i = here + d
			if steps.has(nxt) or not in_bounds(nxt) or unit_at(nxt) != null:
				continue
			steps[nxt] = steps[here] + 1
			found[nxt] = steps[nxt]
			queue.append(nxt)
	return found


## 沿最短路走到 dest, 一格花 1 点 (腿瘸了多花)。走不到或者点数不够, 返回 false, 什么都不变
func move(unit: Unit, dest: Vector2i) -> bool:
	if _not_your_turn(unit) != "":
		return false
	var path = find_path(unit, dest)
	if path == null or path.is_empty() or move_cost(unit, path) > unit.ap:
		return false
	unit.ap -= move_cost(unit, path)
	var start := unit.pos
	unit.pos = dest
	events.append({"kind": "move", "unit": unit, "path": [start] + path})
	return true


# ---------- 攻击 ----------

## 打一下花几点 (瞄准部位多花 1 点; 连发看武器)
func attack_cost(unit: Unit, part := "") -> int:
	if unit.bursting():
		return unit.weapon().burst_ap
	return unit.weapon().ap + (Rules.AIM_AP if part != "" else 0)


## 能打多远 (格)
func attack_range(unit: Unit) -> int:
	var w := unit.weapon()
	if Rules.is_close(w.kind):
		return 1
	if w.kind == "throw":
		return Rules.throw_range(unit.stats["vigor"])
	return w.reach


## 能打就返回 ""; 打不了返回原因 (给画面显示)
func attack_problem(unit: Unit, target: Unit, part := "") -> String:
	var why := _not_your_turn(unit)
	if why != "":
		return why
	if not target.alive() or target.side == unit.side:
		return "不能打这个人"
	var w := unit.weapon()
	if unit.arms_crippled() < 2:
		if not unit.hand_ok(unit.active):
			return "%s废了, 先换手" % Unit.HAND_NAMES[unit.active]
		if w.hands == 2 and unit.arms_crippled() > 0:
			return "%s要两只手都好才能用" % w.name
	if part != "" and unit.bursting():
		return "连发不能瞄准"
	if part != "" and w.kind == "throw":
		return "手雷不能瞄准"
	var d := Rules.distance(unit.pos, target.pos)
	if Rules.is_close(w.kind):
		if d > 1:
			return "要走到旁边才能打"
	elif d > attack_range(unit):
		var how := "扔" if w.kind == "throw" else "射程"
		return "太远了 (%s%s %d 格)" % [w.name, how, attack_range(unit)]
	if w.magazine > 0 and unit.ammo_in_hand() == 0:
		return "没子弹了, 先换子弹"
	var cost := attack_cost(unit, part)
	if unit.ap < cost:
		return "行动点不够 (要 %d 点)" % cost
	return ""


func hit_chance(unit: Unit, target: Unit, part := "") -> int:
	# 手雷是往那一格扔, 不看人躲不躲得开, 所以不减防御
	var def := 0 if unit.weapon().kind == "throw" else target.defense()
	return Rules.hit_chance(unit.stats, unit.weapon(), def, Rules.distance(unit.pos, target.pos),
			Rules.part_penalty(part), 0, unit.blind)


func crit_chance(unit: Unit, part := "") -> int:
	return Rules.crit_chance(unit.stats["observation"], Rules.aim_crit_bonus(part))


## 打一下 (part 是瞄准的部位, 不瞄准就是 "")。打不了返回 null。
## 打了返回 AttackResult (连发也是); 扔手雷返回 ThrowResult。
func attack(unit: Unit, target: Unit, part := "") -> Variant:
	if attack_problem(unit, target, part) != "":
		return null
	var w := unit.weapon()
	if w.kind == "throw":
		return _throw(unit, target.pos)
	if unit.bursting():
		return _burst(unit, target)
	unit.ap -= attack_cost(unit, part)
	if w.magazine > 0:
		unit.loaded[unit.active] -= 1
	var r := AttackResult.new()
	r.attacker = unit
	r.target = target
	r.weapon = w
	r.part = part
	r.chance = hit_chance(unit, target, part)
	r.hit = dice.roll(1, 100) <= r.chance
	if r.hit:
		# 打中了再掷一次, 看暴没暴击
		r.crit = dice.roll(1, 100) <= crit_chance(unit, part)
		var raw := dice.roll(w.dmg_min, w.dmg_max)
		if Rules.is_close(w.kind):
			raw += Rules.melee_bonus(unit.stats["vigor"])
		r.damage = Rules.damage_after_armor(raw, r.crit, target.armor)
		target.hp = maxi(0, target.hp - r.damage)
	r.hits = 1 if r.hit else 0
	r.killed = not target.alive()

	var where := "%s的%s" % [target.name, Rules.part_name(part)] if part != "" else target.name
	var text := "%s用%s打%s (命中 %d%%)……" % [unit.name, w.name, where, r.chance]
	if not r.hit:
		text += "没打中。"
	elif r.crit:
		text += "暴击! %d 点伤害!" % r.damage
	elif r.damage == 0:
		text += "打中了, 可是没打穿护甲。"
	else:
		text += "打中了, %d 点伤害。" % r.damage
	say(text, _kind(unit))
	if r.killed:
		events.append({"kind": "attack", "result": r})
		say("%s倒下了。" % target.name, _victim_kind(target))
		_check_end()
		return r
	# 暴击打中瞄准的部位: 特殊效果
	var dropped: GroundItem = null
	if r.crit and part != "":
		dropped = _crit_effect(target, part, r)
	events.append({"kind": "attack", "result": r})
	if dropped != null:
		events.append({"kind": "drop", "unit": target, "item": dropped})
	if r.effect != "":
		say(r.effect, _victim_kind(target))
	return r


## 暴击打中部位以后发生什么: 写进 r.effect / r.effect_short; 有武器掉在地上就返回它
func _crit_effect(target: Unit, part: String, r: AttackResult) -> GroundItem:
	var who := target.name
	var pn := Rules.part_name(part)
	if part.ends_with("leg"):
		if target.crippled.has(part):
			return null
		target.crippled[part] = true
		r.effect = "%s的%s瘸了!" % [who, pn]
		r.effect_short = "%s瘸了" % pn
		return null
	if part.ends_with("arm"):
		if target.crippled.has(part):
			return null
		target.crippled[part] = true
		var item := _drop(target, Rules.ARM_OF_HAND.find(part))
		r.effect_short = "%s废了" % pn
		if item != null:
			r.effect = "%s的%s废了, %s掉在地上!" % [who, pn, Gear.WEAPONS[item.weapon_id].name]
		else:
			r.effect = "%s的%s废了!" % [who, pn]
		return item
	if part == "groin":
		target.knocked_down = true
		r.effect = "%s疼得倒在地上!" % who
		r.effect_short = "倒地"
	elif part == "head":
		target.knocked_out = true
		r.effect = "%s被打晕了!" % who
		r.effect_short = "打晕了"
	elif part == "eyes" and not target.blind:
		target.blind = true
		r.effect = "%s的眼睛看不见了!" % who
		r.effect_short = "瞎了"
	return null  # 身上: 只是伤害翻倍


## 这只手上的武器掉到旁边的空地上 (没空地就掉在脚下)
func _drop(unit: Unit, hand: int) -> GroundItem:
	var wid: String = unit.hands[hand]
	if wid == "":
		return null
	var spots := []
	for d in DIRECTIONS:
		var p: Vector2i = unit.pos + d
		if in_bounds(p) and unit_at(p) == null and item_at(p) == null:
			spots.append(p)
	var p: Vector2i = dice.pick(spots) if not spots.is_empty() else unit.pos
	var item := GroundItem.new(p, wid, unit.loaded[hand])
	unit.hands[hand] = ""
	unit.loaded[hand] = 0
	unit.burst[hand] = false
	ground.append(item)
	return item


## 连发 (照原版): 一次打 10 发 (枪里不够就有几发打几发)。
## 三分之一 (往上取整, 10 发就是 4 发) 对准目标飞, 剩下的往左右两边各歪 10 度飞。
## 每发子弹沿着自己那条线飞, 路上碰到的每个人按先后各算一次中不中, 打中谁就停在谁身上
## (敌人、同伴、挡在中间的人都可能)。离得近, 歪的子弹也常常落在目标身上; 离得远就散开了。
## 暴击只算打中目标的那几发。
func _burst(unit: Unit, target: Unit) -> AttackResult:
	var w := unit.weapon()
	var r := AttackResult.new()
	r.attacker = unit
	r.target = target
	r.weapon = w
	r.shots = mini(Rules.BURST_ROUNDS, unit.ammo_in_hand())
	unit.ap -= w.burst_ap
	unit.loaded[unit.active] -= r.shots
	r.chance = hit_chance(unit, target)
	var crit_c := crit_chance(unit)
	var aim := atan2(target.pos.y - unit.pos.y, target.pos.x - unit.pos.x)
	var spread := deg_to_rad(Rules.BURST_SPREAD)
	var split := Rules.burst_split(r.shots)
	var angles := []
	for i in split[0]:
		angles.append(aim)
	for i in split[1]:
		angles.append(aim + spread)
	for i in split[2]:
		angles.append(aim - spread)
	var crits := 0
	var strays := {}       # 别人被打中: {人: 伤害}
	var stray_order := []  # 按先后记下谁被打中
	for angle in angles:
		var traced := _trace(unit, angle, w.reach)
		var hit_who: Unit = null
		for person in traced[0]:
			var p_chance := r.chance if person == target else hit_chance(unit, person)
			if dice.roll(1, 100) > p_chance:
				continue
			var crit: bool = person == target and dice.roll(1, 100) <= crit_c
			var dealt := Rules.damage_after_armor(dice.roll(w.dmg_min, w.dmg_max), crit, person.armor)
			person.hp = maxi(0, person.hp - dealt)
			if person == target:
				r.hits += 1
				crits += 1 if crit else 0
				r.damage += dealt
			else:
				if not strays.has(person):
					stray_order.append(person)
				strays[person] = strays.get(person, 0) + dealt
			hit_who = person
			break
		r.paths.append([Vector2(hit_who.pos) if hit_who != null else traced[1], hit_who])
	for u in stray_order:
		r.strays.append([u, strays[u], not u.alive()])
	r.hit = r.hits > 0
	r.crit = crits > 0
	r.killed = not target.alive()
	events.append({"kind": "attack", "result": r})
	var text := "%s用%s连发打%s (每发命中 %d%%)……" % [unit.name, w.name, target.name, r.chance]
	if r.hits == 0:
		text += "%d 发都没打中他。" % r.shots
	else:
		text += "%d 发里打中他 %d 发" % [r.shots, r.hits]
		if crits > 0:
			text += ", 有 %d 发暴击" % crits
		text += ", 一共 %d 点伤害。" % r.damage
	say(text, _kind(unit))
	if r.killed:
		say("%s倒下了。" % target.name, _victim_kind(target))
	var anyone_down := r.killed
	for s in r.strays:
		say("有子弹打中了%s, %d 点伤害。" % [s[0].name, s[1]], _victim_kind(s[0]))
		if s[2]:
			say("%s倒下了。" % s[0].name, _victim_kind(s[0]))
			anyone_down = true
	if anyone_down:
		_check_end()
	return r


## 从这个人这里往 angle 方向画一条线, 一直到射程或者地图边上。
## 返回 [线上碰到的活人 (按先后), 线的终点 (格子坐标, 可以是小数)]
func _trace(unit: Unit, angle: float, max_range: int) -> Array:
	var start := Vector2(unit.pos)
	var dir := Vector2(cos(angle), sin(angle))
	var people := []
	var end := start
	var t := 0.5
	while true:
		var pt := start + dir * t
		var tile := Vector2i(floori(pt.x + 0.5), floori(pt.y + 0.5))
		if not in_bounds(tile) or Rules.distance(unit.pos, tile) > max_range:
			break
		end = pt
		var u := unit_at(tile)
		if u != null and u != unit and not people.has(u):
			people.append(u)
		t += 0.25
	return [people, end]


## 扔手雷: 扔准了落在瞄的那一格, 扔偏了落在旁边 1～2 格。
## 落点周围 3×3 里的人都被炸到 (包括自己和同伴), 每个人分开算伤害, 再过护甲。
func _throw(unit: Unit, aim: Vector2i) -> ThrowResult:
	var w := unit.weapon()
	unit.ap -= w.ap
	unit.loaded[unit.active] -= 1
	if unit.loaded[unit.active] <= 0:
		unit.hands[unit.active] = ""  # 手雷扔完了, 手空了
		unit.loaded[unit.active] = 0
	var r := ThrowResult.new()
	r.attacker = unit
	r.weapon = w
	r.aim = aim
	r.chance = Rules.hit_chance(unit.stats, w, 0, Rules.distance(unit.pos, aim), 0, 0, unit.blind)  # 不减防御
	r.hit = dice.roll(1, 100) <= r.chance
	r.landing = aim
	if not r.hit:
		var spots := []
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				var p := aim + Vector2i(dx, dy)
				if (dx != 0 or dy != 0) and in_bounds(p):
					spots.append(p)
		if not spots.is_empty():
			r.landing = dice.pick(spots)
	for u in units:
		if u.alive() and Rules.distance(u.pos, r.landing) <= Rules.BLAST_RADIUS:
			var dealt := Rules.damage_after_armor(dice.roll(w.dmg_min, w.dmg_max), false, u.armor)
			u.hp = maxi(0, u.hp - dealt)
			r.victims.append([u, dealt, not u.alive()])
	events.append({"kind": "throw", "result": r})
	say("%s扔出手雷 (命中 %d%%)……%s" % [unit.name, r.chance, "扔准了!" if r.hit else "扔偏了!"], _kind(unit))
	if r.victims.is_empty():
		say("手雷炸了, 没炸到人。", "info")
	for v in r.victims:
		say("%s被炸到, %d 点伤害。" % [v[0].name, v[1]], _victim_kind(v[0]))
		if v[2]:
			say("%s倒下了。" % v[0].name, _victim_kind(v[0]))
	_check_end()
	if result == "" and not unit.alive():
		end_turn()  # 把自己炸倒了, 剩下的点数也用不了了
	return r


## 冲锋枪换成连发 / 单发, 不花点数
func toggle_burst(unit: Unit) -> bool:
	if _not_your_turn(unit) != "" or unit.weapon().burst_ap == 0:
		return false
	unit.burst[unit.active] = not unit.burst[unit.active]
	var mode := "连发" if unit.burst[unit.active] else "单发"
	say("%s的%s换成%s。" % [unit.name, unit.weapon().name, mode], _kind(unit))
	return true


func _check_end() -> void:
	# 两边同时倒下 (比如手雷连自己一起炸了) 算输
	if not units.any(func(u: Unit) -> bool: return u.side == Unit.PLAYER and u.alive()):
		result = "lost"
		say("这一局输了。", "bad")
	elif not units.any(func(u: Unit) -> bool: return u.side == Unit.ENEMY and u.alive()):
		result = "won"
		say("敌人全倒下了, 你赢了!", "good")


# ---------- 换子弹、换手 ----------

func reload_problem(unit: Unit) -> String:
	var why := _not_your_turn(unit)
	if why != "":
		return why
	if unit.arms_crippled() > 0 and unit.weapon_id() != "kick" and not unit.hand_ok(unit.active):
		return "%s废了" % Unit.HAND_NAMES[unit.active]
	var w := unit.weapon()
	if w.magazine == 0:
		return "%s不用子弹" % w.name
	if unit.ammo_in_hand() >= w.magazine:
		return "子弹是满的"
	if unit.spare.get(unit.weapon_id(), 0) <= 0:
		return "没有备用子弹了"
	if unit.ap < Rules.RELOAD_AP:
		return "行动点不够 (要 %d 点)" % Rules.RELOAD_AP
	return ""


## 把手上的枪装满 (用备用子弹), 花 2 点
func reload(unit: Unit) -> bool:
	if reload_problem(unit) != "":
		return false
	var w := unit.weapon()
	var n := mini(w.magazine - unit.ammo_in_hand(), unit.spare[unit.weapon_id()])
	unit.loaded[unit.active] += n
	unit.spare[unit.weapon_id()] -= n
	unit.ap -= Rules.RELOAD_AP
	events.append({"kind": "reload", "unit": unit})
	say("%s换了子弹 (%s %d/%d)。" % [unit.name, w.name, unit.ammo_in_hand(), w.magazine], _kind(unit))
	return true


## 换用另一只手的武器, 不花点数
func switch_hand(unit: Unit) -> bool:
	if _not_your_turn(unit) != "":
		return false
	unit.active = 1 - unit.active
	events.append({"kind": "switch", "unit": unit})
	say("%s换成%s的%s。" % [unit.name, Unit.HAND_NAMES[unit.active], unit.weapon().name], _kind(unit))
	return true


# ---------- 地上的武器 ----------

func item_at(p: Vector2i) -> GroundItem:
	for item in ground:
		if item.pos == p:
			return item
	return null


## 能拿东西的空手: 先看现在用的这只, 再看另一只; 没有返回 -1
func free_hand(unit: Unit) -> int:
	for hand in [unit.active, 1 - unit.active]:
		if unit.hands[hand] == "" and unit.hand_ok(hand):
			return hand
	return -1


func pickup_problem(unit: Unit, item: GroundItem) -> String:
	var why := _not_your_turn(unit)
	if why != "":
		return why
	if Rules.distance(unit.pos, item.pos) > 1:
		return "要走到旁边才能捡"
	if unit.arms_crippled() == 2:
		return "两只手都废了, 捡不了"
	if free_hand(unit) < 0:
		return "两只手都拿着东西"
	var w: Gear.Weapon = Gear.WEAPONS[item.weapon_id]
	if w.hands == 2 and unit.arms_crippled() > 0:
		return "%s要两只手都好才能用" % w.name
	if unit.ap < Rules.PICKUP_AP:
		return "行动点不够 (要 %d 点)" % Rules.PICKUP_AP
	return ""


## 捡起地上的武器 (站在旁边就能捡), 花 2 点, 拿在空着的手上并换成用它
func pickup(unit: Unit, item: GroundItem) -> bool:
	if pickup_problem(unit, item) != "":
		return false
	var hand := free_hand(unit)
	unit.hands[hand] = item.weapon_id
	unit.loaded[hand] = item.loaded
	unit.burst[hand] = false  # 捡起来的枪先是单发
	unit.active = hand
	unit.ap -= Rules.PICKUP_AP
	ground.erase(item)
	events.append({"kind": "pickup", "unit": unit, "item": item})
	say("%s捡起了%s。" % [unit.name, Gear.WEAPONS[item.weapon_id].name], _kind(unit))
	return true


# ---------- 其他 ----------

## 这个人做的事, 在战斗记录里用什么颜色
static func _kind(unit: Unit) -> String:
	return "player" if unit.side == Unit.PLAYER else "enemy"


## 这个人挨打、倒下: 是你这边的就是坏消息, 是敌人就是好消息
static func _victim_kind(unit: Unit) -> String:
	return "bad" if unit.side == Unit.PLAYER else "good"


func say(text: String, kind := "info") -> void:
	messages.append([text, kind])


## 画面拿走新发生的事 (拿走以后就清空)
func take_events() -> Array:
	var taken := events
	events = []
	return taken
