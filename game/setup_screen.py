"""
开打前的「准备」画面: 照《辐射》二代建角色那一页的感觉 (左边能力值加加减减, 中间算出来的数, 右边挑东西)。
- 救世主系统六项, 每项 1～10 分, 一开始每项 1 分, 再分 18 点
- 右手、左手拿什么 (8 种武器), 穿什么护甲 (3 种)
- 鼠标指着什么, 下面的绿屏幕就说明什么
"""

import pygame

from . import gear, practice, rules, ui

W, H = 1200, 720
TITLE = pygame.Rect(20, 14, W - 40, 50)
STATS_BOX = pygame.Rect(20, 78, 400, 532)
DERIVED_BOX = pygame.Rect(436, 78, 336, 300)
HELP_BOX = pygame.Rect(436, 390, 336, 220)
GEAR_BOX = pygame.Rect(788, 78, 392, 532)
RESET_BTN = pygame.Rect(20, 628, 170, 64)
START_BTN = pygame.Rect(W - 220, 624, 200, 76)
ROW_Y = [STATS_BOX.y + 70 + i * 66 for i in range(6)]

STAT_LETTERS = {"survival": "S", "agility": "A", "vigor": "V", "intellect": "I", "observation": "O", "resolve": "R"}
STAT_HELP = {
    "survival": "适应: 在废土上活下去的本事。抗毒、抗辐射、抗病、耐饥渴、伤好得快。练习场里还用不到。",
    "agility": "灵巧: 每回合的行动点数 (5 + 灵巧 ÷ 2), 用枪的命中 (每分 +5%), 近身的命中 (每分 +3%), 还有防御。",
    "vigor": "体魄: 生命值 (15 + 体魄 × 3), 近身的命中 (每分 +2%) 和伤害 (加 体魄 ÷ 2), "
             "手雷扔多远 (体魄 × 2 格)。大锤要体魄 6, 步枪要 4 (不够会怎样以后再定)。",
    "intellect": "学识: 医疗、科学、破解、修东西、聪明的对话选项。练习场里还用不到。",
    "observation": "洞察: 谁先动 (反应值), 远处打得准 (洞察几分, 就几格之内不扣命中), 暴击几率 (洞察 × 2)。",
    "resolve": "意志: 扛压力、说服人、能带几个同伴。练习场里还用不到。",
}
KIND_NAMES = {"unarmed": "空手", "melee": "近身武器", "gun": "枪", "throw": "投掷"}


def weapon_help(wid):
    w = gear.WEAPONS[wid]
    if wid == "fist":
        return "拳头: 手里不拿东西。伤害 1～3, 打一下 3 点, 只能打挨着的人, 伤害再加 体魄 ÷ 2。"
    words = f"{w.name}: {KIND_NAMES[w.kind]}, {'双手' if w.hands == 2 else '单手'}。伤害 {w.dmg_min}～{w.dmg_max}, 打一下 {w.ap} 点。"
    if w.kind == "melee":
        words += "只能打挨着的人, 伤害再加 体魄 ÷ 2。"
    elif w.kind == "gun":
        words += f"射程 {w.range} 格。弹夹 {w.magazine} 发, 备用子弹 {gear.SPARE_AMMO.get(wid, 0)} 发。"
    if w.accuracy:
        words += f"准头 {w.accuracy:+d}%。"
    if w.burst_ap:
        words += f"可以连发: 一次 {rules.BURST_ROUNDS} 发, 花 {w.burst_ap} 点, 每发分开算中不中, 不能瞄准。"
    if w.kind == "throw":
        words += (f"一次带 {gear.GRENADES} 个。扔多远看体魄 (体魄 × 2 格), 炸 3×3, "
                  "范围里的人都受伤, 包括你自己。扔偏了会落到旁边。")
    if w.vigor_req:
        words += f"要体魄 {w.vigor_req}。"
    return words


def armor_help(aid):
    a = gear.ARMORS[aid]
    if aid == "none":
        return "没穿护甲: 什么都不挡, 不过也不占地方。"
    return f"{a.name}: 防御 +{a.defense} (更难被打中), 先挡掉 {a.threshold} 点伤害, 剩下的再挡 {a.resist}%。"


