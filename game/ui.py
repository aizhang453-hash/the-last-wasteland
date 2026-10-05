"""
界面的样子: 照《辐射》二代的感觉 (用户 2026-10-05 要求), 全部用代码画, 不用原版的图。
- 生锈的金属面板, 边上有铆钉, 有凸起和凹下去的边
- 绿色字的老式屏幕 (有一条条的扫描线)
- 一排小灯 (行动点)、红色的圆按钮、数字计数器
"""

import random

import pygame

from . import fonts

METAL = (92, 84, 66)
METAL_LIGHT = (140, 128, 100)
METAL_DARK = (44, 40, 32)
RUST = (110, 70, 40)
SCREEN_BG = (14, 22, 12)
GREEN = (96, 224, 88)
GREEN_DIM = (48, 120, 44)
AMBER = (232, 196, 80)
LAMP_RED = (200, 40, 30)


def metal(surf, rect, seed=0):
    """一块生锈的金属板: 底色上撒斑点、锈迹和划痕 (每块用固定的随机数, 画出来每次都一样)"""
    rect = pygame.Rect(rect)
    rng = random.Random(seed)
    pygame.draw.rect(surf, METAL, rect)
    for _ in range(rect.width * rect.height // 40):
        x = rng.randrange(rect.left, rect.right)
        y = rng.randrange(rect.top, rect.bottom)
        shade = rng.randint(-18, 14)
        color = tuple(max(0, min(255, c + shade)) for c in METAL)
        surf.fill(color, (x, y, rng.randint(1, 3), rng.randint(1, 2)))
    for _ in range(rect.width * rect.height // 2500 + 1):  # 一块块锈
        x = rng.randrange(rect.left, rect.right)
        y = rng.randrange(rect.top, rect.bottom)
        for _ in range(30):
            dx, dy = rng.randint(-14, 14), rng.randint(-6, 6)
            if rect.collidepoint(x + dx, y + dy):
                surf.fill(RUST if rng.random() < 0.6 else (90, 60, 36), (x + dx, y + dy, 2, 2))
    for _ in range(rect.width // 60 + 1):  # 划痕
        x = rng.randrange(rect.left, rect.right - 20)
        y = rng.randrange(rect.top, rect.bottom)
        pygame.draw.line(surf, METAL_LIGHT if rng.random() < 0.5 else METAL_DARK,
                         (x, y), (x + rng.randint(8, 30), y + rng.randint(-3, 3)), 1)


def bevel(surf, rect, raised=True, width=3):
    """凸起 (raised) 或凹下去的边: 上左亮、下右暗, 凹下去就反过来"""
    rect = pygame.Rect(rect)
    light, dark = (METAL_LIGHT, METAL_DARK) if raised else (METAL_DARK, METAL_LIGHT)
    for i in range(width):
        r = rect.inflate(-2 * i, -2 * i)
        pygame.draw.line(surf, light, r.topleft, (r.right - 1, r.top))
        pygame.draw.line(surf, light, r.topleft, (r.left, r.bottom - 1))
        pygame.draw.line(surf, dark, (r.left, r.bottom - 1), (r.right - 1, r.bottom - 1))
        pygame.draw.line(surf, dark, (r.right - 1, r.top), (r.right - 1, r.bottom - 1))


def rivet(surf, pos):
    x, y = pos
    pygame.draw.circle(surf, METAL_DARK, (x + 1, y + 1), 4)
    pygame.draw.circle(surf, (120, 110, 88), (x, y), 4)
    pygame.draw.circle(surf, (170, 160, 130), (x - 1, y - 1), 1)


def rivets(surf, rect, inset=8):
    rect = pygame.Rect(rect)
    for pos in ((rect.left + inset, rect.top + inset), (rect.right - inset - 1, rect.top + inset),
                (rect.left + inset, rect.bottom - inset - 1), (rect.right - inset - 1, rect.bottom - inset - 1)):
        rivet(surf, pos)


def crt(surf, rect):
    """老式绿字屏幕: 深色底, 一条条扫描线, 凹下去的边框"""
    rect = pygame.Rect(rect)
    pygame.draw.rect(surf, SCREEN_BG, rect, border_radius=10)
    lines = pygame.Surface(rect.size, pygame.SRCALPHA)
    for y in range(0, rect.height, 3):
        pygame.draw.line(lines, (0, 0, 0, 60), (0, y), (rect.width, y))
    surf.blit(lines, rect.topleft)
    pygame.draw.rect(surf, METAL_DARK, rect, 3, border_radius=10)
    pygame.draw.rect(surf, (30, 44, 26), rect.inflate(-6, -6), 1, border_radius=8)


def slot(surf, rect):
    """凹下去的深色格子 (放武器、计数器)"""
    rect = pygame.Rect(rect)
    pygame.draw.rect(surf, (30, 28, 22), rect)
    bevel(surf, rect, raised=False, width=3)


def lamp(surf, center, on, color=GREEN, radius=6):
    """一盏小圆灯: 亮着的有一圈光"""
    x, y = center
    pygame.draw.circle(surf, METAL_DARK, (x, y), radius + 2)
    if on:
        glow = pygame.Surface((radius * 6, radius * 6), pygame.SRCALPHA)
        pygame.draw.circle(glow, (*color, 50), (radius * 3, radius * 3), radius * 2)
        surf.blit(glow, (x - radius * 3, y - radius * 3))
        pygame.draw.circle(surf, color, (x, y), radius)
        pygame.draw.circle(surf, tuple(min(255, c + 90) for c in color), (x - 2, y - 2), 2)
    else:
        pygame.draw.circle(surf, tuple(c // 4 for c in color), (x, y), radius)


def red_button(surf, center, radius, pressed=False, hover=False):
    """红色圆按钮 (像老机器上的按钮)"""
    x, y = center
    pygame.draw.circle(surf, METAL_DARK, (x + 2, y + 2), radius + 4)
    pygame.draw.circle(surf, (150, 140, 112), (x, y), radius + 4)
    pygame.draw.circle(surf, (70, 14, 10), (x, y), radius)
    face = (230, 60, 44) if hover else LAMP_RED
    pygame.draw.circle(surf, face, (x - 1, y - 1), radius - 3)
    if not pressed:
        pygame.draw.circle(surf, (255, 170, 150), (x - radius // 3, y - radius // 3), max(2, radius // 4))


_text_cache = {}


def text(size, words, color, glow=False):
    """画字 (常用的字会记住, 不用每帧重画)。glow: 绿屏幕上的字, 周围带一点光"""
    key = (size, words, color, glow)
    img = _text_cache.get(key)
    if img is None:
        font = fonts.get(size)
        base = font.render(words, True, color)
        if glow:
            halo_color = tuple(c // 3 for c in color)
            img = pygame.Surface((base.get_width() + 2, base.get_height() + 2), pygame.SRCALPHA)
            halo = font.render(words, True, halo_color)
            for dx, dy in ((0, 1), (2, 1), (1, 0), (1, 2)):
                img.blit(halo, (dx, dy))
            img.blit(base, (1, 1))
        else:
            img = base
        if len(_text_cache) > 600:
            _text_cache.clear()
        _text_cache[key] = img
    return img


NO_LINE_START = "，。、,.!?！？;；:：)）」』…"  # 这些标点不放在一行的开头


def wrap(size, words, width, indent=True):
    """一行太长就折成几行 (中文一个字一个字地折)。indent: 折下来的行前面空两格"""
    font = fonts.get(size)
    lead = "  " if indent else ""
    lines, line = [], ""
    for ch in words:
        if line and font.size(line + ch)[0] > width and ch not in NO_LINE_START:
            lines.append(line)
            line = lead + ch if ch != " " else lead
        else:
            line += ch
    if line.strip():
        lines.append(line)
    return lines


# ---------- 武器的样子 (放在武器格子里的大图) ----------

def weapon_picture(surf, rect, weapon_id):
    """在格子正中间画一把武器 (都用方块和多边形拼的)"""
    cx, cy = pygame.Rect(rect).center
    if weapon_id == "pistol":
        body = [(cx - 50, cy - 16), (cx + 46, cy - 16), (cx + 46, cy - 2), (cx - 10, cy - 2),
                (cx - 14, cy + 4), (cx - 50, cy + 4)]
        pygame.draw.polygon(surf, (70, 72, 78), body)
        pygame.draw.polygon(surf, (110, 112, 120), body, 2)
        grip = [(cx - 46, cy + 4), (cx - 18, cy + 4), (cx - 24, cy + 36), (cx - 50, cy + 36)]
        pygame.draw.polygon(surf, (88, 60, 40), grip)
        pygame.draw.polygon(surf, (60, 40, 26), grip, 2)
        pygame.draw.arc(surf, (90, 92, 98), (cx - 20, cy - 4, 20, 20), 3.3, 6.1, 3)  # 扳机护圈
        pygame.draw.line(surf, (150, 152, 160), (cx - 44, cy - 12), (cx + 40, cy - 12), 1)
    elif weapon_id == "knife":
        blade = [(cx - 10, cy - 8), (cx + 52, cy - 8), (cx + 64, cy - 2), (cx + 52, cy + 6), (cx - 10, cy + 6)]
        pygame.draw.polygon(surf, (190, 192, 198), blade)
        pygame.draw.line(surf, (235, 236, 240), (cx - 8, cy - 6), (cx + 54, cy - 6), 2)
        pygame.draw.rect(surf, (80, 80, 84), (cx - 16, cy - 14, 6, 26))  # 护手
        pygame.draw.rect(surf, (96, 64, 40), (cx - 56, cy - 7, 40, 14), border_radius=4)
        for i in range(4):
            pygame.draw.line(surf, (70, 46, 28), (cx - 50 + i * 9, cy - 6), (cx - 50 + i * 9, cy + 6), 2)
    elif weapon_id == "pipe":
        pygame.draw.line(surf, (120, 120, 126), (cx - 60, cy + 16), (cx + 60, cy - 16), 9)
        pygame.draw.line(surf, (170, 170, 176), (cx - 58, cy + 12), (cx + 58, cy - 19), 2)
        pygame.draw.circle(surf, (100, 100, 106), (cx + 60, cy - 16), 6)
    elif weapon_id == "sledgehammer":
        pygame.draw.line(surf, (110, 76, 46), (cx - 66, cy + 24), (cx + 40, cy - 10), 7)
        head = [(cx + 26, cy - 34), (cx + 62, cy - 22), (cx + 52, cy + 6), (cx + 16, cy - 6)]
        pygame.draw.polygon(surf, (96, 96, 102), head)
        pygame.draw.polygon(surf, (140, 140, 148), head, 2)
    elif weapon_id in ("rifle", "smg"):
        long = weapon_id == "rifle"
        left, right = (cx - 74, cx + 74) if long else (cx - 54, cx + 50)
        pygame.draw.rect(surf, (70, 72, 78), (left + 30, cy - 12, right - left - 30, 10))   # 枪身
        pygame.draw.line(surf, (150, 152, 160), (left + 32, cy - 10), (right - 2, cy - 10), 1)
        stock = [(left, cy - 10), (left + 32, cy - 12), (left + 32, cy + 2), (left + 4, cy + 14)]
        pygame.draw.polygon(surf, (96, 64, 40) if long else (60, 60, 66), stock)
        pygame.draw.rect(surf, (88, 60, 40), (left + 44, cy - 2, 10, 20))   # 握把
        if long:
            pygame.draw.rect(surf, (40, 40, 44), (cx - 6, cy - 22, 30, 7), border_radius=3)  # 瞄准镜
        else:
            pygame.draw.rect(surf, (40, 40, 44), (cx + 2, cy - 2, 9, 26))  # 长弹夹
    elif weapon_id == "grenade":
        pygame.draw.ellipse(surf, (66, 90, 48), (cx - 22, cy - 18, 44, 48))
        for i in range(3):
            pygame.draw.line(surf, (44, 62, 32), (cx - 20, cy - 4 + i * 12), (cx + 20, cy - 4 + i * 12), 2)
        pygame.draw.rect(surf, (120, 120, 126), (cx - 8, cy - 28, 16, 12))
        pygame.draw.circle(surf, (170, 170, 176), (cx + 14, cy - 26), 7, 2)  # 拉环
    else:  # 拳头 (两只手都废了用脚踢, 也画这个)
        skin, dark = (210, 168, 128), (150, 112, 80)
        pygame.draw.rect(surf, skin, (cx - 30, cy - 22, 60, 44), border_radius=12)
        for i in range(4):
            pygame.draw.line(surf, dark, (cx - 18 + i * 13, cy - 20), (cx - 18 + i * 13, cy - 4), 2)
        pygame.draw.rect(surf, skin, (cx - 40, cy - 6, 18, 24), border_radius=8)  # 大拇指
        pygame.draw.rect(surf, dark, (cx - 30, cy - 22, 60, 44), 2, border_radius=12)


def ground_item(surf, cx, cy, weapon_id):
    """地上的小武器 (周围一圈淡黄的光, 好让人看见)"""
    cx, cy = int(cx), int(cy)
    glow = pygame.Surface((40, 20), pygame.SRCALPHA)
    pygame.draw.ellipse(glow, (255, 220, 120, 70), glow.get_rect())
    surf.blit(glow, (cx - 20, cy - 10))
    if weapon_id == "knife":
        pygame.draw.line(surf, (210, 210, 216), (cx - 2, cy - 1), (cx + 10, cy - 4), 2)
        pygame.draw.line(surf, (110, 72, 44), (cx - 9, cy + 1), (cx - 2, cy - 1), 3)
    elif weapon_id == "pipe":
        pygame.draw.line(surf, (130, 130, 136), (cx - 11, cy + 3), (cx + 11, cy - 4), 3)
    elif weapon_id == "sledgehammer":
        pygame.draw.line(surf, (110, 76, 46), (cx - 12, cy + 3), (cx + 6, cy - 3), 3)
        pygame.draw.rect(surf, (96, 96, 102), (cx + 4, cy - 7, 7, 9))
    elif weapon_id == "grenade":
        pygame.draw.circle(surf, (66, 90, 48), (cx, cy - 1), 5)
        pygame.draw.rect(surf, (120, 120, 126), (cx - 2, cy - 8, 4, 3))
    elif weapon_id in ("pistol", "rifle", "smg"):
        length = 14 if weapon_id == "pistol" else 22
        pygame.draw.rect(surf, (52, 52, 58), (cx - length // 2, cy - 4, length, 4))
        pygame.draw.rect(surf, (88, 60, 40), (cx - length // 2, cy, 4, 5))
    else:
        pygame.draw.rect(surf, (90, 90, 96), (cx - 8, cy - 3, 16, 6))


# 瞄准窗口里的大个子 (正面朝着你, 所以他的右手在你的左边): 每个部位在画上的位置
def figure_parts(fx, fy):
    """fx: 人正中间的横坐标; fy: 头顶。返回 {部位: 方块}"""
    return {
        "eyes": pygame.Rect(fx - 18, fy + 26, 36, 16),
        "head": pygame.Rect(fx - 26, fy + 4, 52, 60),
        "torso": pygame.Rect(fx - 36, fy + 70, 72, 92),
        "right_arm": pygame.Rect(fx - 60, fy + 74, 22, 96),
        "left_arm": pygame.Rect(fx + 38, fy + 74, 22, 96),
        "groin": pygame.Rect(fx - 30, fy + 162, 60, 26),
        "right_leg": pygame.Rect(fx - 30, fy + 188, 27, 104),
        "left_leg": pygame.Rect(fx + 3, fy + 188, 27, 104),
    }


def figure(surf, fx, fy, look, crippled=(), blind=False, highlight=None):
    """画瞄准窗口里的大个子。瘸了、废了的地方画个红叉, 鼠标指着的部位描黄边"""
    parts = figure_parts(fx, fy)
    dark = tuple(int(c * 0.75) for c in look["shirt"])
    for key in ("right_leg", "left_leg"):
        pygame.draw.rect(surf, look["pants"], parts[key], border_radius=4)
        r = parts[key]
        pygame.draw.rect(surf, (40, 32, 26), (r.x - 2, r.bottom - 10, r.width + 4, 10), border_radius=3)
    pygame.draw.rect(surf, look["pants"], parts["groin"], border_radius=4)
    for key in ("right_arm", "left_arm"):
        pygame.draw.rect(surf, dark, parts[key], border_radius=8)
        r = parts[key]
        pygame.draw.circle(surf, look["skin"], (r.centerx, r.bottom - 4), 9)
    pygame.draw.rect(surf, look["shirt"], parts["torso"], border_radius=10)
    pygame.draw.line(surf, dark, (fx, fy + 76), (fx, fy + 156), 2)
    head = parts["head"]
    pygame.draw.ellipse(surf, look["skin"], head)
    if look["mohawk"]:
        pygame.draw.rect(surf, look["hair"], (fx - 6, fy - 12, 12, 28), border_radius=3)
    else:
        pygame.draw.rect(surf, look["hair"], (head.x, head.y - 2, head.width, 20),
                         border_top_left_radius=20, border_top_right_radius=20)
    eyes = parts["eyes"]
    for ex in (eyes.x + 8, eyes.right - 12):
        if blind:
            pygame.draw.line(surf, (200, 40, 30), (ex - 3, eyes.y + 4), (ex + 5, eyes.y + 12), 2)
            pygame.draw.line(surf, (200, 40, 30), (ex + 5, eyes.y + 4), (ex - 3, eyes.y + 12), 2)
        else:
            pygame.draw.rect(surf, (30, 24, 20), (ex, eyes.y + 6, 5, 5))
    for key in crippled:
        r = parts[key]
        pygame.draw.line(surf, (220, 40, 30), r.topleft, r.bottomright, 3)
        pygame.draw.line(surf, (220, 40, 30), r.topright, r.bottomleft, 3)
    if highlight:
        r = parts[highlight]
        if highlight == "head":
            pygame.draw.ellipse(surf, AMBER, r, 3)
        else:
            pygame.draw.rect(surf, AMBER, r.inflate(4, 4), 3, border_radius=6)
    return parts
