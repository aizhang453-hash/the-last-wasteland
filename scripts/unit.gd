class_name Unit
extends RefCounted
## 战斗里的一个人 (玩家这边或者敌人)

const PLAYER := "player"
const ENEMY := "enemy"
const HAND_NAMES := ["右手", "左手"]

var name: String
var short: String          # 画面上排队头像里写的一个字
var side: String
var stats: Dictionary
var hands: Array           # 两只手拿的武器, 比如 ["pistol", "knife"]; "" 是空手
var active := 0            # 现在用哪只手: 0 右手, 1 左手
var spare: Dictionary      # 备用子弹, 比如 {"pistol": 24}
var loaded: Array          # 每只手的枪里现在有几发 (一开始是满的); 拿的是手雷的话, 是手上有几个手雷
var burst := [false, false]  # 每只手上的枪是不是换成了连发 (记在枪上, 换手、捡起别的枪不会带过去)
var armor: Gear.Armor
var max_hp: int
var hp: int
var pos: Vector2i
var ap := 0                # 这回合还剩几点
var leftover := 0          # 上回合没用完的点数 (变成防御, 到自己下回合开始为止)
# 被暴击打中部位以后的样子 (练习场里没有治疗, 这一局打完才好)
var crippled := {}         # 瘸了、废了的手脚, 比如 {"left_leg": true}
var blind := false         # 眼睛看不见了: 命中 -30
var knocked_down := false  # 倒在地上: 下一回合先花 3 点爬起来
var knocked_out := false   # 被打晕: 下一回合不能动


func _init(p_name: String, p_side: String, p_stats: Dictionary, p_hands: Array, p_armor := "none",
		p_ammo := {}, p_pos := Vector2i.ZERO, p_short := "") -> void:
	name = p_name
	short = p_short if p_short != "" else p_name.left(1)
	side = p_side
	stats = p_stats.duplicate()
	hands = p_hands.duplicate()
	spare = p_ammo.duplicate()
	loaded = []
	for w in hands:
		if w == "":
			loaded.append(0)
		elif Gear.WEAPONS[w].kind == "throw":
			loaded.append(spare.get(w, 1))
			spare.erase(w)
		else:
			loaded.append(Gear.WEAPONS[w].magazine)
	armor = Gear.ARMORS[p_armor]
	max_hp = Rules.max_hp(stats["vigor"])
	hp = max_hp
	pos = p_pos


func _to_string() -> String:
	return "<%s %s 生命 %d/%d>" % [name, pos, hp, max_hp]


func alive() -> bool:
	return hp > 0


func weapon_id() -> String:
	if arms_crippled() == 2:
		return "kick"  # 两只手都废了, 只能踢
	return hands[active] if hands[active] != "" else "fist"


func weapon() -> Gear.Weapon:
	return Gear.WEAPONS[weapon_id()]


func ammo_in_hand() -> int:
	return loaded[active]


## 这只手还能用吗 (胳膊没废)
func hand_ok(hand: int) -> bool:
	return not crippled.has(Rules.ARM_OF_HAND[hand])


func arms_crippled() -> int:
	var n := 0
	for arm in Rules.ARM_OF_HAND:
		if crippled.has(arm):
			n += 1
	return n


func legs_crippled() -> int:
	var n := 0
	for leg in Rules.LEGS:
		if crippled.has(leg):
			n += 1
	return n


## 走一格花几点 (腿瘸了要多花)
func step_cost() -> int:
	return Rules.step_cost(legs_crippled())


func defense() -> int:
	return Rules.defense(stats["agility"], armor.defense, leftover)


## 现在是连发吗 (手上的武器能连发, 而且这把枪换成了连发)
func bursting() -> bool:
	return burst[active] and weapon().burst_ap > 0


## 身上的伤 (给画面显示)
func statuses() -> Array:
	var words := []
	for p in Rules.BODY_PARTS:
		if crippled.has(p[0]):
			words.append(p[1] + ("瘸了" if String(p[0]).ends_with("leg") else "废了"))
	if blind:
		words.append("瞎了")
	if knocked_out:
		words.append("晕了")
	elif knocked_down:
		words.append("倒在地上")
	return words
