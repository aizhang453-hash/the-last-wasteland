"""
画面的测试: 不开真窗口 (用 pygame 的「假屏幕」), 模拟鼠标键盘, 看会不会出错。
画得对不对还要真的看截图, 这里只管不出错、点了有反应。
运行方法: 在游戏文件夹 (the-last-wasteland) 里输入 python3 -m unittest
"""

import os
import random
import sys
import unittest

os.environ["SDL_VIDEODRIVER"] = "dummy"   # 假屏幕, 不弹出窗口
os.environ["SDL_AUDIODRIVER"] = "dummy"   # 不出声
os.environ["PYGAME_HIDE_SUPPORT_PROMPT"] = "1"
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pygame

from game import screen, setup_screen
from game.combat import PLAYER


def setUpModule():
    pygame.display.init()
    pygame.font.init()


def tearDownModule():
    pygame.quit()


class TestArena(unittest.TestCase):
    def setUp(self):
        self.window = pygame.display.set_mode((screen.W, screen.H))
        self.arena = screen.Arena(rng=random.Random(5), skip_setup=True)

    def run_frames(self, n=1, dt=1 / 30):
        for _ in range(n):
            self.arena.update(dt)
            self.arena.draw(self.window)

    def mouse(self, pos):
        self.arena.handle(pygame.event.Event(pygame.MOUSEMOTION, pos=pos, rel=(0, 0), buttons=(0, 0, 0)))

    def click(self, pos):
        self.arena.handle(pygame.event.Event(pygame.MOUSEBUTTONDOWN, pos=pos, button=1))

    def key(self, key):
        self.arena.handle(pygame.event.Event(pygame.KEYDOWN, key=key, mod=0, unicode=""))

    def wait_for_player(self, limit=2000):
        for _ in range(limit):
            if self.arena.players_turn() or self.arena.battle.result:
                return
            self.run_frames()
        self.fail("一直没轮到玩家")

    def test_tile_math_round_trip(self):
        for x, y in [(0, 0), (3, 10), (13, 13), (7, 2)]:
            cx, cy = screen.tile_center(x, y)
            self.assertEqual(screen.screen_to_tile(cx, cy), (x, y))

    def test_click_tile_walks_there(self):
        you = self.arena.battle.units[0]
        target = (5, 9)
        self.click(tuple(map(int, screen.tile_center(*target))))
        self.assertEqual(you.pos, target)
        self.assertTrue(self.arena.busy)  # 在播走路动画
        self.run_frames(30)
        self.assertFalse(self.arena.busy)

    def test_too_far_shows_hint(self):
        you = self.arena.battle.units[0]
        self.click(tuple(map(int, screen.tile_center(13, 0))))
        self.assertEqual(you.pos, (3, 10))
        self.assertIn("行动点不够", self.arena.hint[0])
        self.run_frames()

    def test_click_enemy_attacks_and_tooltip_draws(self):
        b = self.arena.battle
        gunner = b.units[2]
        x, y = self.arena.unit_screen_pos(gunner)
        pos = (int(x), int(y - 25))
        self.mouse(pos)
        self.run_frames()  # 画提示框
        self.assertIs(self.arena.unit_under(pos), gunner)
        self.click(pos)
        self.assertEqual(b.units[0].ammo_in_hand, 7)
        self.assertIn("命中", b.log[-1][0])
        self.run_frames(30)

    def test_keys_and_buttons(self):
        b = self.arena.battle
        you = b.units[0]
        self.key(pygame.K_q)
        self.assertEqual(you.weapon.name, "小刀")
        self.run_frames()
        self.click(self.arena.buttons["switch"].center)
        self.assertEqual(you.weapon.name, "手枪")
        self.run_frames()
        self.key(pygame.K_r)
        self.assertEqual(self.arena.hint[0], "子弹是满的")
        self.key(pygame.K_SPACE)
        self.assertIsNot(b.current, you)

    def test_whole_battles_with_screen(self):
        """玩家每回合都直接结束 (或者电脑替他打), 一直打到底, 再按回车重来"""
        from game import ai
        for game in range(3):
            b = self.arena.battle
            for _ in range(3000):
                if b.result:
                    break
                if self.arena.players_turn():
                    if game == 0 or not ai.act(b, b.current):
                        self.key(pygame.K_SPACE)
                self.run_frames(1, dt=1 / 10)
            self.assertIsNotNone(b.result)
            self.run_frames(40, dt=1 / 10)
            self.key(pygame.K_RETURN)
            self.assertIsNot(self.arena.battle, b)
            self.assertEqual(self.arena.battle.units[0].side, PLAYER)

    def right_click(self, pos):
        self.arena.handle(pygame.event.Event(pygame.MOUSEBUTTONDOWN, pos=pos, button=3))

    def enemy_pos(self, unit):
        x, y = self.arena.unit_screen_pos(unit)
        return (int(x), int(y - 25))

    def test_right_click_opens_aim_window_and_shoot_part(self):
        b = self.arena.battle
        you, gunner = b.units[0], b.units[2]
        self.right_click(self.enemy_pos(gunner))
        self.assertIs(self.arena.aim_target, gunner)
        rect = self.arena.aim_buttons()["left_leg"]
        self.mouse(rect.center)
        self.run_frames()  # 画瞄准窗口
        self.click(rect.center)
        self.assertIsNone(self.arena.aim_target)
        self.assertEqual(you.ap, 8 - 5)
        self.assertIn("持枪强盗的左腿", b.log[-1][0] if "倒下" not in b.log[-1][0] else b.log[-2][0])
        self.run_frames(40)

    def test_click_on_figure_part(self):
        b = self.arena.battle
        gunner = b.units[2]
        self.arena.open_aim(gunner)
        from game import ui
        head = ui.figure_parts(screen.AIM_WIN.centerx, screen.AIM_FIGURE_TOP)["torso"]
        self.assertEqual(self.arena.aim_part_under(head.center), "torso")
        self.click(head.center)
        self.assertTrue(any("持枪强盗的身上" in t for t, _ in b.log))

    def test_aim_mode_button_and_escape(self):
        b = self.arena.battle
        gunner = b.units[2]
        self.key(pygame.K_a)
        self.assertTrue(self.arena.aiming)
        self.click(self.enemy_pos(gunner))
        self.assertIs(self.arena.aim_target, gunner)
        self.assertEqual(b.units[0].ap, 8)  # 还没打
        self.key(pygame.K_ESCAPE)            # Esc 先关瞄准窗口, 不退出
        self.assertIsNone(self.arena.aim_target)
        self.assertTrue(self.arena.running)
        self.run_frames()
        self.click(self.arena.buttons["aim"].center)
        self.assertTrue(self.arena.aiming)
        self.right_click((5, 300))          # 右键取消瞄准
        self.assertFalse(self.arena.aiming)

    def test_pickup_by_clicking(self):
        b = self.arena.battle
        you, gunner = b.units[0], b.units[2]
        gunner.crippled.add("right_arm")
        item = b._drop(gunner, 0)
        b.take_events()
        item.pos = (4, 10)  # 放到你旁边
        you.hands[1] = None  # 左手空出来
        self.mouse(tuple(map(int, screen.tile_center(*item.pos))))
        self.run_frames()
        self.click(tuple(map(int, screen.tile_center(*item.pos))))
        self.assertEqual(you.hands, ["pistol", "pistol"])
        self.assertEqual(you.ap, 8 - 2)

    def test_draw_injuries(self):
        """受伤的样子都能画出来 (躺着、瞎了、瘸了、地上有武器)"""
        b = self.arena.battle
        you, knife, gunner = b.units
        knife.knocked_out = True
        gunner.crippled.update({"right_arm", "left_leg"})
        b._drop(gunner, 0)
        you.blind = True
        you.crippled.add("right_leg")
        self.run_frames(5)
        self.arena.open_aim(gunner)
        self.run_frames(2)

    def test_burst_mode_and_tracers(self):
        b = self.arena.battle
        you, gunner = b.units[0], b.units[2]
        you.hands[0] = "smg"
        you.loaded[0] = 20
        self.click(screen.WEAPON_SLOT.center)  # 点武器格子换连发
        self.assertTrue(you.burst)
        self.run_frames()
        self.right_click(self.enemy_pos(gunner))  # 连发不能瞄准
        self.assertIsNone(self.arena.aim_target)
        self.assertIn("连发不能瞄准", self.arena.hint[0])
        self.mouse(self.enemy_pos(gunner))
        self.run_frames()
        self.click(self.enemy_pos(gunner))
        self.assertEqual(you.ammo_in_hand, 15)
        self.assertEqual(you.ap, 8 - 6)
        self.run_frames(30)
        self.key(pygame.K_f)  # F 换回单发
        self.assertFalse(you.burst)

    def test_grenade_throw_animation(self):
        b = self.arena.battle
        you, gunner = b.units[0], b.units[2]
        you.hands[0] = "grenade"
        you.loaded[0] = 3
        you.pos = (8, 6)
        self.mouse(self.enemy_pos(gunner))
        self.run_frames()  # 画 3×3 的范围
        self.click(self.enemy_pos(gunner))
        self.assertEqual(you.ammo_in_hand, 2)
        self.assertTrue(any("扔出手雷" in t for t, _ in b.log))
        for _ in range(40):
            self.run_frames()

    def test_end_buttons(self):
        b = self.arena.battle
        for u in b.units[1:]:
            u.hp = 0
        b._check_end()
        self.run_frames(5)
        self.click(screen.END_SETUP.center)
        self.assertEqual(self.arena.mode, "setup")
        self.run_frames()

    def test_escape_quits(self):
        self.key(pygame.K_ESCAPE)
        self.assertFalse(self.arena.running)


