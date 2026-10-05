"""
战斗的测试: 轮流、走路、攻击、换子弹, 还有让电脑自己打几百局, 每一步都检查数字对不对。
运行方法: 在游戏文件夹 (the-last-wasteland) 里输入 python3 -m unittest
"""

import os
import random
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from game import ai, practice, rules
from game.gear import GRENADES, WEAPONS
from game.combat import ENEMY, PLAYER, Battle, Unit


class FixedRng(random.Random):
    """掷骰子每次都掷出给定的数 (测试用)"""

    def __init__(self, *rolls):
        super().__init__(0)
        self.rolls = list(rolls)

    def randint(self, a, b):
        value = self.rolls.pop(0) if self.rolls else a
        return max(a, min(b, value))


def person(name, side, pos, agility=5, observation=5, vigor=5, hands=("pistol", None), armor="none", ammo=None):
    stats = practice.stats(1, agility, vigor, 1, observation, 1)
    return Unit(name, side, stats, list(hands), armor=armor, ammo=ammo, pos=pos)


class TestTurns(unittest.TestCase):
    def test_initiator_first_then_reaction_order(self):
        """先动手的先打第一下; 之后按反应值 (洞察) 排, 一样比灵巧, 还一样玩家先"""
        you = person("你", PLAYER, (0, 0), observation=3)
        fast = person("快", ENEMY, (5, 5), observation=7)
        tie = person("平", ENEMY, (6, 6), observation=3)
        b = Battle([you, fast, tie], rng=FixedRng())
        self.assertEqual([u.name for u in b.order], ["你", "快", "平"])
        for _ in range(3):
            b.end_turn()
        self.assertEqual(b.round, 2)
        self.assertEqual([u.name for u in b.order], ["快", "你", "平"])

    def test_tie_breaks_by_agility(self):
        you = person("你", PLAYER, (0, 0), observation=5, agility=4)
        quick = person("灵", ENEMY, (5, 5), observation=5, agility=6)
        b = Battle([you, quick], rng=FixedRng())
        b.end_turn()
        b.end_turn()
        self.assertEqual([u.name for u in b.order], ["灵", "你"])

    def test_leftover_points_become_defense_and_do_not_carry(self):
        you = person("你", PLAYER, (0, 0), agility=6)
        foe = person("敌", ENEMY, (9, 9))
        b = Battle([you, foe], rng=FixedRng())
        self.assertEqual(you.ap, 8)
        b.move(you, (1, 1))
        b.end_turn()
        self.assertEqual(you.leftover, 7)
        self.assertEqual(you.defense(), 6 + 7 * 2)
        b.end_turn()  # 又轮到你: 点数重新给满, 防御加成没了
        self.assertEqual(you.ap, 8)
        self.assertEqual(you.defense(), 6)

    def test_dead_are_skipped(self):
        you = person("你", PLAYER, (0, 0))
        a = person("甲", ENEMY, (5, 5))
        c = person("乙", ENEMY, (6, 6))
        b = Battle([you, a, c], rng=FixedRng())
        a.hp = 0
        b.end_turn()
        self.assertIs(b.current, c)


