class_name Rules
## 战斗规则里的公式。
## 2026-10-05 跟用户一条条定的, 写在 GitHub 看板的「战斗系统」卡片上。数字以后在练习场试玩再调。

## 救世主系统的六个能力值 (每项 1 到 10 分): 代码里用英文名, 画面上显示中文名
const STAT_NAMES := {
	"survival": "适应",
	"agility": "灵巧",
	"vigor": "体魄",
	"intellect": "学识",
	"observation": "洞察",
	"resolve": "意志",
}
const STAT_ORDER := ["survival", "agility", "vigor", "intellect", "observation", "resolve"]

## 近身打的武器种类 (只能打挨着的格子, 命中也看体魄)
const CLOSE_KINDS := ["unarmed", "melee"]

const RELOAD_AP := 2       # 换子弹花几点
const PICKUP_AP := 2       # 捡起地上的东西花几点
const PACK_AP := 4         # 战斗里打开背包花几点 (原版二代也是 4 点; 打开以后在里面换东西不花)
const AIM_AP := 1          # 瞄准部位多花几点
const GET_UP_AP := 3       # 被打倒在地上, 下一回合先花几点爬起来
const BLIND_PENALTY := 30  # 瞎了以后命中扣多少
const BURST_ROUNDS := 10   # 连发一次打几发 (2026-10-05 照原版从 5 改成 10)
const BURST_SPREAD := 10   # 连发往两边散的子弹, 歪出去几度
const BLAST_RADIUS := 1    # 手雷炸多大: 落点周围 1 格, 也就是 3×3
const MIN_HIT := 5         # 命中几率最低 5%
const MAX_HIT := 95        # 命中几率最高 95%

## 能瞄准的八个部位: [代码里的名字, 中文名, 命中扣多少]。
## 瞄准越难打的部位, 暴击几率加得越多 (加扣分的一半); 特殊效果暴击了才发生。
const BODY_PARTS := [
	["head", "头", 40],
	["eyes", "眼睛", 60],
	["torso", "身上", 0],
	["right_arm", "右手", 30],
	["left_arm", "左手", 30],
	["groin", "下身", 30],
	["right_leg", "右腿", 20],
	["left_leg", "左腿", 20],
]
const ARM_OF_HAND := ["right_arm", "left_arm"]  # 右手 (0) 和左手 (1) 是哪只胳膊
const LEGS := ["right_leg", "left_leg"]

## 压力槽 (我们自己的特色, 原版没有)。用户 2026-10-10 定的做法写在看板「压力槽」卡片上;
## 下面的数字是 Claude 先定的, 试玩再调。压力 0～100, 分三段: 冷静 / 紧张 / 慌乱
const STRESS_START := 10          # 开打时多少 (练习场每局重新开始)
const STRESS_MAX := 100           # 满了就吓呆
const CALM_BELOW := 30            # 0～29 冷静
const PANIC_FROM := 70            # 70～100 慌乱 (中间是紧张)
const STRESS_AFTER_FREEZE := 70   # 吓呆了一回合以后降回多少
# 涨多少 (还要按意志打折, 见 stress_gain)
const STRESS_PER_HP := 3          # 掉 1 点生命 (2026-10-10 量过 2 / 3 / 4, 用户选了 3: 大约四分之一的局你会慌)
const STRESS_CRIT := 10           # 被暴击, 再加这么多
const STRESS_SHOT_AT := 3         # 被打了可是没伤到 (没打中、被护甲挡住)
const STRESS_BLAST := 5           # 手雷在旁边炸 (落点 2 格以内)
const STRESS_ALLY_DOWN := 15      # 同伴被打倒
# 降多少
const STRESS_RELIEF := 15         # 打倒一个敌人, 松一口气
# 冷静的好处
const CALM_AIM_EASE := 10         # 瞄准部位的扣分少这么多
const CALM_CRIT := 5              # 暴击几率加这么多
# 慌乱的好处和坏处
const PANIC_AP := 1               # 肾上腺素: 行动点多 1 点
const PANIC_MELEE := 2            # 近身打的伤害多 2 点
const PANIC_RANGED := 10          # 手抖: 开枪、扔手雷命中扣这么多
const PANIC_AIM := 10             # 瞄准部位再扣这么多
const PANIC_CRIT := 5             # 眼花: 暴击几率扣这么多
const FUMBLE_CHANCE := 10         # 慌乱时每次攻击, 有百分之几出大失败


static func is_close(kind: String) -> bool:
	return kind in CLOSE_KINDS


static func part_name(part: String) -> String:
	for p in BODY_PARTS:
		if p[0] == part:
			return p[1]
	return ""


static func part_penalty(part: String) -> int:
	for p in BODY_PARTS:
		if p[0] == part:
			return p[2]
	return 0


## 瞄准这个部位, 暴击几率加多少 (命中扣分的一半); part 是 "" 就是没瞄准
static func aim_crit_bonus(part: String) -> int:
	return half(part_penalty(part))


## 走一格花几点: 腿好好的 1 点, 瘸一条 2 点, 两条都瘸 4 点
static func step_cost(crippled_legs: int) -> int:
	return [1, 2, 4][crippled_legs]


## 每回合的行动点数 = 5 + 灵巧 ÷ 2 (舍掉小数)
static func action_points(agility: int) -> int:
	return 5 + half(agility)


## 反应值, 高的先动。现在就等于洞察 (以后特长、性格特点可以加)
static func reaction(observation: int) -> int:
	return observation


## 生命值 = 15 + 体魄 × 3
static func max_hp(vigor: int) -> int:
	return 15 + vigor * 3