class SetupScreen:
    """准备画面。click / key 返回 "start" 表示可以开打了"""

    def __init__(self, setup):
        self.setup = setup
        self.mouse = (0, 0)
        self.hint = None
        self.bg = self.make_bg()

    # ---------- 位置 ----------

    def stat_buttons(self):
        """{(能力值, -1 或 +1): 方块}"""
        rects = {}
        for stat, y in zip(practice.STAT_ORDER, ROW_Y):
            rects[(stat, -1)] = pygame.Rect(STATS_BOX.x + 294, y - 18, 40, 36)
            rects[(stat, 1)] = pygame.Rect(STATS_BOX.x + 342, y - 18, 40, 36)
        return rects

    def stat_rows(self):
        return {stat: pygame.Rect(STATS_BOX.x + 10, y - 30, STATS_BOX.width - 20, 60)
                for stat, y in zip(practice.STAT_ORDER, ROW_Y)}

    def gear_buttons(self):
        """{("hand", 0 或 1, 武器) 或 ("armor", 护甲): 方块}"""
        rects = {}
        for hand in (0, 1):
            top = GEAR_BOX.y + 52 + hand * 168
            for i, wid in enumerate(gear.CHOICES):
                rects[("hand", hand, wid)] = pygame.Rect(GEAR_BOX.x + 14 + (i % 4) * 92,
                                                         top + (i // 4) * 50, 86, 42)
        for i, aid in enumerate(gear.ARMORS):
            rects[("armor", aid)] = pygame.Rect(GEAR_BOX.x + 14 + i * 124, GEAR_BOX.y + 400, 116, 44)
        return rects

    # ---------- 鼠标键盘 ----------

    def click(self, pos):
        self.mouse = pos
        for (stat, delta), rect in self.stat_buttons().items():
            if rect.collidepoint(pos):
                if not self.setup.change(stat, delta):
                    name = rules.STAT_NAMES[stat]
                    if delta > 0 and self.setup.stats[stat] < practice.MAX_STAT:
                        self.hint = "点数分完了, 先减掉别的"
                    else:
                        self.hint = f"{name}最低 {practice.MIN_STAT} 分" if delta < 0 else f"{name}最高 {practice.MAX_STAT} 分"
                else:
                    self.hint = None
                return None
        for key, rect in self.gear_buttons().items():
            if rect.collidepoint(pos):
                if key[0] == "hand":
                    self.setup.hands[key[1]] = key[2]
                else:
                    self.setup.armor = key[1]
                return None
        if RESET_BTN.collidepoint(pos):
            self.setup.__init__()
            self.hint = None
            return None
        if START_BTN.collidepoint(pos):
            return self.start()
        return None

    def key(self, key):
        if key in (pygame.K_RETURN, pygame.K_KP_ENTER):
            return self.start()
        return None

    def start(self):
        if not self.setup.ready():
            self.hint = f"还有 {self.setup.points_left()} 点没分完"
            return None
        return "start"

    # ---------- 画 ----------

    def make_bg(self):
        bg = pygame.Surface((W, H))
        ui.metal(bg, bg.get_rect(), seed=4)
        ui.bevel(bg, bg.get_rect(), raised=True, width=3)
        for x in (8, W - 9):
            for y in (8, H - 9):
                ui.rivet(bg, (x, y))
        ui.crt(bg, TITLE)
        for box in (STATS_BOX, GEAR_BOX):
            ui.slot(bg, box)
        ui.crt(bg, DERIVED_BOX)
        ui.crt(bg, HELP_BOX)
        ui.bevel(bg, START_BTN.inflate(10, 10), raised=True, width=3)
        return bg

    def hovered_help(self):
        """鼠标指着的东西的说明"""
        for (stat, _), rect in self.stat_buttons().items():
            if rect.collidepoint(self.mouse):
                return STAT_HELP[stat]
        for stat, rect in self.stat_rows().items():
            if rect.collidepoint(self.mouse):
                return STAT_HELP[stat]
        for key, rect in self.gear_buttons().items():
            if rect.collidepoint(self.mouse):
                return weapon_help(key[2]) if key[0] == "hand" else armor_help(key[1])
        return "鼠标指着能力值、武器或者护甲, 这里会说明它管什么。"

    def draw(self, surf):
        s = self.setup
        surf.blit(self.bg, (0, 0))
        title = ui.text(22, "练习场 · 开打前的准备", ui.GREEN, glow=True)
        surf.blit(title, title.get_rect(midleft=(TITLE.x + 20, TITLE.centery)))
        right = self.hint or "每项先给 1 分, 再分 18 点; 分完了就能开打"
        note = ui.text(16, right, ui.AMBER if self.hint else ui.GREEN_DIM, glow=True)
        surf.blit(note, note.get_rect(midright=(TITLE.right - 20, TITLE.centery)))

        # 左边: 救世主系统
        surf.blit(ui.text(22, "救世主系统", ui.AMBER), (STATS_BOX.x + 18, STATS_BOX.y + 16))
        surf.blit(ui.text(14, "S.A.V.I.O.R.", (150, 140, 110)), (STATS_BOX.x + 140, STATS_BOX.y + 22))
        rows = self.stat_rows()
        for stat, y in zip(practice.STAT_ORDER, ROW_Y):
            if rows[stat].collidepoint(self.mouse):
                pygame.draw.rect(surf, (52, 48, 38), rows[stat])
            surf.blit(ui.text(14, STAT_LETTERS[stat], (150, 140, 110)), (STATS_BOX.x + 20, y - 9))
            surf.blit(ui.text(26, rules.STAT_NAMES[stat], ui.AMBER), (STATS_BOX.x + 46, y - 16))
            box = pygame.Rect(STATS_BOX.x + 200, y - 22, 80, 44)
            ui.slot(surf, box)
            surf.blit(*centered(ui.text(28, f"{s.stats[stat]:02d}", ui.AMBER), box.center))
        for (stat, delta), rect in self.stat_buttons().items():
            on = rect.collidepoint(self.mouse)
            pygame.draw.rect(surf, (120, 108, 84) if on else ui.METAL, rect)
            ui.bevel(surf, rect, raised=True, width=2)
            # 加号减号用线画 (有的字体没有减号, 会显示成方块)
            cx, cy = rect.center
            pygame.draw.line(surf, ui.AMBER, (cx - 8, cy), (cx + 8, cy), 3)
            if delta > 0:
                pygame.draw.line(surf, ui.AMBER, (cx, cy - 8), (cx, cy + 8), 3)
        left_box = pygame.Rect(STATS_BOX.x + 200, STATS_BOX.bottom - 62, 80, 44)
        surf.blit(ui.text(20, "还能分", ui.AMBER), (STATS_BOX.x + 46, left_box.y + 10))
        ui.slot(surf, left_box)
        left = s.points_left()
        surf.blit(*centered(ui.text(28, f"{left:02d}", (240, 90, 60) if left else ui.AMBER), left_box.center))

        # 中间: 算出来的数
        st = s.stats
        armor = gear.ARMORS[s.armor]
        derived = [
            ("生命", f"{rules.max_hp(st['vigor'])}"),
            ("行动点", f"{rules.action_points(st['agility'])}"),
            ("反应 (谁先动)", f"{rules.reaction(st['observation'])}"),
            ("用枪命中起点", f"{40 + st['agility'] * 5}%"),
            ("近身命中起点", f"{40 + st['agility'] * 3 + st['vigor'] * 2}%"),
            ("近身伤害", f"+{rules.melee_bonus(st['vigor'])}"),
            ("暴击几率", f"{rules.crit_chance(st['observation'])}%"),
            ("几格内不扣命中", f"{st['observation']} 格"),
            ("手雷扔多远", f"{rules.throw_range(st['vigor'])} 格"),
            ("防御", f"{rules.defense(st['agility'], armor.defense, 0)}"),
        ]
        y = DERIVED_BOX.y + 16
        for name, value in derived:
            surf.blit(ui.text(17, name, ui.GREEN, glow=True), (DERIVED_BOX.x + 20, y))
            v = ui.text(17, value, ui.GREEN, glow=True)
            surf.blit(v, v.get_rect(topright=(DERIVED_BOX.right - 20, y)))
            y += 27

        # 说明
        lines = ui.wrap(16, self.hovered_help(), HELP_BOX.width - 40, indent=False)
        y = HELP_BOX.y + 16
        for line in lines[:9]:
            surf.blit(ui.text(16, line, ui.GREEN, glow=True), (HELP_BOX.x + 20, y))
            y += 22

        # 右边: 右手、左手、护甲
        for hand, label in ((0, "右手"), (1, "左手")):
            surf.blit(ui.text(20, label, ui.AMBER), (GEAR_BOX.x + 16, GEAR_BOX.y + 18 + hand * 168))
        surf.blit(ui.text(20, "护甲", ui.AMBER), (GEAR_BOX.x + 16, GEAR_BOX.y + 366))
        for key, rect in self.gear_buttons().items():
            if key[0] == "hand":
                chosen = s.hands[key[1]] == key[2]
                label = gear.WEAPONS[key[2]].name if key[2] != "fist" else "空手"
            else:
                chosen = s.armor == key[1]
                label = gear.ARMORS[key[1]].name
            on = rect.collidepoint(self.mouse)
            pygame.draw.rect(surf, (64, 58, 44) if chosen else (120, 108, 84) if on else ui.METAL, rect)
            ui.bevel(surf, rect, raised=not chosen, width=2)
            if chosen:
                pygame.draw.rect(surf, ui.AMBER, rect, 2)
            surf.blit(*centered(ui.text(17, label, ui.AMBER if chosen else (230, 220, 190)), rect.center))
        need = [gear.WEAPONS[w] for w in s.hands if gear.WEAPONS[w].vigor_req > s.stats["vigor"]]
        if need:
            warn = f"体魄不够: {need[0].name}要 {need[0].vigor_req} (不够会怎样以后再定)"
            surf.blit(ui.text(14, warn, (240, 110, 70)), (GEAR_BOX.x + 16, GEAR_BOX.bottom - 32))

        # 下面: 恢复默认、开打
        on = RESET_BTN.collidepoint(self.mouse)
        pygame.draw.rect(surf, (120, 108, 84) if on else ui.METAL, RESET_BTN)
        ui.bevel(surf, RESET_BTN, raised=True, width=2)
        surf.blit(*centered(ui.text(20, "恢复默认", ui.AMBER), RESET_BTN.center))
        tip = ui.text(16, "回车 开打 · Esc 退出", (170, 160, 130))
        surf.blit(tip, tip.get_rect(center=(W // 2, RESET_BTN.centery)))
        ready = s.ready()
        on = START_BTN.collidepoint(self.mouse)
        ui.red_button(surf, (START_BTN.x + 40, START_BTN.centery), 24, hover=on and ready)
        surf.blit(ui.text(28, "开打", ui.AMBER if ready else (130, 120, 96)), (START_BTN.x + 84, START_BTN.centery - 18))


def centered(img, center):
    return img, img.get_rect(center=(int(center[0]), int(center[1])))