class TestMoving(unittest.TestCase):
    def setUp(self):
        self.you = person("你", PLAYER, (2, 2), agility=2)  # 6 点
        self.foe = person("敌", ENEMY, (4, 4))
        self.b = Battle([self.you, self.foe], width=10, height=10, rng=FixedRng())

    def test_diagonal_step_costs_one(self):
        self.assertTrue(self.b.move(self.you, (3, 3)))
        self.assertEqual(self.you.ap, 5)

    def test_cannot_walk_too_far_or_onto_people(self):
        self.assertFalse(self.b.move(self.you, (9, 2)))   # 要 7 点
        self.assertFalse(self.b.move(self.you, (4, 4)))   # 有人
        self.assertFalse(self.b.move(self.you, (10, 2)))  # 出了地图
        self.assertEqual((self.you.pos, self.you.ap), ((2, 2), 6))

    def test_walks_around_people(self):
        self.b.units.append(person("挡", PLAYER, (3, 2)))
        path = self.b.find_path(self.you, (4, 2))
        self.assertEqual(len(path), 2)
        self.assertNotIn((3, 2), path)

    def test_reachable(self):
        tiles = self.b.reachable(self.you)
        self.assertEqual(tiles[(8, 2)], 6)
        self.assertNotIn((9, 2), tiles)
        self.assertNotIn((4, 4), tiles)       # 有人站着
        self.assertNotIn((8, 8), tiles)       # 斜着直走要穿过敌人, 绕路要 7 步

    def test_move_event_has_full_path(self):
        self.b.move(self.you, (2, 5))
        events = self.b.take_events()
        self.assertEqual(events, [("move", self.you, [(2, 2), (2, 3), (2, 4), (2, 5)])])
        self.assertEqual(self.b.take_events(), [])


class TestAttacking(unittest.TestCase):
    def test_hit_uses_ap_ammo_and_armor(self):
        you = person("你", PLAYER, (0, 0), agility=6, observation=5)
        foe = person("敌", ENEMY, (3, 0), agility=4, armor="leather")
        # 掷骰子: 命中掷 1 (中), 暴击掷 100 (没暴击), 伤害掷 9
        b = Battle([you, foe], rng=FixedRng(1, 100, 9))
        r = b.attack(you, foe)
        self.assertTrue(r.hit)
        self.assertFalse(r.crit)
        self.assertEqual(r.damage, 6)
        self.assertEqual(foe.hp, foe.max_hp - 6)
        self.assertEqual(you.ap, 8 - 4)
        self.assertEqual(you.ammo_in_hand, 7)
        self.assertEqual(r.chance, 40 + 30 - (4 + 5))

    def test_miss_when_roll_too_high(self):
        you = person("你", PLAYER, (0, 0))
        foe = person("敌", ENEMY, (3, 0))
        b = Battle([you, foe], rng=FixedRng(96))
        r = b.attack(you, foe)
        self.assertFalse(r.hit)
        self.assertEqual(foe.hp, foe.max_hp)
        self.assertIn("没打中", b.log[-1][0])

    def test_crit_doubles(self):
        you = person("你", PLAYER, (0, 0), observation=5)
        foe = person("敌", ENEMY, (3, 0))
        b = Battle([you, foe], rng=FixedRng(1, 10, 7))  # 暴击几率 10%, 掷 10 算暴击
        r = b.attack(you, foe)
        self.assertTrue(r.crit)
        self.assertEqual(r.damage, 14)
        self.assertIn("暴击", b.log[-1][0])

    def test_melee_needs_to_be_next_to(self):
        you = person("你", PLAYER, (0, 0), hands=("knife", None))
        foe = person("敌", ENEMY, (2, 1))
        b = Battle([you, foe], rng=FixedRng())
        self.assertEqual(b.attack_problem(you, foe), "要走到旁边才能打")
        foe.pos = (1, 1)  # 斜着挨着也算
        self.assertIsNone(b.attack_problem(you, foe))

    def test_melee_adds_vigor(self):
        you = person("你", PLAYER, (0, 0), vigor=8, hands=("knife", None))
        foe = person("敌", ENEMY, (1, 0))
        b = Battle([you, foe], rng=FixedRng(1, 100, 4))
        self.assertEqual(b.attack(you, foe).damage, 4 + 4)

    def test_problems(self):
        you = person("你", PLAYER, (0, 0), agility=1)  # 5 点
        foe = person("敌", ENEMY, (16, 0))
        b = Battle([you, foe], width=20, height=5, rng=FixedRng())
        self.assertIn("太远", b.attack_problem(you, foe))
        foe.pos = (5, 0)
        you.loaded[0] = 0
        self.assertEqual(b.attack_problem(you, foe), "没子弹了, 先换子弹")
        you.loaded[0] = 3
        you.ap = 3
        self.assertEqual(b.attack_problem(you, foe), "行动点不够 (要 4 点)")
        self.assertIsNone(b.attack(you, foe))
        self.assertEqual(b.attack_problem(you, you), "不能打这个人")

    def test_kill_ends_battle(self):
        you = person("你", PLAYER, (0, 0))
        foe = person("敌", ENEMY, (2, 0))
        foe.hp = 1
        b = Battle([you, foe], rng=FixedRng(1, 100, 12))
        r = b.attack(you, foe)
        self.assertTrue(r.killed)
        self.assertEqual(b.result, "won")
        self.assertEqual(foe.hp, 0)
        self.assertFalse(b.move(you, (1, 1)))  # 打完了就不能再动

    def test_player_dies(self):
        you = person("你", PLAYER, (0, 0))
        foe = person("敌", ENEMY, (2, 0))
        you.hp = 1
        b = Battle([you, foe], rng=FixedRng(1, 100, 12), initiator=foe)
        b.attack(foe, you)
        self.assertEqual(b.result, "lost")


