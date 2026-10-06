extends TestCase
## 战斗公式的测试 (数字照看板「战斗系统」卡片上定的)


func s(agility := 5, vigor := 5, observation := 5) -> Dictionary:
	return Practice.stats(1, agility, vigor, 1, observation, 1)


func test_action_points() -> void:
	# 行动点 = 5 + 灵巧 ÷ 2 (舍掉小数)
	eq(Rules.action_points(1), 5)
	eq(Rules.action_points(6), 8)
	eq(Rules.action_points(7), 8)
	eq(Rules.action_points(10), 10)


func test_hp_and_melee_bonus() -> void:
	eq(Rules.max_hp(1), 18)
	eq(Rules.max_hp(10), 45)
	eq(Rules.melee_bonus(5), 2)
	eq(Rules.melee_bonus(10), 5)


func test_defense() -> void:
	eq(Rules.defense(4, 5, 1), 11)


func test_distance_counts_diagonal_as_one() -> void:
	eq(Rules.distance(Vector2i(0, 0), Vector2i(3, 3)), 3)
	eq(Rules.distance(Vector2i(0, 0), Vector2i(3, 1)), 3)


func test_hit_chance_example_from_board() -> void:
	# 看板上的例子: 灵巧 6、洞察 5、用枪 1 级, 手枪打 7 格外防御 11 的强盗 → 56%
	eq(Rules.hit_chance(s(6, 5, 5), Gear.WEAPONS["pistol"], 11, 7, 0, 5), 56)


func test_hit_chance_melee() -> void:
	# 近身: 40 + 灵巧 × 3 + 体魄 × 2 + 准头, 不看距离
	eq(Rules.hit_chance(s(6, 5), Gear.WEAPONS["knife"], 10, 1), 40 + 18 + 10 + 5 - 10)


func test_no_distance_penalty_within_observation() -> void:
	var st := s(5, 5, 6)
	eq(Rules.hit_chance(st, Gear.WEAPONS["pistol"], 0, 6), 65)
	eq(Rules.hit_chance(st, Gear.WEAPONS["pistol"], 0, 8), 65 - 8)


func test_hit_chance_limits() -> void:
	eq(Rules.hit_chance(s(10), Gear.WEAPONS["rifle"], 0, 1), 95)
	eq(Rules.hit_chance(s(1), Gear.WEAPONS["pistol"], 50, 15), 5)


func test_crit_chance() -> void:
	eq(Rules.crit_chance(5), 10)
	eq(Rules.crit_chance(5, 20), 30)


func test_damage_example_from_board() -> void:
	# 看板上的例子: 9 点打皮甲, 先减 2 再打 8 折, 5.6 算 6 点
	eq(Rules.damage_after_armor(9, false, Gear.ARMORS["leather"]), 6)


func test_crit_doubles_before_armor() -> void:
	eq(Rules.damage_after_armor(9, true, Gear.ARMORS["leather"]), 13)  # (18-2)*0.8=12.8


func test_armor_can_stop_everything() -> void:
	eq(Rules.damage_after_armor(4, false, Gear.ARMORS["metal"]), 0)
	eq(Rules.damage_after_armor(3, false, Gear.ARMORS["none"]), 3)


func test_rounds_half_up() -> void:
	eq(Rules.damage_after_armor(5, false, Gear.Armor.new("t", "测试甲", 0, 0, 50)), 3)  # 2.5 算 3


func test_burst_split() -> void:
	eq(Rules.burst_split(10), [4, 3, 3])
	eq(Rules.burst_split(5), [2, 2, 1])
	eq(Rules.burst_split(1), [1, 0, 0])


func test_numbers_match_board() -> void:
	# 武器表跟看板上定的一样: [伤害下限, 上限, 花几点, 射程, 准头, 弹夹]
	var expected := {
		"fist": [1, 3, 3, 1, 0, 0], "knife": [2, 6, 3, 1, 5, 0], "pipe": [3, 7, 4, 1, 0, 0],
		"sledgehammer": [6, 14, 4, 1, -10, 0], "pistol": [5, 12, 4, 15, 0, 8],
		"rifle": [8, 18, 5, 30, 10, 5], "smg": [4, 9, 4, 15, -5, 20],
	}
	for wid in expected:
		var w: Gear.Weapon = Gear.WEAPONS[wid]
		eq([w.dmg_min, w.dmg_max, w.ap, w.reach, w.accuracy, w.magazine], expected[wid], wid)
	eq(Gear.WEAPONS["smg"].burst_ap, 6)
	eq(Gear.WEAPONS["sledgehammer"].hands, 2)
	var armors := []
	for aid in Gear.ARMOR_ORDER:
		var a: Gear.Armor = Gear.ARMORS[aid]
		armors.append([a.defense, a.threshold, a.resist])
	eq(armors, [[0, 0, 0], [5, 2, 20], [10, 4, 30]])
	eq(Gear.SPARE_AMMO, {"pistol": 24, "rifle": 15, "smg": 20})
	eq(Rules.BURST_ROUNDS, 10)