class TestSetup(unittest.TestCase):
    """开打前的准备画面"""

    def setUp(self):
        self.window = pygame.display.set_mode((screen.W, screen.H))
        self.arena = screen.Arena(rng=random.Random(5))

    def click(self, pos):
        self.arena.handle(pygame.event.Event(pygame.MOUSEBUTTONDOWN, pos=pos, button=1))

    def draw(self):
        self.arena.update(1 / 30)
        self.arena.draw(self.window)

    def test_starts_in_setup_and_starts_battle(self):
        self.assertEqual(self.arena.mode, "setup")
        self.draw()
        self.click(setup_screen.START_BTN.center)
        self.assertEqual(self.arena.mode, "battle")
        self.draw()

    def test_points_and_limits(self):
        s = self.arena.setup
        ss = self.arena.setup_screen
        self.assertEqual(s.points_left(), 0)
        plus = ss.stat_buttons()[("agility", 1)]
        self.click(plus.center)
        self.assertEqual(s.stats["agility"], 6)  # 点数分完了, 加不上去
        self.assertIn("分完了", ss.hint)
        self.click(ss.stat_buttons()[("survival", -1)].center)
        self.assertEqual(s.points_left(), 1)
        self.arena.handle(pygame.event.Event(pygame.KEYDOWN, key=pygame.K_RETURN, mod=0, unicode=""))
        self.assertEqual(self.arena.mode, "setup")  # 还有 1 点没分, 不能开打
        self.assertIn("没分完", ss.hint)
        self.click(plus.center)
        self.assertEqual(s.stats["agility"], 7)
        for _ in range(3):
            self.click(ss.stat_buttons()[("intellect", -1)].center)
        self.assertEqual(s.stats["intellect"], 1)  # 最低 1 分
        self.draw()

    def test_choose_gear_and_play(self):
        ss = self.arena.setup_screen
        self.click(ss.gear_buttons()[("hand", 0, "smg")].center)
        self.click(ss.gear_buttons()[("hand", 1, "grenade")].center)
        self.click(ss.gear_buttons()[("armor", "metal")].center)
        self.draw()
        self.click(setup_screen.START_BTN.center)
        you = self.arena.battle.units[0]
        self.assertEqual(you.hands, ["smg", "grenade"])
        self.assertEqual(you.loaded, [20, 3])
        self.assertEqual(you.spare, {"smg": 60})
        self.assertEqual(you.armor.name, "金属甲")

    def test_help_texts(self):
        ss = self.arena.setup_screen
        for rect in list(ss.gear_buttons().values()) + list(ss.stat_rows().values()):
            ss.mouse = rect.center
            self.assertTrue(ss.hovered_help())
            self.draw()

    def test_reset(self):
        s = self.arena.setup
        self.click(self.arena.setup_screen.stat_buttons()[("vigor", -1)].center)
        self.click(self.arena.setup_screen.gear_buttons()[("hand", 0, "rifle")].center)
        self.click(setup_screen.RESET_BTN.center)
        self.assertEqual((s.stats["vigor"], s.hands), (5, ["pistol", "knife"]))

    def test_escape_quits_from_setup(self):
        self.arena.handle(pygame.event.Event(pygame.KEYDOWN, key=pygame.K_ESCAPE, mod=0, unicode=""))
        self.assertFalse(self.arena.running)


if __name__ == "__main__":
    unittest.main()
