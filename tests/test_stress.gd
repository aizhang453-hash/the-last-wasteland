extends TestCase
## 压力槽 (2026-10-10 用户定的做法, 数字是 Claude 先定的): 冷静 / 紧张 / 慌乱、涨和降、完美一击、大失败、吓呆
## 测试里的人 (person) 意志都是 1: 涨的时候打 95 折, 每回合开头降 3 点

const P := Unit.PLAYER
const E := Unit.ENEMY

var you: Unit
var foe: Unit


func before_each() -> void:
	you = person("你", P, Vector2i(0, 0), 6, 5, 5, ["pistol", ""])
	foe = person("敌", E, Vector2i(3, 0))


func battle(rolls := [], first: Unit = null) -> Battle:
	return Battle.new([you, foe], 10, 10, TestCase.FixedDice.new(rolls), first)


# ---------- 公式 ----------

func test_zones() -> void:
	for pair in [[0, "calm"], [29, "calm"], [30, "tense"], [69, "tense"], [70, "panic"], [100, "panic"]]:
		eq(Rules.stress_zone(pair[0]), pair[1], "压力 %d" % pair[0])
	eq(Rules.stress_zone_name(50), "紧张")


func test_resolve_shrinks_gains() -> void:
	# 意志每 1 点少涨 5%, 四舍五入
	eq(Rules.stress_gain(20, 1), 19)
	eq(Rules.stress_gain(20, 5), 15)
	eq(Rules.stress_gain(20, 10), 10)
	eq(Rules.stress_gain(14, 1), 13)
	eq(Rules.stress_decay(1), 3)
	eq(Rules.stress_decay(10), 12)


func test_aim_penalty_with_stress() -> void:
	eq(Rules.aim_penalty("head", 10), 30, "冷静少扣 10")
	eq(Rules.aim_penalty("head", 40), 40, "紧张照常")
	eq(Rules.aim_penalty("head", 80), 50, "慌乱多扣 10")
	eq(Rules.aim_penalty("torso", 10), 0, "最少不扣")
	eq(Rules.aim_penalty("torso", 80), 10, "慌乱瞄准身上也难")
	eq(Rules.aim_penalty("", 80), 0, "没瞄准不扣")
	eq(Rules.stress_hit_bonus(80, "gun"), -10)
	eq(Rules.stress_hit_bonus(80, "throw"), -10)
	eq(Rules.stress_hit_bonus(80, "melee"), 0, "近身打不受手抖影响")
	eq(Rules.stress_hit_bonus(10, "gun"), 0)


# ---------- 开打、涨、降 ----------

func test_start_and_turn_decay() -> void:
	var b := battle()
	eq(foe.stress, Rules.STRESS_START)
	eq(you.stress, Rules.STRESS_START - 3, "你先动, 回合开头降 意志 + 2")
	b.end_turn()
	eq(foe.stress, Rules.STRESS_START - 3)


func test_practice_starts_fresh() -> void:
	var b := Practice.make_battle(Dice.new(1))
	eq(b.units[0].stress, Rules.STRESS_START - 5, "准备画面默认意志 3, 开头降 5")
	eq(b.units[1].stress, Rules.STRESS_START)
	eq(b.units[2].stress, Rules.STRESS_START)


func test_getting_hurt_raises_stress() -> void:
	var b := battle([1, 100, 7])
	b.attack(you, foe)
	eq(foe.hp, foe.max_hp - 7)
	eq(foe.stress, 10 + Rules.stress_gain(7 * Rules.STRESS_PER_HP, 1), "掉 7 点生命, 打 95 折")


func test_miss_or_armor_still_scares() -> void:
	var b := battle([100])
	b.attack(you, foe)
	eq(foe.stress, 10 + 3, "没打中也涨 3")
	foe.armor = Gear.Armor.new("thick", "厚甲", 0, 20, 0)  # 先挡 20 点: 手枪打不穿
	b.dice = TestCase.FixedDice.new([1, 100, 5])
	you.ap = 10
	var r: Battle.AttackResult = b.attack(you, foe)
	eq(r.damage, 0)
	eq(foe.stress, 10 + 3 + 3, "被护甲挡住也涨 3")


func test_crit_adds_more() -> void:
	var b := battle([1, 1, 5])
	b.attack(you, foe)
	eq(foe.hp, foe.max_hp - 10)
	eq(foe.stress, 10 + Rules.stress_gain(10 * Rules.STRESS_PER_HP + Rules.STRESS_CRIT, 1))


func test_high_resolve_takes_it_better() -> void:
	foe.stats["resolve"] = 10
	var b := battle([1, 100, 7])
	b.attack(you, foe)
	var gain := Rules.stress_gain(7 * Rules.STRESS_PER_HP, 10)
	eq(gain, roundi(7 * Rules.STRESS_PER_HP * 0.5))
	eq(foe.stress, 10 + gain, "意志 10 只涨一半")
	b.end_turn()
	eq(foe.stress, 10 + gain - 12, "意志 10 每回合降 12")


