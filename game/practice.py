"""
练习场的布置: 一小块空地, 你和两个强盗。
这些只是用来试战斗规则的假人, 不是正式剧情。
开打前可以在「准备」画面里自己分能力值、挑两只手的武器和护甲 (见 Setup)。
"""

from . import gear
from .combat import ENEMY, PLAYER, Battle, Unit

MAP_SIZE = 14
STAT_ORDER = ["survival", "agility", "vigor", "intellect", "observation", "resolve"]  # 救世主系统的顺序
START_POINTS = 18  # 每项先给 1 分, 再自己分 18 点 (加起来 24)
MIN_STAT, MAX_STAT = 1, 10


def stats(survival, agility, vigor, intellect, observation, resolve):
    """六个能力值 (开局每项 1 分, 再分 18 点, 加起来 24)"""
    return {"survival": survival, "agility": agility, "vigor": vigor,
            "intellect": intellect, "observation": observation, "resolve": resolve}


class Setup:
    """你开打前的准备: 能力值、右手左手拿什么、穿什么护甲"""

    def __init__(self):
        self.stats = stats(3, 6, 5, 2, 5, 3)
        self.hands = ["pistol", "knife"]
        self.armor = "leather"

    def points_left(self):
        return MIN_STAT * 6 + START_POINTS - sum(self.stats.values())

    def change(self, stat, delta):
        """能力值加 1 或减 1 (不能低于 1、高于 10, 也不能超过能分的点数)"""
        value = self.stats[stat] + delta
        if not MIN_STAT <= value <= MAX_STAT:
            return False
        if delta > 0 and self.points_left() < delta:
            return False
        self.stats[stat] = value
        return True

    def ready(self):
        """点数分完了才能开打"""
        return self.points_left() == 0

    def make_player(self):
        hands = [None if w == "fist" else w for w in self.hands]
        ammo = {}
        for w in hands:
            if w in gear.SPARE_AMMO:
                ammo[w] = ammo.get(w, 0) + gear.SPARE_AMMO[w]
        unit = Unit("你", PLAYER, self.stats, hands, armor=self.armor, ammo=ammo, pos=(3, 10), short="你")
        for hand, w in enumerate(hands):
            if w == "grenade":
                unit.loaded[hand] = gear.GRENADES
        return unit


def make_battle(rng=None, setup=None):
    you = (setup or Setup()).make_player()
    # 强盗比你弱 (能力值加起来不到 24), 枪手也没穿护甲。
    # 用默认的准备, 电脑用敌人那套简单想法替你打, 大约七成能赢; 会动脑子的话赢面更大。
    knife = Unit("持刀强盗", ENEMY, stats(3, 4, 4, 1, 3, 3),
                 hands=["knife", None], armor="leather",
                 pos=(10, 3), short="刀")
    gunner = Unit("持枪强盗", ENEMY, stats(3, 3, 4, 1, 3, 3),
                  hands=["pistol", None], armor="none", ammo={"pistol": 16},
                  pos=(11, 6), short="枪")
    return Battle([you, knife, gunner], width=MAP_SIZE, height=MAP_SIZE, rng=rng, initiator=you)
