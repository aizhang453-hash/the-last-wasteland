"""
战斗公式的测试 (数字照看板「战斗系统」卡片上定的)。
运行方法: 在游戏文件夹 (the-last-wasteland) 里输入 python3 -m unittest
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from game import gear, rules
from game.gear import ARMORS, WEAPONS


def stats(agility=5, vigor=5, observation=5):
    return {"survival": 1, "agility": agility, "vigor": vigor,
            "intellect": 1, "observation": observation, "resolve": 1}


class TestFormulas(unittest.TestCase):
    def test_action_points(self):
        """行动点 = 5 + 灵巧 ÷ 2 (舍掉小数)"""
        self.assertEqual(rules.action_points(1), 5)
        self.assertEqual(rules.action_points(6), 8)
        self.assertEqual(rules.action_points(7), 8)
        self.assertEqual(rules.action_points(10), 10)

    def test_hp_and_melee_bonus(self):
        self.assertEqual(rules.max_hp(1), 18)
        self.assertEqual(rules.max_hp(10), 45)
        self.assertEqual(rules.melee_bonus(5), 2)
        self.assertEqual(rules.melee_bonus(10), 5)

    def test_defense(self):
        """防御 = 灵巧 + 护甲防御 + 没用完的点数 × 2"""
        self.assertEqual(rules.defense(4, 5, 1), 11)

    def test_distance_counts_diagonal_as_one(self):
        self.assertEqual(rules.distance((0, 0), (3, 3)), 3)
        self.assertEqual(rules.distance((0, 0), (3, 1)), 3)

    def test_hit_chance_example_from_board(self):
        """看板上的例子: 灵巧 6、洞察 5、用枪 1 级, 手枪打 7 格外防御 11 的强盗 → 56%"""
        chance = rules.hit_chance(stats(agility=6, observation=5), WEAPONS["pistol"], 11, 7, perk_bonus=5)
        self.assertEqual(chance, 56)

    def test_hit_chance_melee_uses_vigor_and_ignores_distance(self):
        """近身: 40 + 灵巧 × 3 + 体魄 × 2 + 准头"""
        chance = rules.hit_chance(stats(agility=6, vigor=5), WEAPONS["knife"], 10, 1)
        self.assertEqual(chance, 40 + 18 + 10 + 5 - 10)

    def test_no_distance_penalty_within_observation(self):
        s = stats(agility=5, observation=6)
        near = rules.hit_chance(s, WEAPONS["pistol"], 0, 6)
        far = rules.hit_chance(s, WEAPONS["pistol"], 0, 8)
        self.assertEqual(near, 65)
        self.assertEqual(far, 65 - 8)

    def test_hit_chance_limits(self):
        self.assertEqual(rules.hit_chance(stats(agility=10), WEAPONS["rifle"], 0, 1), 95)
        self.assertEqual(rules.hit_chance(stats(agility=1), WEAPONS["pistol"], 50, 15), 5)

    def test_crit_chance(self):
        self.assertEqual(rules.crit_chance(5), 10)
        self.assertEqual(rules.crit_chance(5, aim_bonus=20), 30)

    def test_damage_example_from_board(self):
        """看板上的例子: 9 点打皮甲, 先减 2 再打 8 折, 5.6 算 6 点"""
        self.assertEqual(rules.damage_after_armor(9, False, ARMORS["leather"]), 6)

    def test_crit_doubles_before_armor(self):
        self.assertEqual(rules.damage_after_armor(9, True, ARMORS["leather"]), 13)  # (18-2)*0.8=12.8

    def test_armor_can_stop_everything(self):
        self.assertEqual(rules.damage_after_armor(4, False, ARMORS["metal"]), 0)
        self.assertEqual(rules.damage_after_armor(3, False, ARMORS["none"]), 3)

    def test_rounds_half_up(self):
        armor = gear.Armor("测试甲", 0, 0, 50)
        self.assertEqual(rules.damage_after_armor(5, False, armor), 3)  # 2.5 算 3


class TestGearTable(unittest.TestCase):
    def test_numbers_match_board(self):
        """武器表跟看板上定的一样 (伤害、花几点、射程、准头、弹夹)"""
        expected = {
            "fist": (1, 3, 3, 1, 0, 0), "knife": (2, 6, 3, 1, 5, 0), "pipe": (3, 7, 4, 1, 0, 0),
            "sledgehammer": (6, 14, 4, 1, -10, 0), "pistol": (5, 12, 4, 15, 0, 8),
            "rifle": (8, 18, 5, 30, 10, 5), "smg": (4, 9, 4, 15, -5, 20),
        }
        for wid, numbers in expected.items():
            w = WEAPONS[wid]
            self.assertEqual((w.dmg_min, w.dmg_max, w.ap, w.range, w.accuracy, w.magazine), numbers, wid)
        self.assertEqual(WEAPONS["smg"].burst_ap, 6)
        self.assertEqual(WEAPONS["sledgehammer"].hands, 2)
        self.assertEqual([(a.defense, a.threshold, a.resist) for a in ARMORS.values()],
                         [(0, 0, 0), (5, 2, 20), (10, 4, 30)])


if __name__ == "__main__":
    unittest.main()