func test_zone_change_is_told() -> void:
	foe.stress = 25
	var b := battle([1, 100, 7])
	b.attack(you, foe)
	said(b, "敌紧张起来了。")
	var moods := b.take_events().filter(func(e: Dictionary) -> bool: return e["kind"] == "mood")
	eq(moods.size(), 1)
	eq(moods[0]["words"], "紧张起来了")


func test_downing_a_foe_relieves_and_scares_his_friends() -> void:
	var other := person("乙", E, Vector2i(8, 8))
	you.stress = 50
	foe.hp = 1
	var b := Battle.new([you, foe, other], 10, 10, TestCase.FixedDice.new([1, 100, 5]))
	eq(you.stress, 47)
	b.attack(you, foe)
	check(not foe.alive())
	eq(you.stress, 47 - Rules.STRESS_RELIEF, "打倒敌人松一口气")
	eq(other.stress, 10 + 14, "同伴被打倒涨 15, 打 95 折")


func test_blast_scares_people_nearby() -> void:
	you.hands = ["grenade", ""]
	you.loaded = [1, 0]
	var near := person("旁边", E, Vector2i(5, 0))  # 离落点 2 格: 没炸到, 吓一跳
	var b := Battle.new([you, foe, near], 10, 10, TestCase.FixedDice.new([1, 10]))
	var r: Battle.ThrowResult = b.attack(you, foe)
	eq(r.victims.size(), 1)
	eq(near.stress, 10 + 5)
	eq(foe.stress, 10 + Rules.stress_gain(Rules.STRESS_BLAST + 10 * Rules.STRESS_PER_HP, 1), "炸到的: 吓一跳 + 掉的生命")


# ---------- 冷静 ----------

func test_calm_aims_better() -> void:
	var b := battle()
	check(you.stress_zone() == "calm")
	var calm_head := b.hit_chance(you, foe, "head")
	var calm_crit := b.crit_chance(you)
	you.stress = 40
	eq(calm_head, b.hit_chance(you, foe, "head") + Rules.CALM_AIM_EASE)
	eq(calm_crit, b.crit_chance(you) + Rules.CALM_CRIT)
	eq(b.hit_chance(you, foe), b.hit_chance(you, foe), "不瞄准一样")


func test_perfect_strike_ignores_armor() -> void:
	foe.armor = Gear.ARMORS["metal"]
	var b := battle([1, 1, 5])
	var r: Battle.AttackResult = b.attack(you, foe, "torso")
	check(r.perfect, "冷静的时候瞄准部位打出暴击")
	eq(r.damage, 10, "暴击翻倍, 金属甲挡不住")
	said(b, "完美一击! 护甲挡不住, 10 点伤害!")


func test_no_perfect_strike_when_tense_or_not_aimed() -> void:
	foe.armor = Gear.ARMORS["metal"]
	you.stress = 40
	var b := battle([1, 1, 5])
	var r: Battle.AttackResult = b.attack(you, foe, "torso")
	check(r.crit and not r.perfect)
	eq(r.damage, 4, "(10 - 4) × 0.7")
	you.stress = 10
	you.ap = 10
	b.dice = TestCase.FixedDice.new([1, 1, 5])
	r = b.attack(you, foe)
	check(r.crit and not r.perfect, "没瞄准部位不算完美一击")


# ---------- 慌乱 ----------

func test_panic_effects() -> void:
	you.stress = 90
	var b := battle()
	check(you.panicking())
	eq(you.ap, Rules.action_points(6) + 1, "肾上腺素: 多 1 点")
	var gun := b.hit_chance(you, foe)
	var head := b.hit_chance(you, foe, "head")
	var crit := b.crit_chance(you)
	you.stress = 40
	eq(gun, b.hit_chance(you, foe) - 10, "手抖")
	eq(head, b.hit_chance(you, foe, "head") - 20, "瞄准再扣 10")
	eq(crit, b.crit_chance(you) - 5, "眼花")


func test_panic_hits_harder_up_close() -> void:
	you.hands = ["knife", ""]
	foe.pos = Vector2i(1, 0)
	you.stress = 90
	var b := battle([100, 1, 100, 4])  # 先掷大失败 (没出事), 再掷命中、暴击、伤害
	var r: Battle.AttackResult = b.attack(you, foe)
	eq(r.fumble, "")
	eq(r.damage, 4 + 2 + 2, "伤害 4 + 体魄 5 ÷ 2 + 慌乱 2")


func test_no_fumble_roll_unless_panicking() -> void:
	you.stress = 69
	var b := battle([1, 100, 5])
	var r: Battle.AttackResult = b.attack(you, foe)
	check(r.hit)
	eq(r.fumble, "")
	eq(r.damage, 5)