## 近身打的伤害再加 体魄 ÷ 2 (舍掉小数)
static func melee_bonus(vigor: int) -> int:
	return half(vigor)


## 连发的子弹怎么分: [对准目标的, 往一边歪的, 往另一边歪的]。三分之一 (往上取整) 对准, 剩下的分到两边
static func burst_split(shots: int) -> Array:
	var center := ceili(shots / 3.0)
	var rest := shots - center
	return [center, ceili(rest / 2.0), floori(rest / 2.0)]


## 手雷扔多远 = 体魄 × 2 格 (力气大扔得远)
static func throw_range(vigor: int) -> int:
	return vigor * 2


## 防御 = 灵巧 + 护甲的防御 + 上回合没用完的点数 × 2
static func defense(agility: int, armor_defense: int, leftover_ap: int) -> int:
	return agility + armor_defense + leftover_ap * 2


## 两个格子隔几步。可以斜着走, 斜着也算 1 步, 所以是横竖里大的那个
static func distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## 命中几率 (百分比)。
## 起点: 用枪 40 + 灵巧 × 5; 近身 40 + 灵巧 × 3 + 体魄 × 2
## 加: 武器准头、bonus (特长、压力); 减: 敌人防御、距离 (洞察几分就几格内不扣, 再远每格 4%)、瞄准部位、瞎了 30
## 最低 5%, 最高 95%
static func hit_chance(stats: Dictionary, weapon: Gear.Weapon, target_defense: int, dist: int,
		aim_penalty: int = 0, bonus: int = 0, blind: bool = false) -> int:
	var chance: int
	var far := 0
	if is_close(weapon.kind):
		chance = 40 + stats["agility"] * 3 + stats["vigor"] * 2
	else:
		chance = 40 + stats["agility"] * 5
		far = maxi(0, dist - stats["observation"]) * 4
	chance += weapon.accuracy + bonus - target_defense - far - aim_penalty
	if blind:
		chance -= BLIND_PENALTY
	return clampi(chance, MIN_HIT, MAX_HIT)


## 暴击几率 = 洞察 × 2 + 瞄准部位的加成 (打中以后再掷一次)
static func crit_chance(observation: int, aim_bonus: int = 0) -> int:
	return observation * 2 + aim_bonus


## 伤害过护甲: 暴击先翻倍; 再减掉护甲固定挡的几点; 剩下的按比例打折; 最后四舍五入。
## 比如 9 点打皮甲 (挡 2 点、再打 8 折): 9 - 2 = 7, 7 × 0.8 = 5.6, 算 6 点。
static func damage_after_armor(raw: int, crit: bool, armor: Gear.Armor) -> int:
	if crit:
		raw *= 2
	var left := raw - armor.threshold
	if left <= 0:
		return 0
	# 用整数算四舍五入, 免得小数算出 5.499999 这种怪数
	return floori((left * (100 - armor.resist) + 50) / 100.0)


# ---------- 压力槽 ----------

const STRESS_ZONES := ["calm", "tense", "panic"]  # 从低到高
const STRESS_ZONE_NAMES := {"calm": "冷静", "tense": "紧张", "panic": "慌乱"}


## 压力在哪一段: "calm" 冷静 (0～29) / "tense" 紧张 (30～69) / "panic" 慌乱 (70～100)
static func stress_zone(stress: int) -> String:
	if stress < CALM_BELOW:
		return "calm"
	if stress >= PANIC_FROM:
		return "panic"
	return "tense"


static func stress_zone_name(stress: int) -> String:
	return STRESS_ZONE_NAMES[stress_zone(stress)]


## 压力真正涨多少: 意志每 1 点少涨 5% (意志 10 只涨一半), 四舍五入
static func stress_gain(raw: int, resolve: int) -> int:
	return floori((raw * (100 - clampi(resolve, 0, 10) * 5) + 50) / 100.0)


## 每回合开头自己降多少 = 意志 + 2
static func stress_decay(resolve: int) -> int:
	return resolve + 2


## 瞄准部位的扣分, 算上压力: 冷静少扣 10 (最少不扣); 慌乱再多扣 10。part 是 "" 就是没瞄准, 不扣
static func aim_penalty(part: String, stress: int) -> int:
	if part == "":
		return 0
	var p := part_penalty(part)
	match stress_zone(stress):
		"calm":
			p = maxi(0, p - CALM_AIM_EASE)
		"panic":
			p += PANIC_AIM
	return p


## 压力让命中加减多少 (不算瞄准部位): 慌乱时远处打 (枪、手雷) 扣 10
static func stress_hit_bonus(stress: int, weapon_kind: String) -> int:
	if stress_zone(stress) == "panic" and not is_close(weapon_kind):
		return -PANIC_RANGED
	return 0


## 压力让暴击几率加减多少: 冷静 +5, 慌乱 -5
static func stress_crit_bonus(stress: int) -> int:
	match stress_zone(stress):
		"calm":
			return CALM_CRIT
		"panic":
			return -PANIC_CRIT
	return 0


## 慌乱的时候行动点多 1 点
static func stress_ap_bonus(stress: int) -> int:
	return PANIC_AP if stress_zone(stress) == "panic" else 0


## 慌乱的时候近身打的伤害多 2 点
static func stress_melee_bonus(stress: int) -> int:
	return PANIC_MELEE if stress_zone(stress) == "panic" else 0


## 整数除以 2, 舍掉小数 (负数不会用到)
static func half(n: int) -> int:
	return floori(n / 2.0)
