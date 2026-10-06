extends TestCase
## 第 3 步: 冲锋枪连发 (照原版散开)、手雷; 还有开打前的准备

const P := Unit.PLAYER
const E := Unit.ENEMY


func fixed(rolls := []) -> Dice:
	return TestCase.FixedDice.new(rolls)


func repeat(seq: Array, times: int) -> Array:
	var out := []
	for i in times:
		out.append_array(seq)
	return out


func test_burst_close_range() -> void:
	# 离得近 (3 格): 往两边歪的子弹也都落在目标身上
	var you := person("你", P, Vector2i(0, 0), 6, 5, 5, ["smg", ""], "none", {"smg": 20})
	var foe := person("敌", E, Vector2i(3, 0))
	foe.hp = 200
	foe.max_hp = 200
	# 10 发都打中, 第 3 发暴击
	var rolls := repeat([1, 100, 5], 2) + [1, 1, 9] + repeat([1, 100, 5], 7)
	var b := Battle.new([you, foe], 14, 14, fixed(rolls))
	check(not b.toggle_burst(foe), "还没轮到他")
	check(b.toggle_burst(you))
	eq(b.attack_cost(you), 6)
	eq(b.attack_problem(you, foe, "head"), "连发不能瞄准")
	var r: Battle.AttackResult = b.attack(you, foe)
	eq([r.shots, r.hits, r.crit], [10, 10, true])
	eq(r.damage, 5 * 9 + 18)
	eq(you.ammo_in_hand(), 10)
	eq(you.ap, 8 - 6)
	has_text(b.messages[-1][0], "10 发里打中他 10 发, 有 1 发暴击")
	eq(r.paths.size(), 10)


func far_battle(rolls: Array, others := []) -> Array:
	var you := person("你", P, Vector2i(0, 5), 6, 5, 5, ["smg", ""])
	var foe := person("敌", E, Vector2i(10, 5))
	you.burst[0] = true
	var b := Battle.new([you, foe] + others, 15, 11, fixed(rolls))
	return [b, you, foe]


func test_burst_spreads_far() -> void:
	# 离得远 (10 格): 只有对准的 4 发打得到他, 往两边歪的 6 发飞走了
	var f := far_battle(repeat([1, 100, 5], 3) + [1, 1, 9])
	var r: Battle.AttackResult = f[0].attack(f[1], f[2])
	eq([r.hits, r.damage, r.strays], [4, 5 * 3 + 18, []])
	eq(r.paths.filter(func(p): return p[1] == null).size(), 6)


func test_burst_hits_someone_beside() -> void:
	# 歪出去的子弹打中站在旁边的人
	var other := person("乙", E, Vector2i(10, 7))
	var f := far_battle(repeat([1, 100, 5], 4) + [1, 6, 100, 100], [other])
	var b: Battle = f[0]
	var r: Battle.AttackResult = b.attack(f[1], f[2])
	eq(r.hits, 4)
	eq(r.strays.size(), 1)
	eq([r.strays[0][0].name, r.strays[0][1]], ["乙", 6])
	has_text(b.messages[-1][0], "有子弹打中了乙, 6 点伤害。")


func test_burst_can_hit_your_own_side() -> void:
	# 挡在中间的同伴会先被算: 打中了就停在他身上
	var friend := person("同伴", P, Vector2i(5, 5))
	var f := far_battle([1, 4] + repeat([100, 100], 3), [friend])
	var b: Battle = f[0]
	var r: Battle.AttackResult = b.attack(f[1], f[2])
	eq(r.hits, 0)
	eq(friend.hp, friend.max_hp - 4)
	check(r.strays[0][0] == friend)
	eq(b.messages[-1][1], "bad")


func test_burst_with_few_bullets_and_stops_after_kill() -> void:
	var you := person("你", P, Vector2i(0, 0), 5, 5, 5, ["smg", ""])
	var foe := person("敌", E, Vector2i(3, 0))
	you.burst[0] = true
	you.loaded[0] = 3
	foe.hp = 4
	var b := Battle.new([you, foe], 14, 14, fixed([1, 100, 9]))
	var r: Battle.AttackResult = b.attack(you, foe)
	eq(r.shots, 3)
	eq(r.hits, 1, "第一发就打倒了, 剩下的打空")
	check(r.killed)
	eq(you.ammo_in_hand(), 0)
	eq(b.result, "won")


