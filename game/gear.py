"""
武器和护甲。数字是 2026-10-05 定的起点 (看板「战斗系统」卡片), 以后试玩再调。
"""

from dataclasses import dataclass


@dataclass(frozen=True)
class Weapon:
    name: str
    kind: str          # unarmed 空手 / melee 近身武器 / gun 枪 / throw 投掷
    hands: int         # 单手 1, 双手 2
    dmg_min: int       # 伤害范围
    dmg_max: int
    ap: int            # 打一下花几点
    range: int         # 射程 (格); 近身是 1, 只能打挨着的
    accuracy: int = 0  # 准头, 加到命中几率上
    magazine: int = 0  # 弹夹装几发; 0 是不用子弹
    burst_ap: int = 0  # 连发花几点; 0 是不能连发
    vigor_req: int = 0  # 要多少体魄 (不够会怎样, 以后再加)


@dataclass(frozen=True)
class Armor:
    name: str
    defense: int    # 加到防御上 (让人更难打中)
    threshold: int  # 先挡掉几点伤害
    resist: int     # 剩下的再挡掉百分之几


WEAPONS = {
    "fist": Weapon("拳头", "unarmed", 1, 1, 3, ap=3, range=1),
    "kick": Weapon("脚", "unarmed", 0, 1, 3, ap=3, range=1),  # 两只手都废了只能踢, 伤害跟拳头一样
    "knife": Weapon("小刀", "melee", 1, 2, 6, ap=3, range=1, accuracy=5),
    "pipe": Weapon("铁棍", "melee", 1, 3, 7, ap=4, range=1),
    "sledgehammer": Weapon("大锤", "melee", 2, 6, 14, ap=4, range=1, accuracy=-10, vigor_req=6),
    "pistol": Weapon("手枪", "gun", 1, 5, 12, ap=4, range=15, magazine=8),
    "rifle": Weapon("步枪", "gun", 2, 8, 18, ap=5, range=30, accuracy=10, magazine=5, vigor_req=4),
    "smg": Weapon("冲锋枪", "gun", 2, 4, 9, ap=4, range=15, accuracy=-5, magazine=20, burst_ap=6),
    "grenade": Weapon("手雷", "throw", 1, 10, 25, ap=5, range=0),  # 射程看体魄 (rules.throw_range); 炸 3×3
}

# 练习场里能挑的武器 (按这个顺序摆), 还有每种枪带多少备用子弹、手雷拿几个
CHOICES = ["fist", "knife", "pipe", "sledgehammer", "pistol", "rifle", "smg", "grenade"]
SPARE_AMMO = {"pistol": 24, "rifle": 15, "smg": 20}  # 冲锋枪 2026-10-05 从 60 减到 20 (照原版: 连发费子弹, 得省着用)
GRENADES = 3

ARMORS = {
    "none": Armor("没穿护甲", 0, 0, 0),
    "leather": Armor("皮甲", 5, 2, 20),
    "metal": Armor("金属甲", 10, 4, 30),
}
