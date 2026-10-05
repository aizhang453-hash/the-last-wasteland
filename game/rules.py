"""
战斗规则里的公式。
2026-10-05 跟用户一条条定的, 写在 GitHub 看板的「战斗系统」卡片上。数字以后在练习场试玩再调。
"""

# 救世主系统的六个能力值 (每项 1 到 10 分): 代码里用英文名, 画面上显示中文名
STAT_NAMES = {
    "survival": "适应",
    "agility": "灵巧",
    "vigor": "体魄",
    "intellect": "学识",
    "observation": "洞察",
    "resolve": "意志",
}

# 近身打的武器种类 (只能打挨着的格子, 命中也看体魄)
CLOSE_KINDS = ("unarmed", "melee")

RELOAD_AP = 2  # 换子弹花几点
PICKUP_AP = 2  # 捡起地上的武器花几点
AIM_AP = 1     # 瞄准部位多花几点
GET_UP_AP = 3  # 被打倒在地上, 下一回合先花几点爬起来
BLIND_PENALTY = 30  # 瞎了以后命中扣多少
BURST_ROUNDS = 5    # 连发一次打几发
BLAST_RADIUS = 1    # 手雷炸多大: 落点周围 1 格, 也就是 3×3
MIN_HIT = 5    # 命中几率最低 5%
MAX_HIT = 95   # 命中几率最高 95%

# 能瞄准的八个部位: (代码里的名字, 中文名, 命中扣多少)。
# 瞄准越难打的部位, 暴击几率加得越多 (加扣分的一半); 特殊效果暴击了才发生。
BODY_PARTS = [
    ("head", "头", 40),
    ("eyes", "眼睛", 60),
    ("torso", "身上", 0),
    ("right_arm", "右手", 30),
    ("left_arm", "左手", 30),
    ("groin", "下身", 30),
    ("right_leg", "右腿", 20),
    ("left_leg", "左腿", 20),
]
PART_NAMES = {key: name for key, name, _ in BODY_PARTS}
PART_PENALTY = {key: penalty for key, _, penalty in BODY_PARTS}
ARM_OF_HAND = ("right_arm", "left_arm")  # 右手 (0) 和左手 (1) 是哪只胳膊


def aim_crit_bonus(part):
    """瞄准这个部位, 暴击几率加多少 (命中扣分的一半)"""
    return PART_PENALTY[part] // 2 if part else 0


def step_cost(crippled_legs):
    """走一格花几点: 腿好好的 1 点, 瘸一条 2 点, 两条都瘸 4 点"""
    return (1, 2, 4)[crippled_legs]


def action_points(agility):
    """每回合的行动点数 = 5 + 灵巧 ÷ 2 (舍掉小数)"""
    return 5 + agility // 2


def reaction(observation):
    """反应值, 高的先动。现在就等于洞察 (以后特长、性格特点可以加)"""
    return observation


def max_hp(vigor):
    """生命值 = 15 + 体魄 × 3"""
    return 15 + vigor * 3


def melee_bonus(vigor):
    """近身打的伤害再加 体魄 ÷ 2 (舍掉小数)"""
    return vigor // 2


def throw_range(vigor):
    """手雷扔多远 = 体魄 × 2 格 (力气大扔得远)"""
    return vigor * 2


def defense(agility, armor_defense, leftover_ap):
    """防御 = 灵巧 + 护甲的防御 + 上回合没用完的点数 × 2"""
    return agility + armor_defense + leftover_ap * 2


def distance(a, b):
    """两个格子隔几步。可以斜着走, 斜着也算 1 步, 所以是横竖里大的那个"""
    return max(abs(a[0] - b[0]), abs(a[1] - b[1]))


def hit_chance(stats, weapon, target_defense, dist, aim_penalty=0, perk_bonus=0, blind=False):
    """
    命中几率 (百分比)。
    起点: 用枪 40 + 灵巧 × 5; 近身 40 + 灵巧 × 3 + 体魄 × 2
    加: 武器准头、特长; 减: 敌人防御、距离 (洞察几分就几格内不扣, 再远每格 4%)、瞄准部位、瞎了 30
    最低 5%, 最高 95%
    """
    if weapon.kind in CLOSE_KINDS:
        chance = 40 + stats["agility"] * 3 + stats["vigor"] * 2
        far = 0
    else:
        chance = 40 + stats["agility"] * 5
        far = max(0, dist - stats["observation"]) * 4
    chance += weapon.accuracy + perk_bonus - target_defense - far - aim_penalty
    if blind:
        chance -= BLIND_PENALTY
    return max(MIN_HIT, min(MAX_HIT, chance))


def crit_chance(observation, aim_bonus=0):
    """暴击几率 = 洞察 × 2 + 瞄准部位的加成 (打中以后再掷一次)"""
    return observation * 2 + aim_bonus


def damage_after_armor(raw, crit, armor):
    """
    伤害过护甲: 暴击先翻倍; 再减掉护甲固定挡的几点; 剩下的按比例打折; 最后四舍五入。
    比如 9 点打皮甲 (挡 2 点、再打 8 折): 9 - 2 = 7, 7 × 0.8 = 5.6, 算 6 点。
    """
    if crit:
        raw *= 2
    left = raw - armor.threshold
    if left <= 0:
        return 0
    # 用整数算四舍五入, 免得小数算出 5.499999 这种怪数
    return (left * (100 - armor.resist) + 50) // 100