func test_burst_only_for_smg() -> void:
	var you := person("你", P, Vector2i(0, 0), 5, 5, 5, ["pistol", ""])
	var foe := person("敌", E, Vector2i(3, 0))
	var b := Battle.new([you, foe], 14, 14, fixed())
	check(not b.toggle_burst(you))
	you.burst[0] = true  # 就算开着, 手枪也还是单发
	eq(b.attack_cost(you), 4)


func test_grenade_range_and_blast() -> void:
	var you := person("你", P, Vector2i(0, 0), 5, 5, 3, ["grenade", "pistol"], "none", {"grenade": 2})
	var a := person("甲", E, Vector2i(5, 5))
	var c := person("乙", E, Vector2i(6, 6))
	var far := person("远", E, Vector2i(7, 9))
	var b := Battle.new([you, a, c, far], 12, 12, fixed([1, 10, 20]))
	eq(you.loaded, [2, 8])
	eq(b.attack_range(you), 6)
	has_text(b.attack_problem(you, far), "太远了")
	eq(b.attack_problem(you, a, "head"), "手雷不能瞄准")
	eq(b.hit_chance(you, a), 40 + 25, "手雷不减防御")
	var r: Battle.ThrowResult = b.attack(you, a)
	check(r.hit)
	eq(r.landing, Vector2i(5, 5))
	eq(r.victims.map(func(v): return [v[0].name, v[1]]), [["甲", 10], ["乙", 20]])
	eq(you.ammo_in_hand(), 1)
	eq(you.ap, 7 - 5)


func test_last_grenade_empties_hand_and_miss_lands_nearby() -> void:
	var you := person("你", P, Vector2i(0, 0), 5, 5, 5, ["grenade", ""])
	var foe := person("敌", E, Vector2i(4, 4))
	var b := Battle.new([you, foe], 10, 10, fixed([100]))
	var r: Battle.ThrowResult = b.attack(you, foe)
	check(not r.hit)
	check(r.landing != Vector2i(4, 4))
	check(Rules.distance(r.landing, Vector2i(4, 4)) <= 2)
	eq(you.hands, ["", ""])
	check(b.messages.any(func(m): return String(m[0]).contains("扔偏了")))


func test_grenade_can_hurt_yourself_and_both_dead_is_lost() -> void:
	var you := person("你", P, Vector2i(0, 0), 5, 5, 5, ["grenade", ""])
	var foe := person("敌", E, Vector2i(1, 0))
	you.hp = 1
	foe.hp = 1
	var b := Battle.new([you, foe], 14, 14, fixed([1, 10, 10]))
	var r: Battle.ThrowResult = b.attack(you, foe)
	var names := r.victims.map(func(v): return v[0].name)
	names.sort()
	eq(names, ["你", "敌"])
	eq(b.result, "lost")


func test_setup_points() -> void:
	var s := Practice.Setup.new()
	var total := 0
	for v in s.stats.values():
		total += v
	eq(total, 24)
	check(s.ready())
	check(not s.change("agility", 1))
	check(s.change("resolve", -1))
	check(not s.ready())
	check(s.change("agility", 1))
	for i in 5:
		s.change("intellect", -1)
	eq(s.stats["intellect"], 1)


func test_setup_makes_player() -> void:
	var s := Practice.Setup.new()
	s.hands = ["fist", "rifle"]
	s.armor = "none"
	var you := s.make_player()
	eq(you.hands, ["", "rifle"])
	eq(you.spare, {"rifle": 15})
	eq(you.weapon().name, "拳头")
	s.hands = ["smg", "grenade"]
	you = s.make_player()
	eq(you.loaded, [20, 3])
	eq(you.spare, {"smg": 20})
