"""
练习场的画面: 斜着看的方格地面、人、排队头像、战斗文字框、按钮、瞄准窗口。全部用代码画, 不用图片。
一打开先是「准备」画面 (setup_screen.py): 分能力值、挑武器和护甲, 再开打。
鼠标: 点空格子走过去, 点敌人打他, 右键点敌人 (或者先按「瞄准」) 选部位打, 点地上的武器捡起来,
      点武器格子换单发 / 连发 (冲锋枪)。
键盘: 空格 结束回合, R 换子弹, Q 换手, A 瞄准, F 单发 / 连发,
      打完按回车再来一局、按 S 重新准备, Esc 关掉瞄准窗口 / 退出。
"""

import math
from collections import Counter

import pygame

from . import ai, practice, rules, setup_screen, ui
from .gear import WEAPONS
from .combat import ENEMY, HAND_NAMES, PLAYER

W, H = 1200, 720          # 画面大小 (窗口拉大拉小时画面跟着缩放)
TILE_W, TILE_H = 64, 32   # 一格菱形的宽和高
TOP_BAR = 64              # 上面排队头像那一条的高度
PANEL_Y = 540             # 下面面板从这里开始
ORIGIN = (W // 2, 92)     # 格子 (0, 0) 菱形最上面那个角在画面上的位置

STEP_TIME = 0.11   # 走一格的动画几秒
AI_DELAY = 0.3     # 敌人每做一件事之间停几秒, 让玩家看清楚
HINT_TIME = 2.0    # 提示 (比如「行动点不够」) 显示几秒

# 颜色
BG = (24, 20, 16)
SAND = [(122, 104, 74), (128, 109, 78), (116, 99, 70), (125, 106, 72)]
TILE_LINE = (100, 85, 61)
TEXT = (226, 214, 186)
DIM = (140, 130, 110)
YELLOW = (240, 200, 80)
RED = (220, 80, 60)
GREEN = (110, 200, 110)
SIDE_COLORS = {PLAYER: (70, 120, 100), ENEMY: (150, 60, 45)}
# 战斗记录的颜色: 跟老式屏幕一样都是绿色系, 坏消息是橙红色
LOG_COLORS = {"info": (70, 150, 64), "player": (110, 230, 96), "enemy": (196, 214, 84),
              "good": (160, 255, 140), "bad": (240, 110, 70)}
LOG_LINE = 20

# 上面一条: 轮数、排队头像、操作说明
ROUND_BOX = pygame.Rect(12, 10, 96, 44)
PORTRAITS = pygame.Rect(116, 6, 300, 52)   # 排队头像放在一条凹下去的深色槽里
TIP_BOX = pygame.Rect(W - 400, 12, 388, 40)
# 下面面板里各块的位置
LOG_BOX = pygame.Rect(14, PANEL_Y + 12, 530, H - PANEL_Y - 24)
SWITCH_BTN = pygame.Rect(556, PANEL_Y + 12, 88, 50)
RELOAD_BTN = pygame.Rect(556, PANEL_Y + 67, 88, 50)
AIM_BTN = pygame.Rect(556, PANEL_Y + 122, 88, 50)
# 瞄准窗口
END_AGAIN = pygame.Rect(W // 2 - 230, H // 2 + 20, 210, 50)   # 打完以后的两个按钮
END_SETUP = pygame.Rect(W // 2 + 20, H // 2 + 20, 210, 50)
AIM_WIN = pygame.Rect(W // 2 - 330, 78, 660, 452)
AIM_FIGURE_TOP = AIM_WIN.y + 92
AIM_CANCEL = pygame.Rect(AIM_WIN.right - 22 - 176, AIM_WIN.bottom - 50, 176, 36)
# 瞄准窗口两边的部位按钮: 他的右手、右腿在你的左边 (他是面对着你的)
AIM_LEFT = ["head", "right_arm", "torso", "right_leg"]
AIM_RIGHT = ["eyes", "left_arm", "groin", "left_leg"]
AIM_ROWS = [AIM_FIGURE_TOP + 22, AIM_FIGURE_TOP + 104, AIM_FIGURE_TOP + 176, AIM_FIGURE_TOP + 246]
AP_STRIP = pygame.Rect(656, PANEL_Y + 12, 304, 30)
WEAPON_SLOT = pygame.Rect(656, PANEL_Y + 48, 304, 120)
HP_BOX = pygame.Rect(974, PANEL_Y + 30, 90, 42)
DEF_BOX = pygame.Rect(974, PANEL_Y + 118, 90, 42)
END_BOX = pygame.Rect(1078, PANEL_Y + 12, 110, 156)

# 人的样子 (按排队头像上的那个字找)
LOOKS = {
    "你": dict(shirt=(70, 120, 100), pants=(78, 64, 48), hair=(52, 38, 26), skin=(222, 182, 142), mohawk=False),
    "刀": dict(shirt=(140, 58, 42), pants=(60, 58, 60), hair=(30, 26, 24), skin=(200, 160, 120), mohawk=True),
    "枪": dict(shirt=(120, 82, 50), pants=(66, 60, 52), hair=(150, 60, 40), skin=(214, 172, 132), mohawk=True),
}
DEFAULT_LOOK = LOOKS["刀"]


# ---------- 斜着看的格子: 格子坐标 <-> 画面坐标 ----------

def tile_top(x, y):
    """格子 (x, y) 菱形最上面那个角在画面上的位置 (x, y 可以是小数, 走路动画用)"""
    return ORIGIN[0] + (x - y) * TILE_W / 2, ORIGIN[1] + (x + y) * TILE_H / 2


def tile_center(x, y):
    sx, sy = tile_top(x, y)
    return sx, sy + TILE_H / 2


def tile_diamond(x, y):
    sx, sy = tile_top(x, y)
    return [(sx, sy), (sx + TILE_W / 2, sy + TILE_H / 2), (sx, sy + TILE_H), (sx - TILE_W / 2, sy + TILE_H / 2)]


def screen_to_tile(mx, my):
    """画面上的一个点在哪个格子里"""
    u = (mx - ORIGIN[0]) / (TILE_W / 2)
    v = (my - ORIGIN[1]) / (TILE_H / 2)
    return math.floor((u + v) / 2), math.floor((v - u) / 2)


class Arena:
    """战斗练习场: 管一场战斗的画面、动画和鼠标键盘"""

    def __init__(self, rng=None, skip_setup=False):
        self.rng = rng
        self.running = True
        self.mouse = (0, 0)
        self.setup = practice.Setup()
        self.setup_screen = setup_screen.SetupScreen(self.setup)
        self.mode = "battle" if skip_setup else "setup"  # setup: 准备画面; battle: 打仗
        self.top_bg = make_top_bg()
        self.panel_bg = make_panel_bg()
        self.aim_bg = make_aim_bg()
        self.new_battle()

    def new_battle(self):
        self.battle = practice.make_battle(self.rng, self.setup)
        self.anims = []      # 排着队播的动画 (走路、攻击……), 播完一个再播下一个
        self.floats = []     # 飘在人头上的字 (「-6」「没打中」)
        self.facing = {u: (1 if u.side == PLAYER else -1) for u in self.battle.units}  # 1 朝右, -1 朝左
        self.ai_wait = 0.0
        self.hint = None     # (文字, 还剩几秒)
        self.buttons = {}
        self.aiming = False      # 按了「瞄准」: 下一次点敌人会弹出瞄准窗口
        self.aim_target = None   # 瞄准窗口开着的时候, 瞄的是谁
        self.hidden_items = []   # 刚掉下来、掉落动画还没播到的武器 (先不画)
        # 画面上看到的样子 (活着没有、躺着没有): 挨打的动画播完才改, 不然子弹还没飞到人就先倒了
        self.pending = Counter()  # 每个人还有几个跟他有关的动画没播完
        self.shown = {u: (u.alive, u.knocked_down or u.knocked_out) for u in self.battle.units}
        self.ground_bg = make_ground_bg(self.battle)
        self.hovered = None       # 这一帧鼠标指着的人 (每帧只算一次)

    # ---------- 状态 ----------

    @property
    def busy(self):
        """还在播动画 (或者刚发生的事还没排进动画)"""
        return bool(self.anims or self.battle.events)

    def players_turn(self):
        b = self.battle
        return not b.result and not self.busy and b.current.side == PLAYER

    def show_hint(self, text):
        self.hint = (text, HINT_TIME)

    # ---------- 鼠标键盘 ----------

    def handle(self, event):
        if event.type == pygame.QUIT:
            self.running = False
        elif self.mode == "setup":
            self.handle_setup(event)
        elif event.type == pygame.MOUSEMOTION:
            self.mouse = event.pos
        elif event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            self.mouse = event.pos
            self.click(event.pos)
        elif event.type == pygame.MOUSEBUTTONDOWN and event.button == 3:
            self.mouse = event.pos
            self.right_click(event.pos)
        elif event.type == pygame.KEYDOWN:
            self.key(event.key)

    def handle_setup(self, event):
        """准备画面的鼠标键盘"""
        go = None
        if event.type == pygame.MOUSEMOTION:
            self.setup_screen.mouse = event.pos
        elif event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            go = self.setup_screen.click(event.pos)
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                self.running = False
            else:
                go = self.setup_screen.key(event.key)
        if go == "start":
            self.new_battle()
            self.mode = "battle"

    def back_to_setup(self):
        self.mode = "setup"
        self.setup_screen.hint = None

    def key(self, key):
        if key == pygame.K_ESCAPE:
            if self.aim_target or self.aiming:  # 先关瞄准, 再按一次才退出
                self.aim_target = None
                self.aiming = False
            else:
                self.running = False
        elif self.battle.result:
            if key in (pygame.K_RETURN, pygame.K_KP_ENTER) and not self.busy:
                self.new_battle()
            elif key == pygame.K_s and not self.busy:
                self.back_to_setup()
        elif key == pygame.K_f:
            self.do_button("mode")
        elif key == pygame.K_SPACE:
            self.do_button("end")
        elif key == pygame.K_r:
            self.do_button("reload")
        elif key == pygame.K_q:
            self.do_button("switch")
        elif key == pygame.K_a:
            self.do_button("aim")

    def do_button(self, name):
        if not self.players_turn() or self.aim_target:
            return
        b = self.battle
        you = b.current
        if name == "aim":
            self.aiming = not self.aiming
            if self.aiming:
                self.show_hint("瞄准: 点一个敌人, 选打哪里")
            return
        self.aiming = False
        if name == "mode":
            if not you.weapon.burst_ap:
                self.show_hint(f"{you.weapon.name}不能连发")
            else:
                b.toggle_burst(you)
        elif name == "end":
            b.end_turn()
        elif name == "reload":
            problem = b.reload_problem(you)
            if problem:
                self.show_hint(problem)
            else:
                b.reload(you)
        elif name == "switch":
            b.switch_hand(you)

    def click(self, pos):
        if self.aim_target:
            self.click_aim_window(pos)
            return
        if self.battle.result:
            if not self.busy and END_AGAIN.collidepoint(pos):
                self.new_battle()
            elif not self.busy and END_SETUP.collidepoint(pos):
                self.back_to_setup()
            return
        if WEAPON_SLOT.collidepoint(pos):
            self.do_button("mode")
            return
        for name, rect in self.buttons.items():
            if rect.collidepoint(pos):
                self.do_button(name)
                return
        if not self.players_turn():
            return
        b = self.battle
        you = b.current
        target = self.unit_under(pos)
        if target is not None:
            if target.side != you.side:
                if self.aiming:
                    self.open_aim(target)
                    return
                problem = b.attack_problem(you, target)
                if problem:
                    self.show_hint(problem)
                else:
                    b.attack(you, target)
            return
        tile = screen_to_tile(*pos)
        if not b.in_bounds(tile) or pos[1] >= PANEL_Y:
            return
        item = b.item_at(tile)
        if item and item not in self.hidden_items:
            problem = b.pickup_problem(you, item)
            if problem is None:
                b.pickup(you, item)
                return
            if problem != "要走到旁边才能捡":
                self.show_hint(problem)
                return
        if tile == you.pos:
            return
        path = b.find_path(you, tile)
        if path is None:
            self.show_hint("走不过去")
        elif b.move_cost(you, path) > you.ap:
            self.show_hint(f"行动点不够 (要 {b.move_cost(you, path)} 点)")
        else:
            b.move(you, tile)

    def right_click(self, pos):
        """右键: 关掉瞄准窗口; 或者直接瞄准鼠标下面的敌人"""
        if self.aim_target or self.aiming:
            self.aim_target = None
            self.aiming = False
            return
        if not self.players_turn():
            return
        target = self.unit_under(pos)
        if target is not None and target.side != self.battle.current.side:
            self.open_aim(target)

    # ---------- 瞄准窗口 ----------

    def open_aim(self, target):
        self.aiming = False
        you = self.battle.current
        if you.bursting():
            self.show_hint("连发不能瞄准 (按 F 换成单发)")
            return
        if you.weapon.kind == "throw":
            self.show_hint("手雷不能瞄准")
            return
        self.aim_target = target

    def aim_buttons(self):
        """瞄准窗口里八个部位按钮的位置: {部位: 方块}"""
        rects = {}
        for column, x in ((AIM_LEFT, AIM_WIN.x + 22), (AIM_RIGHT, AIM_WIN.right - 22 - 176)):
            for part, y in zip(column, AIM_ROWS):
                rects[part] = pygame.Rect(x, y - 21, 176, 42)
        return rects

    def aim_part_under(self, pos):
        """鼠标指着的部位 (按钮或者画上的身体)"""
        for part, rect in self.aim_buttons().items():
            if rect.collidepoint(pos):
                return part
        parts = ui.figure_parts(AIM_WIN.centerx, AIM_FIGURE_TOP)
        for part in ("eyes", "head", "right_arm", "left_arm", "groin", "right_leg", "left_leg", "torso"):
            if parts[part].collidepoint(pos):
                return part
        return None

    def click_aim_window(self, pos):
        if AIM_CANCEL.collidepoint(pos) or not AIM_WIN.collidepoint(pos):
            self.aim_target = None
            return
        part = self.aim_part_under(pos)
        if part is None:
            return
        b = self.battle
        problem = b.attack_problem(b.current, self.aim_target, part)
        if problem:
            self.show_hint(problem)
            return
        b.attack(b.current, self.aim_target, part)
        self.aim_target = None

    # ---------- 每一帧更新 ----------

    def update(self, dt):
        dt = min(dt, 0.1)
        if self.mode == "setup":
            return
        for event in self.battle.take_events():
            a = self.make_anim(event)
            self.pending.update(a["affects"])
            self.anims.append(a)
        if self.anims:
            a = self.anims[0]
            if not a["started"]:
                a["started"] = True
                self.start_anim(a)
            a["t"] += dt
            if a["t"] >= a["dur"]:
                self.anims.pop(0)
                self.pending.subtract(a["affects"])
        for u in self.battle.units:  # 没有动画在等的人, 画面上就照现在的样子画
            if self.pending[u] <= 0:
                self.shown[u] = (u.alive, u.knocked_down or u.knocked_out)
        for f in self.floats:
            f["t"] += dt
        self.floats = [f for f in self.floats if f["t"] < f["delay"] + f["dur"]]
        if self.hint:
            text, left = self.hint
            self.hint = (text, left - dt) if left > dt else None

        # 轮到敌人: 等一下做一件事, 没事可做就结束回合
        b = self.battle
        if not b.result and not self.busy and b.current.side == ENEMY:
            self.ai_wait += dt
            if self.ai_wait >= AI_DELAY:
                self.ai_wait = 0.0
                if not ai.act(b, b.current):
                    b.end_turn()
        else:
            self.ai_wait = 0.0

    def make_anim(self, event):
        kind = event[0]
        a = {"kind": kind, "t": 0.0, "started": False, "affects": []}  # affects: 挨打的人 (动画播完才倒下)
        if kind == "move":
            a.update(unit=event[1], path=event[2], dur=STEP_TIME * (len(event[2]) - 1))
        elif kind == "attack":
            r = event[1]
            a.update(result=r, dur=0.65 if r.shots > 1 else 0.45, affects=[r.target] + [u for u, _, _ in r.strays])
        elif kind == "throw":
            a.update(result=event[1], dur=0.95, affects=[u for u, _, _ in event[1].victims])
        elif kind in ("drop", "pickup"):
            a.update(unit=event[1], item=event[2], dur=0.3)
            if kind == "drop":
                self.hidden_items.append(event[2])
        else:  # reload / switch / getup / stunned
            a.update(unit=event[1], dur={"reload": 0.35, "getup": 0.4, "stunned": 0.6}.get(kind, 0.0))
        return a

    def start_anim(self, a):
        """动画开始播的时候: 转身、飘字"""
        if a["kind"] == "move":
            first, last = a["path"][0], a["path"][-1]
            self.turn_to(a["unit"], tile_center(*first), tile_center(*last))
        elif a["kind"] == "attack":
            r = a["result"]
            self.turn_to(r.attacker, tile_center(*r.attacker.pos), tile_center(*r.target.pos))
            if r.shots > 1:  # 连发: 写打中他几发; 歪掉的子弹打中别人, 别人头上也飘字
                if r.hits == 0:
                    self.float_text(r.target, f"没打中 (0/{r.shots})", TEXT, delay=0.3)
                else:
                    color = YELLOW if r.crit else RED
                    self.float_text(r.target, f"-{r.damage} ({r.hits}/{r.shots} 发)", color, delay=0.3)
                for u, dealt, _ in r.strays:
                    self.float_text(u, f"-{dealt}", RED, delay=0.35)
            elif not r.hit:
                self.float_text(r.target, "没打中", TEXT)
            elif r.crit:
                self.float_text(r.target, f"暴击 -{r.damage}", YELLOW)
            elif r.damage == 0:
                self.float_text(r.target, "挡住了", DIM)
            else:
                self.float_text(r.target, f"-{r.damage}", RED)
            if r.effect_short:  # 暴击打中部位的效果, 比如「左腿瘸了」
                self.float_text(r.target, r.effect_short, (255, 140, 60), delay=0.5)
        elif a["kind"] == "throw":
            r = a["result"]
            self.turn_to(r.attacker, tile_center(*r.attacker.pos), tile_center(*r.landing))
            for u, dealt, _ in r.victims:
                self.float_text(u, f"-{dealt}", RED, delay=0.55)
        elif a["kind"] == "reload":
            self.float_text(a["unit"], "换子弹", DIM, delay=0)
        elif a["kind"] == "drop":
            if a["item"] in self.hidden_items:
                self.hidden_items.remove(a["item"])
        elif a["kind"] == "pickup":
            self.float_text(a["unit"], "捡起来", DIM, delay=0)
        elif a["kind"] == "getup":
            self.float_text(a["unit"], "爬起来", DIM, delay=0)
        elif a["kind"] == "stunned":
            self.float_text(a["unit"], "晕着……", (255, 140, 60), delay=0)

    def turn_to(self, unit, a, b):
        if b[0] > a[0] + 1:
            self.facing[unit] = 1
        elif b[0] < a[0] - 1:
            self.facing[unit] = -1

    def float_text(self, unit, text, color, delay=0.12):
        self.floats.append({"unit": unit, "text": text, "color": color, "t": 0.0, "delay": delay, "dur": 0.9})

    # ---------- 人在画面上的位置 ----------

    def unit_tile_pos(self, unit):
        """这个人现在画在哪 (格子坐标, 走路动画时是小数)"""
        if self.anims and self.anims[0]["kind"] == "move" and self.anims[0]["unit"] is unit:
            a = self.anims[0]
            path = a["path"]
            k = min(a["t"] / STEP_TIME, len(path) - 1)
            i = min(int(k), len(path) - 2)
            f = k - i
            (x0, y0), (x1, y1) = path[i], path[i + 1]
            return x0 + (x1 - x0) * f, y0 + (y1 - y0) * f
        # 还没轮到播的走路动画: 先画在出发的地方
        for a in self.anims:
            if a["kind"] == "move" and a["unit"] is unit:
                return a["path"][0]
        return unit.pos

    def unit_screen_pos(self, unit):
        """这个人脚底在画面上的位置"""
        cx, cy = tile_center(*self.unit_tile_pos(unit))
        if self.anims and self.anims[0]["kind"] == "attack":
            a = self.anims[0]
            r = a["result"]
            if r.attacker is unit and r.weapon.kind in rules.CLOSE_KINDS:
                # 近身打: 往对方那边扑一下
                tx, ty = tile_center(*r.target.pos)
                push = math.sin(min(a["t"] / 0.25, 1) * math.pi) * 10
                d = math.hypot(tx - cx, ty - cy) or 1
                cx += (tx - cx) / d * push
                cy += (ty - cy) / d * push
        return cx, cy

    def unit_under(self, pos):
        """鼠标下面的人 (只算活人; 前面的人挡住后面的)"""
        found = None
        best = None
        for u in self.battle.units:
            if not u.alive:
                continue
            cx, cy = self.unit_screen_pos(u)
            if pygame.Rect(cx - 13, cy - 50, 26, 54).collidepoint(pos):
                depth = sum(self.unit_tile_pos(u))
                if best is None or depth > best:
                    found, best = u, depth
        return found

    # ---------- 画 ----------

    def draw(self, surf):
        if self.mode == "setup":
            self.setup_screen.draw(surf)
            return
        self.hovered = self.unit_under(self.mouse)
        surf.blit(self.ground_bg, (0, 0))
        self.draw_planning(surf)
        for item in self.battle.ground:
            if item not in self.hidden_items:
                ui.ground_item(surf, *tile_center(*item.pos), item.weapon_id)
        self.draw_units(surf)
        self.draw_effects(surf)
        self.draw_top_bar(surf)
        self.draw_status(surf)
        self.draw_panel(surf)
        if self.aim_target:
            self.draw_aim_window(surf)
        else:
            self.draw_tooltip(surf)
        if self.hint:
            img = ui.text(20, self.hint[0], ui.AMBER)
            shadow = ui.text(20, self.hint[0], (0, 0, 0))
            rect = img.get_rect(center=(W // 2, PANEL_Y - 22))
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1), (2, 2)):
                surf.blit(shadow, rect.move(dx, dy))
            surf.blit(img, rect)
        if self.battle.result and not self.busy:
            self.draw_end(surf)

    def draw_planning(self, surf):
        """轮到你的时候: 能走到的格子发绿; 鼠标指着的格子画出要走的路"""
        if not self.players_turn() or self.aim_target:
            return
        b = self.battle
        you = b.current
        for tile in b.reachable(you):  # 半透明的绿菱形, 一格一格贴 (不用每帧新建整屏的透明图层)
            x, y = tile_top(*tile)
            surf.blit(TINT_GREEN, (x - TILE_W / 2, y))

        target = self.hovered
        if target is not None and target.side != you.side and you.weapon.kind == "throw":
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    tile = (target.pos[0] + dx, target.pos[1] + dy)
                    if b.in_bounds(tile):
                        x, y = tile_top(*tile)
                        surf.blit(TINT_ORANGE, (x - TILE_W / 2, y))
        if self.mouse[1] >= PANEL_Y or self.mouse[1] < TOP_BAR or target:
            return
        tile = screen_to_tile(*self.mouse)
        if not b.in_bounds(tile) or tile == you.pos:
            return
        path = b.find_path(you, tile)
        if path is None:
            return
        cost = b.move_cost(you, path)
        color = GREEN if cost <= you.ap else RED
        for step in path[:-1]:
            pygame.draw.circle(surf, color, tile_center(*step), 3)
        pygame.draw.polygon(surf, color, tile_diamond(*tile), 2)
        label = ui.text(16, f"{cost} 点", color)
        cx, cy = tile_center(*tile)
        surf.blit(label, label.get_rect(center=(cx, cy + 24)))

    def draw_units(self, surf):
        b = self.battle
        # 倒下的人先画 (垫在下面), 活人按远近画, 近的挡住远的
        units = sorted(b.units, key=lambda u: (self.shown[u][0], sum(self.unit_tile_pos(u))))
        hovered = self.hovered if self.players_turn() else None
        for u in units:
            alive, lying = self.shown[u]
            cx, cy = self.unit_screen_pos(u)
            if alive and u is b.current and not b.result:
                pygame.draw.ellipse(surf, YELLOW, (cx - 17, cy - 8, 34, 16), 2)
            if u is hovered and u.side != b.current.side:
                pygame.draw.ellipse(surf, RED, (cx - 17, cy - 8, 34, 16), 2)
            draw_person(surf, cx, cy, LOOKS.get(u.short, DEFAULT_LOOK), self.facing[u], u.weapon_id, alive,
                        lying=lying)

    def draw_effects(self, surf):
        a = self.anims[0] if self.anims else None
        # 开枪: 一道黄线; 连发是一串, 一发一发地闪
        if a and a["kind"] == "attack" and a["result"].weapon.kind not in rules.CLOSE_KINDS:
            r = a["result"]
            ax, ay = self.unit_screen_pos(r.attacker)
            tx, ty = self.unit_screen_pos(r.target)
            f = self.facing[r.attacker]
            start = (ax + f * 15, ay - 26)
            if r.paths:  # 连发: 每发子弹沿着自己那条线飞, 一发一发地闪
                for i, (end_tile, who) in enumerate(r.paths):
                    t0 = i * 0.08
                    if not t0 <= a["t"] < t0 + 0.06:
                        continue
                    if who is not None:
                        ex, ey = self.unit_screen_pos(who)
                        end = (ex, ey - 26)
                    else:
                        ex, ey = tile_center(*end_tile)
                        end = (ex, ey - 26)
                    pygame.draw.line(surf, YELLOW, start, end, 2)
                    pygame.draw.circle(surf, (255, 240, 160), start, 4)
            elif a["t"] < 0.12:
                end = (tx, ty - 26) if r.hit else (tx + 18, ty - 44)
                pygame.draw.line(surf, YELLOW, start, end, 2)
                pygame.draw.circle(surf, (255, 240, 160), start, 4)
        if a and a["kind"] == "throw":
            self.draw_throw(surf, a)
        for fl in self.floats:
            if fl["t"] < fl["delay"]:
                continue
            cx, cy = self.unit_screen_pos(fl["unit"])
            rise = (fl["t"] - fl["delay"]) * 26
            img = ui.text(20, fl["text"], fl["color"])
            shadow = ui.text(20, fl["text"], (0, 0, 0))
            rect = img.get_rect(center=(cx, cy - 62 - rise))
            surf.blit(shadow, rect.move(1, 1))
            surf.blit(img, rect)

    def draw_throw(self, surf, a):
        """手雷: 前半段画它飞过去 (一道弧线), 后半段画 3×3 炸开"""
        r = a["result"]
        ax, ay = self.unit_screen_pos(r.attacker)
        lx, ly = tile_center(*r.landing)
        if a["t"] < 0.5:
            f = a["t"] / 0.5
            x = ax + (lx - ax) * f
            y = (ay - 30) + (ly - (ay - 30)) * f - math.sin(f * math.pi) * 70
            pygame.draw.circle(surf, (60, 80, 40), (int(x), int(y)), 5)
            pygame.draw.circle(surf, (120, 150, 80), (int(x) - 1, int(y) - 1), 2)
            return
        e = min(1.0, (a["t"] - 0.5) / 0.45)
        # 只在落点周围一小块画 (不用整屏的透明图层)
        size = (TILE_W * 3 + 40, TILE_H * 3 + 180)
        layer = pygame.Surface(size, pygame.SRCALPHA)
        ox, oy = lx - size[0] / 2, ly - size[1] / 2 - 40  # 这块小图的左上角在画面上的位置
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                tile = (r.landing[0] + dx, r.landing[1] + dy)
                if self.battle.in_bounds(tile):
                    pts = [(px - ox, py - oy) for px, py in tile_diamond(*tile)]
                    pygame.draw.polygon(layer, (255, 150, 40, int(150 * (1 - e))), pts)
        center = (int(lx - ox), int(ly - 10 - oy))
        pygame.draw.circle(layer, (255, 220, 120, int(220 * (1 - e))), center, int(14 + 70 * e))
        pygame.draw.circle(layer, (255, 120, 30, int(200 * (1 - e))), center, int(8 + 40 * e))
        surf.blit(layer, (ox, oy))

    def draw_top_bar(self, surf):
        b = self.battle
        surf.blit(self.top_bg, (0, 0))
        surf.blit(*centered(ui.text(20, f"第 {b.round} 轮", ui.AMBER), ROUND_BOX.center))
        x = PORTRAITS.x + 34
        for u in b.order:
            if not u.alive:
                continue
            now = u is b.current and not b.result
            done = b.has_acted(u)
            color = SIDE_COLORS[u.side]
            if done:
                color = tuple(c // 2 for c in color)
            pygame.draw.circle(surf, color, (x, 23), 14)
            pygame.draw.circle(surf, YELLOW if now else ui.METAL_DARK, (x, 23), 14, 3 if now else 1)
            surf.blit(*centered(ui.text(16, u.short, TEXT if not done else DIM), (x, 23)))
            surf.blit(*centered(ui.text(12, u.name, ui.AMBER if now else DIM), (x, 48)))
            x += 72
        tip = ui.text(15, "点空地走过去 · 点敌人打他 · 空格 结束回合", ui.GREEN, glow=True)
        surf.blit(tip, tip.get_rect(center=TIP_BOX.center))

    def draw_panel(self, surf):
        b = self.battle
        surf.blit(self.panel_bg, (0, PANEL_Y))
        you = next(u for u in b.units if u.side == PLAYER)
        mine = b.current is you and not b.result
        enabled = self.players_turn()

        # 左边: 绿字屏幕上的战斗记录 (最新的在最下面, 太长的折行)
        inner = LOG_BOX.inflate(-28, -16)
        rows = []
        for words, kind in b.log[-12:]:
            for i, line in enumerate(ui.wrap(16, words, inner.width - 14)):
                rows.append((line, kind, i == 0))
        rows = rows[-(inner.height // LOG_LINE):]
        y = inner.bottom - len(rows) * LOG_LINE
        for line, kind, first in rows:
            color = LOG_COLORS.get(kind, ui.GREEN)
            if first:
                pygame.draw.circle(surf, color, (inner.x + 4, y + 10), 3)
            surf.blit(ui.text(16, line, color, glow=True), (inner.x + 12, y))
            y += LOG_LINE

        # 换手、换子弹、瞄准三个小按钮 (按了「瞄准」, 那个按钮是按下去的样子)
        self.buttons = {}
        for name, label, key, rect in (("switch", "换手", "Q", SWITCH_BTN), ("reload", "换子弹", "R", RELOAD_BTN),
                                       ("aim", "瞄准", "A / 右键", AIM_BTN)):
            self.buttons[name] = rect
            hover = enabled and rect.collidepoint(self.mouse)
            pressed = name == "aim" and self.aiming
            pygame.draw.rect(surf, (70, 64, 50) if pressed else (110, 100, 78) if hover else ui.METAL, rect)
            ui.bevel(surf, rect, raised=not pressed, width=2)
            color = YELLOW if pressed else ui.AMBER if enabled else DIM
            surf.blit(*centered(ui.text(17, label, color), (rect.centerx, rect.centery - 8)))
            surf.blit(*centered(ui.text(12, key, DIM), (rect.centerx, rect.centery + 13)))

        # 一排行动点小灯
        for i in range(10):
            ui.lamp(surf, (AP_STRIP.x + 18 + i * 29, AP_STRIP.centery), mine and i < you.ap)

        # 武器格子: 现在用的那只手
        w = you.weapon
        ui.weapon_picture(surf, WEAPON_SLOT.inflate(-40, -30).move(34, 6), you.weapon_id)
        if you.arms_crippled() == 2:
            hand_label, hand_color = "两只手都废了", (240, 110, 70)
        elif not you.hand_ok(you.active):
            hand_label, hand_color = f"{HAND_NAMES[you.active]}废了", (240, 110, 70)
        else:
            hand_label, hand_color = HAND_NAMES[you.active], DIM
        surf.blit(ui.text(15, hand_label, hand_color), (WEAPON_SLOT.x + 10, WEAPON_SLOT.y + 8))
        name = ui.text(20, w.name, ui.AMBER)
        surf.blit(name, name.get_rect(topright=(WEAPON_SLOT.right - 30, WEAPON_SLOT.y + 6)))
        surf.blit(ui.text(22, f"花 {b.attack_cost(you)} 点", ui.AMBER), (WEAPON_SLOT.x + 10, WEAPON_SLOT.bottom - 32))
        if w.burst_ap:  # 冲锋枪: 单发还是连发 (点这个格子或者按 F 换)
            on = you.bursting()
            mode = ui.text(16, f"连发 {rules.BURST_ROUNDS} 发" if on else "单发", YELLOW if on else ui.AMBER)
            surf.blit(mode, (WEAPON_SLOT.x + 10, WEAPON_SLOT.y + 47))
            surf.blit(ui.text(12, "点这里或按 F 换", DIM), (WEAPON_SLOT.x + 10, WEAPON_SLOT.y + 68))
        if w.kind == "throw":
            count = ui.text(16, f"还有 {you.ammo_in_hand} 个", ui.AMBER)
            surf.blit(count, count.get_rect(bottomright=(WEAPON_SLOT.right - 12, WEAPON_SLOT.bottom - 8)))
        if w.magazine:  # 右边一竖条: 枪里还有几发 (发数多的枪, 一格不到 3 像素就画成一整条)
            seg_h = (WEAPON_SLOT.height - 20) / w.magazine
            if seg_h >= 3:
                for i in range(w.magazine):
                    r = pygame.Rect(WEAPON_SLOT.right - 18, WEAPON_SLOT.bottom - 10 - (i + 1) * seg_h + 1, 9, seg_h - 2)
                    pygame.draw.rect(surf, ui.AMBER if i < you.ammo_in_hand else (60, 52, 30), r)
            else:
                full = pygame.Rect(WEAPON_SLOT.right - 18, WEAPON_SLOT.y + 10, 9, WEAPON_SLOT.height - 20)
                pygame.draw.rect(surf, (60, 52, 30), full)
                left = full.copy()
                left.height = int(full.height * you.ammo_in_hand / w.magazine)
                left.bottom = full.bottom
                pygame.draw.rect(surf, ui.AMBER, left)
            spare = ui.text(14, f"备用 {you.spare.get(you.weapon_id, 0)}", DIM)
            surf.blit(spare, spare.get_rect(bottomright=(WEAPON_SLOT.right - 30, WEAPON_SLOT.bottom - 8)))
        other = you.hands[1 - you.active]
        other_name = WEAPONS[other or "fist"].name
        hint = ui.text(13, f"另一只手: {other_name}", DIM)
        surf.blit(hint, (WEAPON_SLOT.x + 10, WEAPON_SLOT.y + 28))

        # 生命和防御的计数器
        hp_color = (240, 70, 50) if you.hp * 3 < you.max_hp else ui.AMBER
        for label, value, color, box in (("生命", f"{you.hp:03d}", hp_color, HP_BOX),
                                         ("防御", f"{you.defense():03d}", ui.AMBER, DEF_BOX)):
            surf.blit(*centered(ui.text(15, label, ui.AMBER), (box.centerx, box.y - 11)))
            surf.blit(*centered(ui.text(28, value, color), box.center))
        surf.blit(*centered(ui.text(13, f"最多 {you.max_hp}", DIM), (HP_BOX.centerx, HP_BOX.bottom + 9)))

        # 结束回合: 红色大圆按钮
        self.buttons["end"] = END_BOX
        hover = enabled and END_BOX.collidepoint(self.mouse)
        ui.red_button(surf, (END_BOX.centerx, END_BOX.y + 52), 26, hover=hover)
        surf.blit(*centered(ui.text(18, "结束回合", ui.AMBER if enabled else DIM), (END_BOX.centerx, END_BOX.y + 102)))
        surf.blit(*centered(ui.text(13, "空格", DIM), (END_BOX.centerx, END_BOX.y + 126)))
        if not mine and not b.result:
            surf.blit(*centered(ui.text(14, "等别人行动", ui.GREEN_DIM, glow=True), AP_STRIP.center))

    def draw_tooltip(self, surf):
        """鼠标指着敌人: 显示生命、命中几率、花几点, 打不了就说为什么"""
        if not self.players_turn():
            return
        b = self.battle
        you = b.current
        target = self.hovered
        if target is None:
            lines = self.item_tooltip()
        elif target.side == you.side:
            return
        else:
            lines = [(f"{target.name}  生命 {target.hp}/{target.max_hp}", ui.GREEN),
                     (f"{target.weapon.name} · {target.armor.name}", ui.GREEN_DIM)]
            if target.statuses():
                lines.append(("、".join(target.statuses()), (255, 140, 60)))
            problem = b.attack_problem(you, target)
            if self.aiming:
                lines.append(("点他, 选打哪里", ui.AMBER))
            elif problem:
                lines.append((problem, (240, 110, 70)))
            elif you.bursting():
                shots = min(rules.BURST_ROUNDS, you.ammo_in_hand)
                center, side_a, side_b = rules.burst_split(shots)
                lines.append((f"每发命中 {b.hit_chance(you, target)}% · 花 {b.attack_cost(you)} 点", ui.AMBER))
                lines.append((f"连发 {shots} 发: {center} 发对准他, {side_a + side_b} 发往两边散", ui.GREEN_DIM))
            elif you.weapon.kind == "throw":
                lines.append((f"命中 {b.hit_chance(you, target)}% · 花 {b.attack_cost(you)} 点 · 炸 3×3", ui.AMBER))
                if rules.distance(you.pos, target.pos) <= rules.BLAST_RADIUS:
                    lines.append(("小心: 你也在爆炸范围里!", (240, 110, 70)))
            else:
                lines.append((f"命中 {b.hit_chance(you, target)}% · 花 {b.attack_cost(you)} 点", ui.AMBER))
        if not lines:
            return
        imgs = [ui.text(16, t, c, glow=True) for t, c in lines]
        width = max(i.get_width() for i in imgs) + 24
        height = len(imgs) * 21 + 16
        mx, my = self.mouse
        box = pygame.Rect(mx + 18, my - height - 6, width, height)
        box.clamp_ip(pygame.Rect(0, TOP_BAR, W, PANEL_Y - TOP_BAR))
        ui.crt(surf, box)
        for i, img in enumerate(imgs):
            surf.blit(img, (box.x + 12, box.y + 8 + i * 21))

    def item_tooltip(self):
        """鼠标指着地上的武器: 是什么、能不能捡"""
        if self.mouse[1] >= PANEL_Y or self.mouse[1] < TOP_BAR:
            return None
        b = self.battle
        item = b.item_at(screen_to_tile(*self.mouse))
        if item is None or item in self.hidden_items:
            return None
        w = WEAPONS[item.weapon_id]
        lines = [(f"地上: {w.name}" + (f" ({item.loaded} 发)" if w.magazine else ""), ui.GREEN)]
        problem = b.pickup_problem(b.current, item)
        if problem == "要走到旁边才能捡":
            lines.append(("点这里走过去, 到旁边再点一下捡起来", ui.GREEN_DIM))
        elif problem:
            lines.append((problem, (240, 110, 70)))
        else:
            lines.append((f"点一下捡起来 · 花 {rules.PICKUP_AP} 点", ui.AMBER))
        return lines

    def draw_status(self, surf):
        """你身上的伤, 写在地图左上角"""
        you = next(u for u in self.battle.units if u.side == PLAYER)
        words = you.statuses()
        if not words or not you.alive:
            return
        img = ui.text(18, "你: " + "、".join(words), (255, 140, 60))
        shadow = ui.text(18, "你: " + "、".join(words), (0, 0, 0))
        surf.blit(shadow, (17, TOP_BAR + 13))
        surf.blit(img, (16, TOP_BAR + 12))

    def draw_aim_window(self, surf):
        """瞄准窗口: 中间画敌人, 两边八个部位, 写着每个部位的命中几率"""
        b = self.battle
        you = b.current
        target = self.aim_target
        surf.blit(self.aim_bg, AIM_WIN.topleft)
        cost = b.attack_cost(you, "torso")
        title = ui.text(20, f"瞄准: {target.name}", ui.GREEN, glow=True)
        surf.blit(title, title.get_rect(midleft=(AIM_WIN.x + 34, AIM_WIN.y + 38)))
        info = ui.text(16, f"{you.weapon.name} · 瞄准要花 {cost} 点 (还剩 {you.ap} 点)", ui.AMBER, glow=True)
        surf.blit(info, info.get_rect(midright=(AIM_WIN.right - 34, AIM_WIN.y + 38)))

        hover = self.aim_part_under(self.mouse)
        parts = ui.figure(surf, AIM_WIN.centerx, AIM_FIGURE_TOP, LOOKS.get(target.short, DEFAULT_LOOK),
                          crippled=target.crippled, blind=target.blind, highlight=hover)
        for part, rect in self.aim_buttons().items():
            problem = b.attack_problem(you, target, part)
            on = part == hover
            on_left = rect.centerx < AIM_WIN.centerx  # 按钮在左边, 线就连到这个部位的左边
            anchor = parts[part].midleft if on_left else parts[part].midright
            if part == "head":
                anchor = (parts[part].left + 2, parts[part].centery - 8)
            start = rect.midright if on_left else rect.midleft
            pygame.draw.line(surf, ui.AMBER if on else ui.GREEN_DIM, start, anchor, 2 if on else 1)
            pygame.draw.rect(surf, (40, 52, 30) if on else ui.SCREEN_BG, rect, border_radius=6)
            pygame.draw.rect(surf, ui.AMBER if on else ui.GREEN_DIM, rect, 2, border_radius=6)
            name = rules.PART_NAMES[part]
            surf.blit(ui.text(19, name, ui.GREEN, glow=True), (rect.x + 12, rect.y + 9))
            if problem:
                note = ui.text(14, short_reason(problem), (240, 110, 70))
            else:
                note = ui.text(20, f"{b.hit_chance(you, target, part)}%", ui.AMBER, glow=True)
            surf.blit(note, note.get_rect(midright=(rect.right - 12, rect.centery)))
        if hover:
            problem = b.attack_problem(you, target, hover)
            if problem:  # 打不了: 把原因写全
                img = ui.text(16, problem, (240, 110, 70), glow=True)
            else:
                bonus = rules.aim_crit_bonus(hover)
                text = f"暴击几率 {b.crit_chance(you, hover)}%" + (f" (瞄准这里多 {bonus}%)" if bonus else "")
                img = ui.text(16, text, ui.GREEN, glow=True)
            surf.blit(img, img.get_rect(midleft=(AIM_WIN.x + 34, AIM_CANCEL.centery)))
        on = AIM_CANCEL.collidepoint(self.mouse)
        pygame.draw.rect(surf, (110, 100, 78) if on else ui.METAL, AIM_CANCEL)
        ui.bevel(surf, AIM_CANCEL, raised=True, width=2)
        surf.blit(*centered(ui.text(17, "取消 (Esc / 右键)", ui.AMBER), AIM_CANCEL.center))

    def draw_end(self, surf):
        surf.blit(END_SHADE, (0, 0))
        won = self.battle.result == "won"
        big = ui.text(48, "你赢了!" if won else "你倒下了……", GREEN if won else RED)
        surf.blit(big, big.get_rect(center=(W // 2, H // 2 - 40)))
        for rect, label in ((END_AGAIN, "再来一局 (回车)"), (END_SETUP, "重新准备 (S)")):
            on = rect.collidepoint(self.mouse)
            pygame.draw.rect(surf, (120, 108, 84) if on else ui.METAL, rect)
            ui.bevel(surf, rect, raised=True, width=3)
            surf.blit(*centered(ui.text(19, label, ui.AMBER), rect.center))
        small = ui.text(15, "Esc 退出", DIM)
        surf.blit(small, small.get_rect(center=(W // 2, END_AGAIN.bottom + 26)))


def make_top_bg():
    """上面那一条的背景 (金属板、铆钉、凹下去的框), 只画一次"""
    bg = pygame.Surface((W, TOP_BAR))
    ui.metal(bg, bg.get_rect(), seed=2)
    ui.bevel(bg, bg.get_rect(), raised=True, width=2)
    ui.slot(bg, ROUND_BOX)
    ui.slot(bg, PORTRAITS)
    ui.crt(bg, TIP_BOX)
    return bg


def make_panel_bg():
    """下面面板的背景, 只画一次 (锈金属很费时间, 不能每帧都画)"""
    bg = pygame.Surface((W, H - PANEL_Y))
    up = (0, -PANEL_Y)  # 面板里的位置是按整个画面算的, 画在这张小图上要往上挪
    ui.metal(bg, bg.get_rect(), seed=1)
    ui.bevel(bg, bg.get_rect(), raised=True, width=3)
    ui.crt(bg, LOG_BOX.move(up))
    ui.slot(bg, AP_STRIP.move(up))
    ui.slot(bg, WEAPON_SLOT.move(up))
    for box in (HP_BOX, DEF_BOX):
        ui.slot(bg, box.move(up))
    end = END_BOX.move(up)
    ui.bevel(bg, end, raised=True, width=3)
    ui.rivets(bg, end, inset=9)
    for x in (6, W - 7):
        for y in (8, H - PANEL_Y - 9):
            ui.rivet(bg, (x, y))
    return bg


def make_ground_bg(battle):
    """地面 (每格的沙子、石子、裂缝) 每局只画一次, 每帧直接贴上去"""
    bg = pygame.Surface((W, H))
    bg.fill(BG)
    for y in range(battle.height):
        for x in range(battle.width):
            n = (x * 73856093) ^ (y * 19349663)
            pts = tile_diamond(x, y)
            pygame.draw.polygon(bg, SAND[n % len(SAND)], pts)
            pygame.draw.polygon(bg, TILE_LINE, pts, 1)
            # 地上的小石子和裂缝, 每格固定, 不会一闪一闪
            cx, cy = tile_center(x, y)
            if n % 5 == 0:
                pygame.draw.circle(bg, (96, 82, 60), (cx + (n % 17) - 8, cy + (n % 7) - 3), 2)
            if n % 11 == 3:
                pygame.draw.line(bg, (100, 86, 62), (cx - 10, cy + 2), (cx + 4, cy - 3), 1)
    return bg


def tint_diamond(color):
    """一格大小的半透明菱形 (标能走到的格子、手雷会炸到的格子)"""
    img = pygame.Surface((TILE_W, TILE_H), pygame.SRCALPHA)
    pygame.draw.polygon(img, color, [(TILE_W / 2, 0), (TILE_W, TILE_H / 2), (TILE_W / 2, TILE_H), (0, TILE_H / 2)])
    return img


TINT_GREEN = tint_diamond((120, 220, 120, 40))
END_SHADE = pygame.Surface((W, H), pygame.SRCALPHA)  # 打完以后盖在画面上的一层暗色 (只做一次)
END_SHADE.fill((0, 0, 0, 150))
TINT_ORANGE = tint_diamond((255, 110, 50, 70))


def short_reason(problem):
    """瞄准窗口的部位按钮放不下长句子, 换个短说法 (鼠标指着时下面会写全)"""
    for key, short in (("行动点不够", "点数不够"), ("太远", "太远了"), ("走到旁边", "要走过去"),
                       ("没子弹", "没子弹"), ("废了", "手废了"), ("两只手", "要两只手")):
        if key in problem:
            return short
    return problem[:5]


def make_aim_bg():
    """瞄准窗口的背景: 金属框、上面一条绿屏幕、中间放人的深色屏幕"""
    bg = pygame.Surface(AIM_WIN.size)
    ui.metal(bg, bg.get_rect(), seed=3)
    ui.bevel(bg, bg.get_rect(), raised=True, width=3)
    ui.rivets(bg, bg.get_rect(), inset=10)
    ui.crt(bg, pygame.Rect(22, 16, AIM_WIN.width - 44, 44))
    ui.crt(bg, pygame.Rect(AIM_WIN.width // 2 - 100, AIM_FIGURE_TOP - AIM_WIN.y - 26, 200, 334))
    return bg


def centered(img, center):
    """blit 用: 把字摆在 center 正中间"""
    return img, img.get_rect(center=(int(center[0]), int(center[1])))


def draw_person(surf, cx, cy, look, facing, weapon_id, alive=True, lying=False):
    """
    用方块和圆画一个小人, 脚底踩在 (cx, cy)。facing: 1 朝右, -1 朝左。
    死了的人画成躺着的, 身下一摊血; 被打倒、打晕的人 (lying) 也躺着, 没有血。
    """
    cx, cy = int(cx), int(cy)
    if not alive or lying:
        if not alive:
            pygame.draw.ellipse(surf, (96, 22, 16), (cx - 20, cy - 7, 40, 14))
        else:
            pygame.draw.ellipse(surf, (70, 58, 42), (cx - 20, cy - 6, 40, 12))
        pygame.draw.rect(surf, look["pants"], (cx - facing * 2 - 7, cy - 10, 16, 7))
        body_x = cx - facing * 14 - 9
        pygame.draw.rect(surf, look["shirt"], (body_x, cy - 12, 18, 10), border_radius=3)
        pygame.draw.circle(surf, look["skin"], (cx - facing * 26, cy - 8), 6)
        return

    pygame.draw.ellipse(surf, (70, 58, 42), (cx - 14, cy - 5, 28, 10))  # 影子
    dark_shirt = tuple(int(c * 0.75) for c in look["shirt"])
    # 腿和鞋
    for lx in (cx - 6, cx + 1):
        pygame.draw.rect(surf, look["pants"], (lx, cy - 16, 5, 14))
        pygame.draw.rect(surf, (40, 32, 26), (lx - (1 if facing < 0 else 0), cy - 3, 6, 3))
    # 后面那只胳膊
    pygame.draw.rect(surf, dark_shirt, (cx - facing * 9 - 2, cy - 30, 4, 13))
    # 身子
    pygame.draw.rect(surf, look["shirt"], (cx - 8, cy - 33, 16, 19), border_radius=3)
    # 头和头发
    pygame.draw.circle(surf, look["skin"], (cx, cy - 40), 7)
    if look["mohawk"]:
        pygame.draw.rect(surf, look["hair"], (cx - 2, cy - 51, 4, 9))
    else:
        pygame.draw.rect(surf, look["hair"], (cx - 7, cy - 48, 14, 5),
                         border_top_left_radius=5, border_top_right_radius=5)
    pygame.draw.rect(surf, (30, 24, 20), (cx + facing * 3 - 1, cy - 41, 2, 2))  # 眼睛
    # 前面那只胳膊往前伸, 手里拿着武器
    hand = (cx + facing * 10, cy - 25)
    pygame.draw.line(surf, dark_shirt, (cx + facing * 5, cy - 29), hand, 4)
    hx, hy = hand
    if weapon_id in ("pistol", "rifle", "smg"):
        length = {"pistol": 12, "smg": 16, "rifle": 22}[weapon_id]
        gun = pygame.Rect(0, 0, length, 4)
        gun.midleft = (hx - 6, hy) if facing > 0 else (hx - length + 6, hy)
        pygame.draw.rect(surf, (58, 58, 62), gun)
        pygame.draw.rect(surf, (40, 40, 44), (hx - 1, hy, 3, 5))
        if weapon_id == "smg":
            pygame.draw.rect(surf, (40, 40, 44), (hx + facing * 5 - 1, hy + 2, 3, 6))  # 弹夹
        if weapon_id == "rifle":
            pygame.draw.rect(surf, (96, 64, 40), (hx - facing * 9 - 3, hy - 1, 6, 5))  # 枪托
    elif weapon_id == "knife":
        pygame.draw.line(surf, (200, 200, 205), hand, (hx + facing * 9, hy - 6), 2)
    elif weapon_id == "pipe":
        pygame.draw.line(surf, (130, 130, 136), (hx - facing * 3, hy + 4), (hx + facing * 10, hy - 14), 3)
    elif weapon_id == "sledgehammer":
        pygame.draw.line(surf, (110, 76, 46), (hx - facing * 3, hy + 5), (hx + facing * 9, hy - 16), 3)
        pygame.draw.rect(surf, (90, 90, 96), (hx + facing * 9 - 6, hy - 22, 12, 8))
    elif weapon_id == "grenade":
        pygame.draw.circle(surf, (60, 84, 44), (hx + facing * 3, hy - 2), 4)
    pygame.draw.circle(surf, look["skin"], hand, 2)
