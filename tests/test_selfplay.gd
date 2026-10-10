extends TestCase
## 让电脑自己打几百局, 每一步都检查数字对不对; 还有 2026-10-05 检查代码时修好的毛病

const P := Unit.PLAYER
const E := Unit.ENEMY


## 每一步都检查: 数字没有出范围、人没有叠在一起
func check_state(b: Battle) -> void:
	var seen := {}
	for u in b.units:
		check(u.hp >= 0 and u.hp <= u.max_hp, "生命出范围 %s" % u)
		check(u.ap >= 0, "行动点是负的 %s" % u)
		check(u.stress >= 0 and u.stress <= Rules.STRESS_MAX, "压力出范围 %s %d" % [u, u.stress])
		check(b.in_bounds(u.pos), "出了地图 %s" % u)
		for hand in 2:
			var wid: String = u.hands[hand]
			if wid != "" and Gear.WEAPONS[wid].kind == "throw":
				check(u.loaded[hand] >= 1, "手雷个数不对 %s" % u)
			else:
				var mag: int = Gear.WEAPONS[wid].magazine if wid != "" else 0
				check(u.loaded[hand] >= 0 and u.loaded[hand] <= mag, "子弹数不对 %s" % u)
			if not u.hand_ok(hand):
				check(wid == "", "废了的手还拿着东西 %s" % u)
			if u.jammed[hand]:
				check(wid != "" and Gear.WEAPONS[wid].kind == "gun", "卡住的不是枪 %s" % u)
		for count in u.spare.values():
			check(count >= 0, "备用子弹是负的 %s" % u)
		check(Inventory.room(u) >= 0, "背的东西超重了 %s" % u)
		if u.alive():
			check(not seen.has(u.pos), "两个人站在同一格")
			seen[u.pos] = true
	for item in b.ground:
		check(b.in_bounds(item.pos))
		check(item.loaded >= 0)
	if b.result == "":
		check(b.current().alive(), "轮到的人已经倒下了")
		check(not b.current().knocked_out, "晕着的人不该轮到")


## 电脑替两边打完一局; 返回结果, 打不完返回 ""
func play_out(b: Battle, limit := 3000) -> String:
	var steps := 0
	while b.result == "":
		steps += 1
		if steps > limit:
			return ""
		if not AI.act(b, b.current()):
			b.end_turn()
		check_state(b)
	return b.result


func test_computer_plays_both_sides() -> void:
	# 电脑替两边打 300 局: 每局都能打完, 数字一直对
	var won := 0
	var lost := 0
	for seed_value in 300:
		var b := Practice.make_battle(Dice.new(seed_value))
		var res := play_out(b)
		check(res != "", "第 %d 局打不完" % seed_value)
		check(b.round_no < 40)
		if res == "won":
			won += 1
		else:
			lost += 1
	# 强盗调得比你弱, 电脑替你打也应该赢多输少 (2026-10-05 量的大约七成)
	check(won > lost, "赢 %d 输 %d" % [won, lost])


func test_every_loadout() -> void:
	# 每种武器都让电脑替你打十几局: 能打完, 数字一直对
	for wid in Gear.CHOICES:
		for burst in ([false, true] if Gear.WEAPONS[wid].burst_ap > 0 else [false]):
			for seed_value in 15:
				var setup := Practice.Setup.new()
				setup.choose([wid, "knife"])
				var b := Practice.make_battle(Dice.new(seed_value), setup)
				b.units[0].burst[0] = burst
				check(play_out(b, 4000) != "", "%s 第 %d 局打不完" % [wid, seed_value])


func test_panicky_battles() -> void:
	# 大家一开打就快吓呆了 (压力 95): 大失败 (卡住、脱手、打歪、摔倒、手雷扔歪) 一直出, 也能打完, 数字一直对
	var fumbles := {}
	for seed_value in 200:
		var setup := Practice.Setup.new()
		var wid: String = Gear.CHOICES[seed_value % Gear.CHOICES.size()]
		setup.choose([wid, "fist" if wid == "fist" else "knife"])  # 空手的两只手都空着, 才会用拳头
		var b := Practice.make_battle(Dice.new(seed_value + 5000), setup)
		for u in b.units:
			u.stress = 95
		var steps := 0
		while b.result == "":
			steps += 1
			if steps > 4000:
				check(false, "第 %d 局打不完" % seed_value)
				break
			if not AI.act(b, b.current()):
				b.end_turn()
			for e in b.take_events():
				if e["kind"] == "fumble":
					fumbles[e["result"].fumble] = true
				elif e["kind"] == "throw" and e["result"].fumble != "":
					fumbles["wild_throw"] = true
			check_state(b)
	for what in ["jam", "drop", "wild", "fall", "wild_throw"]:
		check(fumbles.has(what), "200 局里一次「%s」都没出" % what)


