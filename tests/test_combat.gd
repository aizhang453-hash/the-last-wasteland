extends TestCase
## 战斗的测试: 轮流、走路、攻击、换子弹、换手

const P := Unit.PLAYER
const E := Unit.ENEMY


func dice(rolls := []) -> Dice:
	return TestCase.FixedDice.new(rolls)


# ---------- 轮流 ----------

func test_initiator_first_then_reaction_order() -> void:
	# 先动手的先打第一下; 之后按反应值 (洞察) 排, 一样比灵巧, 还一样玩家先
	var you := person("你", P, Vector2i(0, 0), 5, 3)
	var fast := person("快", E, Vector2i(5, 5), 5, 7)
	var tie := person("平", E, Vector2i(6, 6), 5, 3)
	var b := Battle.new([you, fast, tie], 14, 14, dice())
	eq(b.order.map(func(u): return u.name), ["你", "快", "平"])
	for i in 3:
		b.end_turn()
	eq(b.round_no, 2)
	eq(b.order.map(func(u): return u.name), ["快", "你", "平"])


func test_tie_breaks_by_agility() -> void:
	var you := person("你", P, Vector2i(0, 0), 4, 5)
	var quick := person("灵", E, Vector2i(5, 5), 6, 5)
	var b := Battle.new([you, quick], 14, 14, dice())
	b.end_turn()
	b.end_turn()
	eq(b.order.map(func(u): return u.name), ["灵", "你"])


func test_leftover_points_become_defense_and_do_not_carry() -> void:
	var you := person("你", P, Vector2i(0, 0), 6)
	var foe := person("敌", E, Vector2i(9, 9))
	var b := Battle.new([you, foe], 14, 14, dice())
	eq(you.ap, 8)
	b.move(you, Vector2i(1, 1))
	b.end_turn()
	eq(you.leftover, 7)
	eq(you.defense(), 6 + 7 * 2)
	b.end_turn()  # 又轮到你: 点数重新给满, 防御加成没了
	eq(you.ap, 8)
	eq(you.defense(), 6)


func test_dead_are_skipped() -> void:
	var you := person("你", P, Vector2i(0, 0))
	var a := person("甲", E, Vector2i(5, 5))
	var c := person("乙", E, Vector2i(6, 6))
	var b := Battle.new([you, a, c], 14, 14, dice())
	a.hp = 0
	b.end_turn()
	check(b.current() == c)


# ---------- 走路 ----------

func walk_battle() -> Array:
	var you := person("你", P, Vector2i(2, 2), 2)  # 6 点
	var foe := person("敌", E, Vector2i(4, 4))
	return [Battle.new([you, foe], 10, 10, dice()), you, foe]


func test_diagonal_step_costs_one() -> void:
	var w := walk_battle()
	check(w[0].move(w[1], Vector2i(3, 3)))
	eq(w[1].ap, 5)


func test_cannot_walk_too_far_or_onto_people() -> void:
	var w := walk_battle()
	var b: Battle = w[0]
	var you: Unit = w[1]
	check(not b.move(you, Vector2i(9, 2)), "要 7 点")
	check(not b.move(you, Vector2i(4, 4)), "有人")
	check(not b.move(you, Vector2i(10, 2)), "出了地图")
	eq(you.pos, Vector2i(2, 2))
	eq(you.ap, 6)


func test_walks_around_people() -> void:
	var w := walk_battle()
	var b: Battle = w[0]
	b.units.append(person("挡", P, Vector2i(3, 2)))
	var path: Array = b.find_path(w[1], Vector2i(4, 2))
	eq(path.size(), 2)
	check(not path.has(Vector2i(3, 2)))


func test_reachable() -> void:
	var w := walk_battle()
	var tiles: Dictionary = w[0].reachable(w[1])
	eq(tiles[Vector2i(8, 2)], 6)
	check(not tiles.has(Vector2i(9, 2)))
	check(not tiles.has(Vector2i(4, 4)), "有人站着")
	check(not tiles.has(Vector2i(8, 8)), "斜着直走要穿过敌人, 绕路要 7 步")


func test_move_event_has_full_path() -> void:
	var w := walk_battle()
	var b: Battle = w[0]
	b.move(w[1], Vector2i(2, 5))
	var events := b.take_events()
	eq(events.size(), 1)
	eq(events[0]["kind"], "move")
	eq(events[0]["path"], [Vector2i(2, 2), Vector2i(2, 3), Vector2i(2, 4), Vector2i(2, 5)])
	eq(b.take_events(), [])


# ---------- 攻击 ----------

func test_hit_uses_ap_ammo_and_armor() -> void:
	var you := person("你", P, Vector2i(0, 0), 6, 5)
	var foe := person("敌", E, Vector2i(3, 0), 4, 5, 5, ["pistol", ""], "leather")
	# 掷骰子: 命中掷 1 (中), 暴击掷 100 (没暴击), 伤害掷 9
	var b := Battle.new([you, foe], 14, 14, dice([1, 100, 9]))
	var r: Battle.AttackResult = b.attack(you, foe)
	check(r.hit)
	check(not r.crit)
	eq(r.damage, 6)
	eq(foe.hp, foe.max_hp - 6)
	eq(you.ap, 8 - 4)
	eq(you.ammo_in_hand(), 7)
	eq(r.chance, 40 + 30 - (4 + 5))