class TestReloadAndHands(unittest.TestCase):
    def test_reload(self):
        you = person("你", PLAYER, (0, 0), ammo={"pistol": 3})
        foe = person("敌", ENEMY, (5, 5))
        b = Battle([you, foe], rng=FixedRng())
        self.assertEqual(b.reload_problem(you), "子弹是满的")
        you.loaded[0] = 4
        self.assertTrue(b.reload(you))
        self.assertEqual((you.ammo_in_hand, you.spare["pistol"]), (7, 0))
        self.assertEqual(you.ap, rules.action_points(5) - 2)
        self.assertEqual(b.reload_problem(you), "没有备用子弹了")

    def test_switch_hand_is_free(self):
        you = person("你", PLAYER, (0, 0), hands=("pistol", "knife"))
        foe = person("敌", ENEMY, (5, 5))
        b = Battle([you, foe], rng=FixedRng())
        ap = you.ap
        b.switch_hand(you)
        self.assertEqual(you.weapon.name, "小刀")
        self.assertEqual(you.ap, ap)
        self.assertEqual(b.reload_problem(you), "小刀不用子弹")

    def test_empty_hand_is_fist(self):
        you = person("你", PLAYER, (0, 0), hands=("pistol", None))
        foe = person("敌", ENEMY, (5, 5))
        b = Battle([you, foe], rng=FixedRng())
        b.switch_hand(you)
        self.assertEqual(you.weapon.name, "拳头")


