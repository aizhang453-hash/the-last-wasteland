extends TestCase
## 第 2 步: 瞄准八个部位, 暴击打中部位的效果

const P := Unit.PLAYER
const E := Unit.ENEMY

var you: Unit
var foe: Unit


func before_each() -> void:
	you = person("你", P, Vector2i(0, 0), 6, 5, 5, ["pistol", "knife"])
	foe = person("敌", E, Vector2i(3, 0), 5, 5, 5, ["pistol", ""], "none", {"pistol": 8})


func battle(rolls := []) -> Battle:
	return Battle.new([you, foe], 10, 10, TestCase.FixedDice.new(rolls))


func test_aim_costs_one_more_and_is_harder() -> void:
	var b := battle([1, 100, 5])
	var plain := b.hit_chance(you, foe)
	eq(b.hit_chance(you, foe, "head"), plain - 40)
	eq(b.hit_chance(you, foe, "eyes"), maxi(5, plain - 60))
	eq(b.attack_cost(you, "head"), 5)
	var r: Battle.AttackResult = b.attack(you, foe, "left_leg")
	eq(r.part, "left_leg")
	eq(you.ap, 8 - 5)
	has_text(b.messages[-1][0], "敌的左腿")


func test_crit_bonus_from_aiming() -> void:
	var b := battle()
	eq(b.crit_chance(you), 10)
	eq(b.crit_chance(you, "left_leg"), 20)
	eq(b.crit_chance(you, "eyes"), 40)


func test_no_effect_without_crit() -> void:
	var b := battle([1, 100, 5])
	var r: Battle.AttackResult = b.attack(you, foe, "left_leg")
	check(r.hit)
	eq(r.effect, "")
	eq(foe.crippled, {})


func test_torso_crit_only_damage() -> void:
	var b := battle([1, 1, 5])
	var r: Battle.AttackResult = b.attack(you, foe, "torso")
	check(r.crit)
	eq(r.effect, "")


func test_legs() -> void:
	# 一条腿瘸了走一格 2 点, 两条都瘸 4 点
	var b := battle([1, 1, 5, 1, 1, 5])
	you.ap = 20  # 一回合打两下
	var r: Battle.AttackResult = b.attack(you, foe, "left_leg")
	eq(r.effect, "敌的左腿瘸了!")
	eq(foe.step_cost(), 2)
	b.attack(you, foe, "right_leg")
	eq(foe.step_cost(), 4)
	check(foe.statuses().has("右腿瘸了"))
	b.end_turn()
	check(b.current() == foe)
	var most := 0
	for v in b.reachable(foe).values():
		most = maxi(most, v)
	eq(most, floori(foe.ap / 4.0))
	check(b.move(foe, Vector2i(4, 1)))
	eq(foe.ap, Rules.action_points(5) - 4)


func test_same_leg_twice_says_nothing_new() -> void:
	var b := battle([1, 1, 5, 1, 1, 5])
	you.ap = 20
	b.attack(you, foe, "left_leg")
	var r: Battle.AttackResult = b.attack(you, foe, "left_leg")
	eq(r.effect, "")


func test_arm_drops_weapon_and_pickup() -> void:
	var b := battle([1, 1, 5])
	var r: Battle.AttackResult = b.attack(you, foe, "right_arm")
	has_text(r.effect, "手枪掉在地上")
	eq(foe.hands, ["", ""])
	eq(b.ground.size(), 1)
	var item: Battle.GroundItem = b.ground[0]
	eq(Rules.distance(item.pos, foe.pos), 1)
	eq(item.loaded, 8)
	eq(b.take_events().map(func(e): return e["kind"]), ["attack", "drop"])
	b.end_turn()
	# 右手废了: 用不了, 要换手 (换到左手是拳头)
	eq(b.attack_problem(foe, you), "右手废了, 先换手")
	b.switch_hand(foe)
	eq(foe.weapon().name, "拳头")
	# 捡起来 (站在旁边就行), 拿在好的左手上
	var ap := foe.ap
	eq(b.pickup_problem(foe, item), "")
	check(b.pickup(foe, item))
	eq(foe.ap, ap - 2)
	eq(foe.hands, ["", "pistol"])
	eq([foe.active, foe.ammo_in_hand()], [1, 8])
	eq(b.ground, [])


func test_pickup_problems() -> void:
	var b := battle([1, 1, 5])
	b.attack(you, foe, "right_arm")
	var item: Battle.GroundItem = b.ground[0]
	eq(b.pickup_problem(you, item), "要走到旁边才能捡")
	you.pos = item.pos + Vector2i(0, 1) if b.unit_at(item.pos + Vector2i(0, 1)) == null else item.pos + Vector2i(0, -1)
	eq(b.pickup_problem(you, item), "两只手都拿着东西")


func test_both_arms_means_kick() -> void:
	var b := battle([1, 1, 5, 1, 1, 5])
	you.ap = 20
	b.attack(you, foe, "right_arm")
	b.attack(you, foe, "left_arm")
	eq(foe.weapon().name, "脚")
	b.end_turn()
	foe.pos = Vector2i(1, 0)
	eq(b.attack_problem(foe, you), "")
	var item: Battle.GroundItem = b.ground[0]
	item.pos = Vector2i(1, 1)  # 就在脚边也捡不了
	eq(b.pickup_problem(foe, item), "两只手都废了, 捡不了")


func test_groin_knocks_down() -> void:
	# 下身: 倒在地上, 下一回合先花 3 点爬起来
	var b := battle([1, 1, 5])
	var r: Battle.AttackResult = b.attack(you, foe, "groin")
	eq(r.effect, "敌疼得倒在地上!")
	check(foe.statuses().has("倒在地上"))
	b.end_turn()
	eq(foe.ap, Rules.action_points(5) - 3)
	check(not foe.knocked_down)
	has_text(b.messages[-1][0], "爬了起来")


func test_head_knocks_out() -> void:
	# 头: 打晕, 下一回合不能动 (直接跳过)
	var b := battle([1, 1, 5])
	b.attack(you, foe, "head")
	check(foe.knocked_out)
	b.end_turn()
	check(b.current() == you, "敌人被跳过了, 又轮到你")
	eq(b.round_no, 2)
	check(not foe.knocked_out)
	check(b.messages.any(func(m): return String(m[0]).contains("晕着")))
	b.end_turn()
	check(b.current() == foe, "下一轮他就醒了")


func test_eyes_blind() -> void:
	var b := battle([1, 1, 5])
	var before := b.hit_chance(foe, you)
	b.attack(you, foe, "eyes")
	check(foe.blind)
	eq(b.hit_chance(foe, you), maxi(5, before - 30))


func test_two_handed_needs_both_arms() -> void:
	you.hands = ["sledgehammer", ""]
	you.crippled["left_arm"] = true
	foe.pos = Vector2i(1, 0)
	var b := battle()
	eq(b.attack_problem(you, foe), "大锤要两只手都好才能用")