func test_fumble_jam_and_fix() -> void:
	you.stress = 90
	var b := battle([1, 1])
	var ap := you.ap
	var r: Battle.AttackResult = b.attack(you, foe)
	eq(r.fumble, "jam")
	eq(you.ap, ap - 4, "点数照花")
	eq(you.ammo_in_hand(), 8, "子弹没打出去")
	eq(foe.hp, foe.max_hp)
	check(you.jammed_now())
	check(you.statuses().has("枪卡住了"))
	has_text(b.attack_problem(you, foe), "卡住了")
	eq(b.reload_problem(you), "", "子弹满的、没备用子弹也能修")
	check(b.reload(you))
	check(not you.jammed_now())
	eq(you.ap, ap - 4 - Rules.RELOAD_AP)
	said(b, "修好了卡住的手枪")
	eq(b.attack_problem(you, foe), "行动点不够 (要 4 点)")


func test_fumble_drop() -> void:
	you.stress = 90
	var b := battle([1, 2])
	var r: Battle.AttackResult = b.attack(you, foe)
	eq(r.fumble, "drop")
	eq(you.hands, ["", ""])
	eq(b.ground.size(), 1)
	eq(b.ground[0].item.id, "pistol")
	eq(b.take_events().map(func(e): return e["kind"]), ["fumble", "drop"])
	said(b, "手枪脱手掉在地上")


func test_fumble_wild_hits_yourself() -> void:
	you.stress = 90
	var b := battle([1, 3, 1, 6])
	var r: Battle.AttackResult = b.attack(you, foe)
	eq(r.fumble, "wild")
	check(r.victim == you)
	eq(you.hp, you.max_hp - 6)
	eq(you.ammo_in_hand(), 7)
	eq(foe.hp, foe.max_hp)
	said(b, "打歪了, 打中了自己! 6 点伤害。")


func test_fumble_wild_can_hit_someone_beside() -> void:
	var friend := person("同伴", P, Vector2i(1, 1))
	you.stress = 90
	var b := Battle.new([you, foe, friend], 10, 10, TestCase.FixedDice.new([1, 3, 2, 6]))
	var r: Battle.AttackResult = b.attack(you, foe)
	check(r.victim == friend)
	eq(friend.hp, friend.max_hp - 6)
	eq(you.hp, you.max_hp)


func test_fumble_wild_can_kill_yourself() -> void:
	var other := person("乙", P, Vector2i(9, 9))
	foe.hands = ["pistol", ""]
	foe.stress = 90
	foe.hp = 1
	var b := Battle.new([you, foe, other], 10, 10, TestCase.FixedDice.new([1, 3, 1, 6]), foe)
	b.attack(foe, you)
	check(not foe.alive())
	eq(b.result, "won", "敌人把自己打倒了, 你赢了")


func test_burst_does_not_go_wild() -> void:
	you.hands = ["smg", ""]
	you.loaded = [20, 0]
	you.burst = [true, false]
	you.stress = 90
	var b := battle([1, 3])
	var r: Battle.AttackResult = b.attack(you, foe)
	eq(r.fumble, "drop", "连发只会卡住或脱手")


func test_fist_fumble_falls_down() -> void:
	you.hands = ["", ""]
	foe.pos = Vector2i(1, 0)
	you.stress = 90
	var b := battle([1, 1])
	var r: Battle.AttackResult = b.attack(you, foe)
	eq(r.fumble, "fall")
	check(you.knocked_down)
	said(b, "一拳打空, 摔倒在地上")


func test_grenade_fumbles() -> void:
	you.hands = ["grenade", ""]
	you.loaded = [3, 0]
	you.stress = 90
	var b := battle([1, 1])
	var r = b.attack(you, foe)
	eq(r.fumble, "drop")
	eq(you.hands, ["", ""])
	eq(b.ground[0].item.count, 3, "一整堆手雷掉在地上")
	# 扔歪了: 落在自己旁边 1～2 格, 照样炸
	you.hands = ["grenade", ""]
	you.loaded = [3, 0]
	you.ap = 10
	b.dice = TestCase.FixedDice.new([1, 2])
	var t: Battle.ThrowResult = b.attack(you, foe)
	eq(t.fumble, "wild")
	var d := Rules.distance(t.landing, you.pos)
	check(d >= 1 and d <= 2, "落在 %s" % t.landing)
	eq(you.loaded[0], 2)
	said(b, "手雷扔歪了")


# ---------- 吓呆 ----------

func test_frozen_at_100() -> void:
	foe.stress = 95
	var b := battle([1, 100, 5])
	b.attack(you, foe)
	eq(foe.stress, 100)
	check(foe.frozen)
	check(foe.statuses().has("吓呆了"))
	said(b, "敌吓呆了!")
	b.end_turn()
	eq(foe.ap, Rules.half(Rules.action_points(5) + 1), "慌乱多 1 点, 再减一半")
	eq(foe.stress, Rules.STRESS_AFTER_FREEZE)
	check(not foe.frozen)
	said(b, "敌吓呆了, 这回合只有 4 点。")


# ---------- 电脑 ----------

func test_ai_fixes_a_jam() -> void:
	var b := battle([], foe)
	foe.jammed = [true, false]
	check(AI.act(b, foe))
	check(not foe.jammed_now())
	said(b, "修好了卡住的手枪")