class TestAiming(unittest.TestCase):
    """第 2 步: 瞄准八个部位, 暴击打中部位的效果"""

    def setUp(self):
        self.you = person("你", PLAYER, (0, 0), agility=6, observation=5, hands=("pistol", "knife"))
        self.foe = person("敌", ENEMY, (3, 0), hands=("pistol", None), ammo={"pistol": 8})

    def battle(self, *rolls):
        return Battle([self.you, self.foe], width=10, height=10, rng=FixedRng(*rolls))

    def test_aim_costs_one_more_and_is_harder(self):
        b = self.battle(1, 100, 5)
        plain = b.hit_chance(self.you, self.foe)
        self.assertEqual(b.hit_chance(self.you, self.foe, "head"), plain - 40)
        self.assertEqual(b.hit_chance(self.you, self.foe, "eyes"), max(5, plain - 60))
        self.assertEqual(b.attack_cost(self.you, "head"), 5)
        r = b.attack(self.you, self.foe, "left_leg")
        self.assertEqual(r.part, "left_leg")
        self.assertEqual(self.you.ap, 8 - 5)
        self.assertIn("敌的左腿", b.log[-1][0])

    def test_crit_bonus_from_aiming(self):
        b = self.battle()
        self.assertEqual(b.crit_chance(self.you), 10)
        self.assertEqual(b.crit_chance(self.you, "left_leg"), 20)
        self.assertEqual(b.crit_chance(self.you, "eyes"), 40)

    def test_no_effect_without_crit(self):
        b = self.battle(1, 100, 5)
        r = b.attack(self.you, self.foe, "left_leg")
        self.assertTrue(r.hit)
        self.assertIsNone(r.effect)
        self.assertEqual(self.foe.crippled, set())

    def test_torso_crit_only_damage(self):
        b = self.battle(1, 1, 5)
        r = b.attack(self.you, self.foe, "torso")
        self.assertTrue(r.crit)
        self.assertIsNone(r.effect)

    def test_legs(self):
        """一条腿瘸了走一格 2 点, 两条都瘸 4 点"""
        b = self.battle(1, 1, 5, 1, 1, 5)
        self.you.ap = 20  # 一回合打两下
        r = b.attack(self.you, self.foe, "left_leg")
        self.assertEqual(r.effect, "敌的左腿瘸了!")
        self.assertEqual(self.foe.step_cost(), 2)
        b.attack(self.you, self.foe, "right_leg")
        self.assertEqual(self.foe.step_cost(), 4)
        self.assertIn("右腿瘸了", self.foe.statuses())
        b.end_turn()
        self.assertIs(b.current, self.foe)
        self.assertEqual(max(b.reachable(self.foe).values()), self.foe.ap // 4)
        self.assertTrue(b.move(self.foe, (4, 1)))
        self.assertEqual(self.foe.ap, rules.action_points(5) - 4)

    def test_same_leg_twice_says_nothing_new(self):
        b = self.battle(1, 1, 5, 1, 1, 5)
        self.you.ap = 20  # 一回合打两下
        b.attack(self.you, self.foe, "left_leg")
        r = b.attack(self.you, self.foe, "left_leg")
        self.assertIsNone(r.effect)

    def test_arm_drops_weapon_and_pickup(self):
        b = self.battle(1, 1, 5)
        r = b.attack(self.you, self.foe, "right_arm")
        self.assertIn("手枪掉在地上", r.effect)
        self.assertEqual(self.foe.hands, [None, None])
        self.assertEqual(len(b.ground), 1)
        item = b.ground[0]
        self.assertEqual(rules.distance(item.pos, self.foe.pos), 1)
        self.assertEqual(item.loaded, 8)
        self.assertEqual([e[0] for e in b.take_events()], ["attack", "drop"])
        b.end_turn()
        # 右手废了: 用不了, 要换手 (换到左手是拳头)
        self.assertEqual(b.attack_problem(self.foe, self.you), "右手废了, 先换手")
        b.switch_hand(self.foe)
        self.assertEqual(self.foe.weapon.name, "拳头")
        # 捡起来 (站在旁边就行), 拿在好的左手上
        ap = self.foe.ap
        self.assertIsNone(b.pickup_problem(self.foe, item))
        self.assertTrue(b.pickup(self.foe, item))
        self.assertEqual(self.foe.ap, ap - 2)
        self.assertEqual(self.foe.hands, [None, "pistol"])
        self.assertEqual((self.foe.active, self.foe.ammo_in_hand), (1, 8))
        self.assertEqual(b.ground, [])

    def test_pickup_problems(self):
        b = self.battle(1, 1, 5)
        b.attack(self.you, self.foe, "right_arm")
        item = b.ground[0]
        self.assertEqual(b.pickup_problem(self.you, item), "要走到旁边才能捡")
        self.you.pos = (item.pos[0] - 1, item.pos[1]) if item.pos[0] > 0 else (item.pos[0] + 1, item.pos[1])
        if b.unit_at(self.you.pos) is self.foe:
            self.you.pos = (item.pos[0], item.pos[1] + 1)
        self.assertEqual(b.pickup_problem(self.you, item), "两只手都拿着东西")

    def test_both_arms_means_kick(self):
        b = self.battle(1, 1, 5, 1, 1, 5)
        self.you.ap = 20  # 一回合打两下
        b.attack(self.you, self.foe, "right_arm")
        b.attack(self.you, self.foe, "left_arm")
        self.assertEqual(self.foe.weapon.name, "脚")
        b.end_turn()
        self.foe.pos = (1, 0)
        self.assertIsNone(b.attack_problem(self.foe, self.you))
        item = b.ground[0]
        item.pos = (1, 1)  # 就在脚边也捡不了
        self.assertEqual(b.pickup_problem(self.foe, item), "两只手都废了, 捡不了")

    def test_groin_knocks_down(self):
        """下身: 倒在地上, 下一回合先花 3 点爬起来"""
        b = self.battle(1, 1, 5)
        r = b.attack(self.you, self.foe, "groin")
        self.assertEqual(r.effect, "敌疼得倒在地上!")
        self.assertIn("倒在地上", self.foe.statuses())
        b.end_turn()
        self.assertEqual(self.foe.ap, rules.action_points(5) - 3)
        self.assertFalse(self.foe.knocked_down)
        self.assertIn("爬了起来", b.log[-1][0])

    def test_head_knocks_out(self):
        """头: 打晕, 下一回合不能动 (直接跳过)"""
        b = self.battle(1, 1, 5)
        b.attack(self.you, self.foe, "head")
        self.assertTrue(self.foe.knocked_out)
        b.end_turn()
        self.assertIs(b.current, self.you)  # 敌人被跳过了, 又轮到你
        self.assertEqual(b.round, 2)
        self.assertFalse(self.foe.knocked_out)
        self.assertTrue(any("晕着" in t for t, _ in b.log))
        b.end_turn()
        self.assertIs(b.current, self.foe)  # 下一轮他就醒了

    def test_eyes_blind(self):
        b = self.battle(1, 1, 5)
        before = b.hit_chance(self.foe, self.you)
        b.attack(self.you, self.foe, "eyes")
        self.assertTrue(self.foe.blind)
        self.assertEqual(b.hit_chance(self.foe, self.you), max(5, before - 30))

    def test_two_handed_needs_both_arms(self):
        self.you.hands = ["sledgehammer", None]
        self.you.crippled.add("left_arm")
        self.foe.pos = (1, 0)
        b = self.battle()
        self.assertEqual(b.attack_problem(self.you, self.foe), "大锤要两只手都好才能用")


class TestBurstAndGrenade(unittest.TestCase):
    """第 3 步: 冲锋枪连发、手雷"""

    def test_burst(self):
        you = person("你", PLAYER, (0, 0), agility=6, hands=("smg", None), ammo={"smg": 20})
        foe = person("敌", ENEMY, (3, 0))
        foe.hp = foe.max_hp = 200
        # 5 发: 中、不中、中 (暴击)、不中、中
        b = Battle([you, foe], rng=FixedRng(1, 100, 5, 99, 1, 1, 9, 99, 1, 100, 4))
        self.assertFalse(b.toggle_burst(foe))           # 还没轮到他
        self.assertTrue(b.toggle_burst(you))
        self.assertEqual(b.attack_cost(you), 6)
        self.assertEqual(b.attack_problem(you, foe, "head"), "连发不能瞄准")
        r = b.attack(you, foe)
        self.assertEqual((r.shots, r.hits, r.crit), (5, 3, True))
        self.assertEqual(r.damage, 5 + 18 + 4)
        self.assertEqual(you.ammo_in_hand, 15)
        self.assertEqual(you.ap, 8 - 6)
        self.assertIn("5 发中了 3 发, 有 1 发暴击", b.log[-1][0])

    def test_burst_with_few_bullets_and_stops_after_kill(self):
        you = person("你", PLAYER, (0, 0), hands=("smg", None))
        foe = person("敌", ENEMY, (3, 0))
        you.burst = True
        you.loaded[0] = 3
        foe.hp = 4
        b = Battle([you, foe], rng=FixedRng(1, 100, 9, 1, 100, 9))
        r = b.attack(you, foe)
        self.assertEqual(r.shots, 3)
        self.assertEqual(r.hits, 1)     # 第一发就打倒了, 剩下的打空
        self.assertTrue(r.killed)
        self.assertEqual(you.ammo_in_hand, 0)
        self.assertEqual(b.result, "won")

    def test_burst_only_for_smg(self):
        you = person("你", PLAYER, (0, 0), hands=("pistol", None))
        foe = person("敌", ENEMY, (3, 0))
        b = Battle([you, foe], rng=FixedRng())
        self.assertFalse(b.toggle_burst(you))
        you.burst = True  # 就算开着, 手枪也还是单发
        self.assertEqual(b.attack_cost(you), 4)

    def test_grenade_range_and_blast(self):
        you = person("你", PLAYER, (0, 0), vigor=3, hands=("grenade", "pistol"), ammo={"grenade": 2})
        a = person("甲", ENEMY, (5, 5))
        c = person("乙", ENEMY, (6, 6))
        far = person("远", ENEMY, (7, 9))
        b = Battle([you, a, c, far], width=12, height=12, rng=FixedRng(1, 10, 20))
        self.assertEqual(you.loaded, [2, 8])
        self.assertEqual(b.attack_range(you), 6)
        self.assertIn("太远了", b.attack_problem(you, far))
        self.assertEqual(b.attack_problem(you, a, "head"), "手雷不能瞄准")
        # 手雷不减防御
        self.assertEqual(b.hit_chance(you, a), 40 + 25 - 0)
        r = b.attack(you, a)
        self.assertTrue(r.hit)
        self.assertEqual(r.landing, (5, 5))
        self.assertEqual([(u.name, d) for u, d, _ in r.victims], [("甲", 10), ("乙", 20)])
        self.assertEqual(you.ammo_in_hand, 1)
        self.assertEqual(you.ap, 7 - 5)

    def test_last_grenade_empties_hand_and_miss_lands_nearby(self):
        you = person("你", PLAYER, (0, 0), vigor=5, hands=("grenade", None))
        foe = person("敌", ENEMY, (4, 4))
        b = Battle([you, foe], width=10, height=10, rng=FixedRng(100))
        r = b.attack(you, foe)
        self.assertFalse(r.hit)
        self.assertNotEqual(r.landing, (4, 4))
        self.assertLessEqual(rules.distance(r.landing, (4, 4)), 2)
        self.assertEqual(you.hands, [None, None])
        self.assertTrue(any("扔偏了" in t for t, _ in b.log))

    def test_grenade_can_hurt_yourself_and_both_dead_is_lost(self):
        you = person("你", PLAYER, (0, 0), hands=("grenade", None))
        foe = person("敌", ENEMY, (1, 0))
        you.hp = foe.hp = 1
        b = Battle([you, foe], rng=FixedRng(1, 10, 10))
        r = b.attack(you, foe)
        self.assertEqual({u.name for u, _, _ in r.victims}, {"你", "敌"})
        self.assertEqual(b.result, "lost")


class TestSetupRules(unittest.TestCase):
    def test_setup_points(self):
        s = practice.Setup()
        self.assertEqual(sum(s.stats.values()), 24)
        self.assertTrue(s.ready())
        self.assertFalse(s.change("agility", 1))
        self.assertTrue(s.change("resolve", -1))
        self.assertFalse(s.ready())
        self.assertTrue(s.change("agility", 1))
        for _ in range(5):
            s.change("intellect", -1)
        self.assertEqual(s.stats["intellect"], 1)

    def test_setup_makes_player(self):
        s = practice.Setup()
        s.hands = ["fist", "rifle"]
        s.armor = "none"
        you = s.make_player()
        self.assertEqual(you.hands, [None, "rifle"])
        self.assertEqual(you.spare, {"rifle": 15})
        self.assertEqual(you.weapon.name, "拳头")


def check(test, b):
    """每一步都检查: 数字没有出范围、人没有叠在一起"""
    seen = set()
    for u in b.units:
        test.assertTrue(0 <= u.hp <= u.max_hp, u)
        test.assertGreaterEqual(u.ap, 0, u)
        test.assertTrue(b.in_bounds(u.pos), u)
        for hand, wid in enumerate(u.hands):
            if wid and WEAPONS[wid].kind == "throw":  # 手雷: 手上至少有 1 个, 扔完了手就空了
                test.assertTrue(1 <= u.loaded[hand] <= GRENADES, u)
                continue
            magazine = WEAPONS[wid].magazine if wid else 0
            test.assertTrue(0 <= u.loaded[hand] <= magazine, u)
        for count in u.spare.values():
            test.assertGreaterEqual(count, 0, u)
        if u.alive:
            test.assertNotIn(u.pos, seen, "两个人站在同一格")
            seen.add(u.pos)
        test.assertTrue(u.crippled <= set(rules.PART_NAMES), u)
        for hand in (0, 1):
            if not u.hand_ok(hand):
                test.assertIsNone(u.hands[hand], "废了的手还拿着东西")
    for item in b.ground:
        test.assertTrue(b.in_bounds(item.pos))
        test.assertGreaterEqual(item.loaded, 0)
    if b.result is None:
        test.assertTrue(b.current.alive)
        test.assertFalse(b.current.knocked_out, "晕着的人不该轮到")


class TestSelfPlay(unittest.TestCase):
    def test_computer_plays_both_sides(self):
        """电脑替两边打 400 局: 每局都能打完, 数字一直对"""
        results = {"won": 0, "lost": 0}
        for seed in range(400):
            b = practice.make_battle(random.Random(seed))
            steps = 0
            while not b.result:
                steps += 1
                self.assertLess(steps, 3000, f"第 {seed} 局打不完")
                if not ai.act(b, b.current):
                    b.end_turn()
                check(self, b)
            self.assertLess(b.round, 40)
            results[b.result] += 1
        # 强盗调得比你弱, 电脑替你打也应该赢多输少 (2026-10-05 量的大约七成)
        self.assertGreater(results["won"], results["lost"])

    def test_every_loadout(self):
        """每种武器都让电脑替你打几十局: 能打完, 数字一直对"""
        for wid in WEAPONS:
            if wid == "kick":
                continue
            for burst in ((False, True) if WEAPONS[wid].burst_ap else (False,)):
                for seed in range(25):
                    setup = practice.Setup()
                    setup.hands = [wid, "knife"]
                    b = practice.make_battle(random.Random(seed), setup)
                    b.units[0].burst = burst
                    steps = 0
                    while not b.result:
                        steps += 1
                        self.assertLess(steps, 4000, f"{wid} 第 {seed} 局打不完")
                        if not ai.act(b, b.current):
                            b.end_turn()
                        check(self, b)

    def test_random_player(self):
        """玩家乱点 (乱走、乱打、乱换手、乱换子弹): 规则也不会出错"""
        for seed in range(150):
            rng = random.Random(seed)
            b = practice.make_battle(random.Random(seed + 1000))
            you = b.units[0]
            steps = 0
            while not b.result:
                steps += 1
                self.assertLess(steps, 5000, f"第 {seed} 局打不完")
                if b.current is you:
                    choice = rng.random()
                    if choice < 0.35:
                        b.move(you, (rng.randrange(-1, 15), rng.randrange(-1, 15)))
                    elif choice < 0.5:
                        b.attack(you, rng.choice(b.units))
                    elif choice < 0.65:
                        part = rng.choice(list(rules.PART_NAMES))
                        b.attack(you, rng.choice(b.units), part)
                        if b.ground and rng.random() < 0.5:
                            b.pickup(you, rng.choice(b.ground))
                    elif choice < 0.72:
                        b.switch_hand(you)
                    elif choice < 0.8:
                        b.reload(you)
                    else:
                        b.end_turn()
                elif not ai.act(b, b.current):
                    b.end_turn()
                check(self, b)
            b.take_events()


if __name__ == "__main__":
    unittest.main()
