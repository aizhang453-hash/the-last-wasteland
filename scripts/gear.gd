class_name Gear
## 武器和护甲。数字是 2026-10-05 定的起点 (看板「战斗系统」卡片), 以后试玩再调。


class Weapon:
	var id: String
	var name: String
	var kind: String       # unarmed 空手 / melee 近身武器 / gun 枪 / throw 投掷
	var hands: int         # 单手 1, 双手 2
	var dmg_min: int       # 伤害范围
	var dmg_max: int
	var ap: int            # 打一下花几点
	var reach: int         # 射程 (格); 近身是 1, 只能打挨着的; 手雷看体魄 (Rules.throw_range)
	var accuracy: int      # 准头, 加到命中几率上
	var magazine: int      # 弹夹装几发; 0 是不用子弹
	var burst_ap: int      # 连发花几点; 0 是不能连发
	var vigor_req: int     # 要多少体魄 (不够会怎样, 以后再加)

	func _init(p_id: String, p_name: String, p_kind: String, p_hands: int, p_min: int, p_max: int, p_ap: int,
			p_reach: int, p_accuracy := 0, p_magazine := 0, p_burst_ap := 0, p_vigor_req := 0) -> void:
		id = p_id
		name = p_name
		kind = p_kind
		hands = p_hands
		dmg_min = p_min
		dmg_max = p_max
		ap = p_ap
		reach = p_reach
		accuracy = p_accuracy
		magazine = p_magazine
		burst_ap = p_burst_ap
		vigor_req = p_vigor_req


class Armor:
	var id: String
	var name: String
	var defense: int    # 加到防御上 (让人更难打中)
	var threshold: int  # 先挡掉几点伤害
	var resist: int     # 剩下的再挡掉百分之几

	func _init(p_id: String, p_name: String, p_defense: int, p_threshold: int, p_resist: int) -> void:
		id = p_id
		name = p_name
		defense = p_defense
		threshold = p_threshold
		resist = p_resist


static var WEAPONS := {
	"fist": Weapon.new("fist", "拳头", "unarmed", 1, 1, 3, 3, 1),
	"kick": Weapon.new("kick", "脚", "unarmed", 0, 1, 3, 3, 1),  # 两只手都废了只能踢, 伤害跟拳头一样
	"knife": Weapon.new("knife", "小刀", "melee", 1, 2, 6, 3, 1, 5),
	"pipe": Weapon.new("pipe", "铁棍", "melee", 1, 3, 7, 4, 1),
	"sledgehammer": Weapon.new("sledgehammer", "大锤", "melee", 2, 6, 14, 4, 1, -10, 0, 0, 6),
	"pistol": Weapon.new("pistol", "手枪", "gun", 1, 5, 12, 4, 15, 0, 8),
	"rifle": Weapon.new("rifle", "步枪", "gun", 2, 8, 18, 5, 30, 10, 5, 0, 4),
	"smg": Weapon.new("smg", "冲锋枪", "gun", 2, 4, 9, 4, 15, -5, 20, 6),
	"grenade": Weapon.new("grenade", "手雷", "throw", 1, 10, 25, 5, 0),  # 扔多远看体魄; 炸 3×3
}

## 练习场里能挑的武器 (按这个顺序摆), 还有每种枪带多少备用子弹、手雷拿几个
const CHOICES := ["fist", "knife", "pipe", "sledgehammer", "pistol", "rifle", "smg", "grenade"]
const SPARE_AMMO := {"pistol": 24, "rifle": 15, "smg": 20}  # 冲锋枪 2026-10-05 从 60 减到 20 (照原版: 连发费子弹)
const GRENADES := 3

static var ARMORS := {
	"none": Armor.new("none", "没穿护甲", 0, 0, 0),
	"leather": Armor.new("leather", "皮甲", 5, 2, 20),
	"metal": Armor.new("metal", "金属甲", 10, 4, 30),
}
const ARMOR_ORDER := ["none", "leather", "metal"]