func test_random_player() -> void:
	# 玩家乱点 (乱走、乱打、乱瞄准、乱捡、乱换手、乱换子弹): 规则也不会出错
	for seed_value in 120:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var b := Practice.make_battle(Dice.new(seed_value + 1000))
		var you: Unit = b.units[0]
		var steps := 0
		while b.result == "":
			steps += 1
			if steps > 5000:
				check(false, "第 %d 局打不完" % seed_value)
				break
			if b.current() == you:
				var c := rng.randf()
				if c < 0.35:
					b.move(you, Vector2i(rng.randi_range(-1, 14), rng.randi_range(-1, 14)))
				elif c < 0.5:
					b.attack(you, b.units[rng.randi_range(0, 2)])
				elif c < 0.65:
					var part: String = Rules.BODY_PARTS[rng.randi_range(0, 7)][0]
					b.attack(you, b.units[rng.randi_range(0, 2)], part)
					if not b.ground.is_empty() and rng.randf() < 0.5:
						b.pickup(you, b.ground[rng.randi_range(0, b.ground.size() - 1)])
				elif c < 0.72:
					b.switch_hand(you)
				elif c < 0.8:
					b.reload(you)
				else:
					b.end_turn()
			elif not AI.act(b, b.current()):
				b.end_turn()
			check_state(b)


# ---------- 2026-10-05 检查代码时修好的毛病 ----------

func test_ai_does_not_switch_hands_forever() -> void:
	# 一手手雷、一手空着, 对头就在旁边: 以前会来回换手停不下来
	var you := person("你", P, Vector2i(3, 3), 5, 5, 5, ["grenade", ""])
	var foe := person("敌", E, Vector2i(4, 4), 5, 5, 5, ["knife", ""])
	var b := Battle.new([you, foe], 14, 14, TestCase.FixedDice.new([50, 50, 50, 50, 50, 50]))
	var stopped := false
	for i in 20:
		if not AI.act(b, you):
			stopped = true
			break
	check(stopped, "20 次还没停下来")


func test_ai_switches_once_to_the_better_hand() -> void:
	var you := person("你", P, Vector2i(3, 3), 5, 5, 5, ["grenade", "knife"])
	var foe := person("敌", E, Vector2i(4, 4))
	var b := Battle.new([you, foe], 14, 14, TestCase.FixedDice.new([50, 50, 50, 50, 50, 50]))
	check(AI.act(b, you), "换成小刀")
	eq(you.weapon().name, "小刀")
	check(AI.act(b, you), "用小刀打, 不会再换回手雷")
	eq(you.weapon().name, "小刀")
	check(b.messages.any(func(m): return String(m[0]).contains("用小刀打")))


func test_ai_grenade_short_of_points_stays() -> void:
	# 手雷够得着、只是点数不够扔: 待着不动 (以前会走进自己的爆炸范围)
	var you := person("你", P, Vector2i(0, 0), 5, 5, 5, ["grenade", ""])
	var foe := person("敌", E, Vector2i(6, 0))
	var b := Battle.new([you, foe], 14, 14, TestCase.FixedDice.new())
	you.ap = 3
	check(not AI.act(b, you))
	eq(you.pos, Vector2i(0, 0))


func test_dead_cannot_act() -> void:
	var you := person("你", P, Vector2i(0, 0))
	var foe := person("敌", E, Vector2i(3, 0))
	var b := Battle.new([you, foe], 14, 14, TestCase.FixedDice.new())
	you.hp = 0
	eq(b.attack_problem(you, foe), "已经倒下了")
	check(not b.move(you, Vector2i(1, 1)))
	check(not b.switch_hand(you))
	check(not AI.act(b, you))


func test_blowing_yourself_up_ends_your_turn() -> void:
	# 手雷把自己炸倒了 (别人还活着): 回合马上结束, 轮到下一个人
	var you := person("你", P, Vector2i(0, 0))
	var thrower := person("扔的", E, Vector2i(1, 0), 5, 5, 5, ["grenade", "pistol"])  # 站得太近, 自己也在范围里
	var other := person("另一个", E, Vector2i(9, 9))
	thrower.hp = 1
	var b := Battle.new([you, thrower, other], 10, 10, TestCase.FixedDice.new([1, 10, 10]), thrower)
	b.attack(thrower, you)
	check(not thrower.alive())
	eq(b.result, "")
	check(b.current() != thrower)
	check(b.current().alive())


func test_burst_switch_belongs_to_the_gun() -> void:
	# 连发开关记在枪上: 换到另一只手的冲锋枪还是单发; 捡起来的枪也是单发
	var you := person("你", P, Vector2i(0, 0), 5, 5, 5, ["smg", "smg"])
	var foe := person("敌", E, Vector2i(5, 0))
	var b := Battle.new([you, foe], 10, 10, TestCase.FixedDice.new())
	b.toggle_burst(you)
	check(you.bursting())
	b.switch_hand(you)
	check(not you.bursting())
	b.switch_hand(you)
	check(you.bursting())
	you.crippled["right_arm"] = true
	var item: Battle.GroundItem = b._drop(you, 0)
	eq(you.burst, [false, false])
	you.crippled.clear()
	you.hands[1] = ""
	you.active = 1
	item.pos = Vector2i(1, 0)
	check(b.pickup(you, item))
	check(not you.bursting())


func test_path_within() -> void:
	var you := person("你", P, Vector2i(0, 0))
	var foe := person("敌", E, Vector2i(9, 9))
	var b := Battle.new([you, foe], 10, 10, TestCase.FixedDice.new())
	eq(b.path_within(you, Vector2i(5, 0), 1).size(), 4)
	eq(b.path_within(you, Vector2i(1, 1), 1), [])