func test_miss_when_roll_too_high() -> void:
	var you := person("你", P, Vector2i(0, 0))
	var foe := person("敌", E, Vector2i(3, 0))
	var b := Battle.new([you, foe], 14, 14, dice([96]))
	var r: Battle.AttackResult = b.attack(you, foe)
	check(not r.hit)
	eq(foe.hp, foe.max_hp)
	has_text(b.messages[-1][0], "没打中")


func test_crit_doubles() -> void:
	var you := person("你", P, Vector2i(0, 0), 5, 5)
	var foe := person("敌", E, Vector2i(3, 0))
	var b := Battle.new([you, foe], 14, 14, dice([1, 10, 7]))  # 暴击几率 10%, 掷 10 算暴击
	var r: Battle.AttackResult = b.attack(you, foe)
	check(r.crit)
	eq(r.damage, 14)
	has_text(b.messages[-1][0], "暴击")


func test_melee_needs_to_be_next_to() -> void:
	var you := person("你", P, Vector2i(0, 0), 5, 5, 5, ["knife", ""])
	var foe := person("敌", E, Vector2i(2, 1))
	var b := Battle.new([you, foe], 14, 14, dice())
	eq(b.attack_problem(you, foe), "要走到旁边才能打")
	foe.pos = Vector2i(1, 1)  # 斜着挨着也算
	eq(b.attack_problem(you, foe), "")


func test_melee_adds_vigor() -> void:
	var you := person("你", P, Vector2i(0, 0), 5, 5, 8, ["knife", ""])
	var foe := person("敌", E, Vector2i(1, 0))
	var b := Battle.new([you, foe], 14, 14, dice([1, 100, 4]))
	eq(b.attack(you, foe).damage, 4 + 4)


func test_problems() -> void:
	var you := person("你", P, Vector2i(0, 0), 1)  # 5 点
	var foe := person("敌", E, Vector2i(16, 0))
	var b := Battle.new([you, foe], 20, 5, dice())
	has_text(b.attack_problem(you, foe), "太远")
	foe.pos = Vector2i(5, 0)
	you.loaded[0] = 0
	eq(b.attack_problem(you, foe), "没子弹了, 先换子弹")
	you.loaded[0] = 3
	you.ap = 3
	eq(b.attack_problem(you, foe), "行动点不够 (要 4 点)")
	eq(b.attack(you, foe), null)
	eq(b.attack_problem(you, you), "不能打这个人")


func test_kill_ends_battle() -> void:
	var you := person("你", P, Vector2i(0, 0))
	var foe := person("敌", E, Vector2i(2, 0))
	foe.hp = 1
	var b := Battle.new([you, foe], 14, 14, dice([1, 100, 12]))
	var r: Battle.AttackResult = b.attack(you, foe)
	check(r.killed)
	eq(b.result, "won")
	eq(foe.hp, 0)
	check(not b.move(you, Vector2i(1, 1)), "打完了就不能再动")


func test_player_dies() -> void:
	var you := person("你", P, Vector2i(0, 0))
	var foe := person("敌", E, Vector2i(2, 0))
	you.hp = 1
	var b := Battle.new([you, foe], 14, 14, dice([1, 100, 12]), foe)
	b.attack(foe, you)
	eq(b.result, "lost")


# ---------- 换子弹、换手 ----------

func test_reload() -> void:
	var you := person("你", P, Vector2i(0, 0), 5, 5, 5, ["pistol", ""], "none", {"pistol": 3})
	var foe := person("敌", E, Vector2i(5, 5))
	var b := Battle.new([you, foe], 14, 14, dice())
	eq(b.reload_problem(you), "子弹是满的")
	you.loaded[0] = 4
	check(b.reload(you))
	eq([you.ammo_in_hand(), you.spare["pistol"]], [7, 0])
	eq(you.ap, Rules.action_points(5) - 2)
	eq(b.reload_problem(you), "没有备用子弹了")


func test_switch_hand_is_free() -> void:
	var you := person("你", P, Vector2i(0, 0), 5, 5, 5, ["pistol", "knife"])
	var foe := person("敌", E, Vector2i(5, 5))
	var b := Battle.new([you, foe], 14, 14, dice())
	var ap := you.ap
	b.switch_hand(you)
	eq(you.weapon().name, "小刀")
	eq(you.ap, ap)
	eq(b.reload_problem(you), "小刀不用子弹")


func test_empty_hand_is_fist() -> void:
	var you := person("你", P, Vector2i(0, 0), 5, 5, 5, ["pistol", ""])
	var foe := person("敌", E, Vector2i(5, 5))
	var b := Battle.new([you, foe], 14, 14, dice())
	b.switch_hand(you)
	eq(you.weapon().name, "拳头")
