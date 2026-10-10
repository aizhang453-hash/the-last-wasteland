extends TestCase
## 背包的规则: 重量、能背多少、拿到手上、穿上、放回背包、武器架; 战斗里打开背包花点数、捡东西、扔东西。


## 默认准备 (手枪、小刀、皮甲、一盒手枪子弹) 的那个人; 体魄可以改
func kit(vigor := 5) -> Unit:
	var s := Practice.Setup.new()
	s.stats["vigor"] = vigor
	return s.kit


func names(list: Array) -> Array:
	return list.map(func(it: Inventory.Item) -> String: return str(it))


func test_capacity_and_kg() -> void:
	eq(Inventory.capacity(5), 60000, "体魄 5 能背 60 公斤")
	eq(Inventory.capacity(1), 20000)
	eq(Inventory.capacity(10), 110000)
	eq(Inventory.kg(7700), "7.7")
	eq(Inventory.kg(60000), "60")
	eq(Inventory.kg(500), "0.5")


func test_default_weight() -> void:
	var u := kit()
	# 手枪 1.5 + 枪里 8 发 0.16 + 小刀 0.5 + 皮甲 4 + 24 发子弹 0.48
	eq(Inventory.weight(u), 6640)
	eq(Inventory.room(u), 60000 - 6640)
	eq(names(Inventory.entries(u)), ["<手枪子弹 ×24>"], "背包里只有子弹")


func test_equip_swaps_with_hand() -> void:
	var u := kit()
	u.burst[0] = true
	eq(Inventory.add(u, Inventory.weapon("rifle")), "")
	var rifle: Inventory.Item = u.pack[0]
	eq(Inventory.equip(u, rifle, 0), "")
	eq(u.hands, ["rifle", "knife"])
	eq(u.loaded[0], 5, "步枪是装满的")
	eq(u.burst[0], false, "刚拿到手上的枪是单发")
	eq(names(u.pack), ["<手枪>"], "原来的手枪放回背包")
	eq(u.pack[0].loaded, 8)
	eq(Inventory.weight(u), 6640 + 4500 + 5 * 20, "挪来挪去重量不变, 只多了步枪")


func test_gun_keeps_its_ammo() -> void:
	var u := kit()
	u.loaded[0] = 3
	eq(Inventory.unequip(u, 0), "")
	eq(u.hands, ["", "knife"])
	eq(u.pack[0].loaded, 3)
	Inventory.equip(u, u.pack[0], 1)
	eq(u.hands, ["", "pistol"])
	eq(u.loaded, [0, 3])
	eq(names(u.pack), ["<小刀>"])
	eq(Inventory.unequip(u, 0), "这只手是空的")


func test_crippled_hands() -> void:
	var u := kit()
	Inventory.add(u, Inventory.weapon("rifle"))
	Inventory.add(u, Inventory.weapon("pipe"))
	u.crippled["right_arm"] = true
	eq(Inventory.equip(u, u.pack[1], 0), "右手废了, 拿不了东西")
	eq(Inventory.equip(u, u.pack[0], 1), "步枪要两只手都好才能用")
	eq(Inventory.equip(u, u.pack[1], 1), "", "单手的铁棍能拿在好的左手上")
	eq(u.hands, ["pistol", "pipe"])
	eq(Inventory.swap_hands(u), "右手废了, 拿不了东西", "铁棍换不到废了的右手上")


func test_wear_and_take_off() -> void:
	var u := kit()
	Inventory.add(u, Inventory.Item.new("armor", "metal"))
	eq(Inventory.wear(u, u.pack[0]), "")
	eq(u.armor.id, "metal")
	eq(names(u.pack), ["<皮甲>"])
	eq(Inventory.take_off(u), "")
	eq(u.armor.id, "none")
	eq(names(u.pack), ["<皮甲>", "<金属甲>"])
	eq(Inventory.take_off(u), "没穿护甲")
	eq(Inventory.equip(u, u.pack[0], 0), "只有武器能拿在手上")
	eq(Inventory.wear(u, Inventory.entries(u)[2]), "这个不能穿", "子弹不能穿")


func test_grenades_stack() -> void:
	var u := kit()
	Inventory.add(u, Inventory.weapon("grenade"))
	Inventory.add(u, Inventory.weapon("grenade"))
	eq(names(u.pack), ["<手雷 ×2>"], "手雷合成一堆")
	eq(u.pack[0].weight(), 1000)
	Inventory.equip(u, u.pack[0], 1)
	eq(u.hands, ["pistol", "grenade"])
	eq(u.loaded[1], 2, "整堆拿到手上")
	Inventory.add(u, Inventory.weapon("grenade"))
	Inventory.unequip(u, 1)
	eq(names(u.pack), ["<小刀>", "<手雷 ×3>"], "放回背包又合到一起")


func test_swap_hands() -> void:
	var u := kit()
	u.burst = [true, false]
	u.loaded[0] = 5
	eq(Inventory.swap_hands(u), "")
	eq(u.hands, ["knife", "pistol"])
	eq(u.loaded, [0, 5])
	eq(u.burst, [false, true], "连发开关跟着枪走")


func test_weight_limit() -> void:
	var u := kit(1)  # 体魄 1: 只能背 20 公斤
	eq(Inventory.add(u, Inventory.Item.new("armor", "metal")), "背不动了 (最多背 20 公斤)")
	eq(u.pack, [], "背不动就不放进去")
	eq(Inventory.add(u, Inventory.weapon("sledgehammer")), "")
	eq(Inventory.room(u), 20000 - 6640 - 6000)


func test_ammo_entries() -> void:
	var u := kit()
	Inventory.add(u, Inventory.Item.new("ammo", "pistol", 24))
	Inventory.add(u, Inventory.Item.new("ammo", "rifle", 15))
	eq(u.spare, {"pistol": 48, "rifle": 15}, "子弹记在 spare 里, 同一种合在一起")
	var list := Inventory.entries(u)
	eq(names(list), ["<手枪子弹 ×48>", "<步枪子弹 ×15>"])
	Inventory.remove(u, list[1])
	eq(u.spare, {"pistol": 48})


func test_rack() -> void:
	var rack := Inventory.rack()
	eq(names(rack), ["<小刀>", "<铁棍>", "<大锤>", "<手枪>", "<步枪>", "<冲锋枪>", "<手雷 ×1>",
			"<手枪子弹 ×24>", "<步枪子弹 ×15>", "<冲锋枪子弹 ×20>", "<皮甲>", "<金属甲>"])
	eq(rack[5].loaded, 20, "武器架上的枪是装满的")
	var u := kit()
	Inventory.add(u, rack[4].copy())
	Inventory.add(u, rack[4].copy())
	eq(names(u.pack), ["<步枪>", "<步枪>"], "武器架上的拿不完")
	eq(Inventory.rack().size(), 12)


func test_descriptions() -> void:
	for it in Inventory.rack():
		var words := Inventory.describe(it)
		has_text(words, it.name())
		has_text(words, "公斤")
	has_text(Inventory.describe(Inventory.Item.new("ammo", "smg", 7)), "一共 7 发")


# ---------- 准备 ----------

func test_setup_overweight_blocks_start() -> void:
	var s := Practice.Setup.new()
	Inventory.add(s.kit, Inventory.Item.new("armor", "metal"))
	Inventory.add(s.kit, Inventory.weapon("sledgehammer"))
	eq(s.problem(), "")
	s.change("vigor", -4)  # 体魄 1, 能背 20 公斤, 现在背着 27.6 公斤
	has_text(s.problem(), "还有 4 点没分完")
	s.change("survival", 4)
	has_text(s.problem(), "背太多了 (最多背 20 公斤)")
	check(not s.ready())


func test_make_player_copies_the_kit() -> void:
	var s := Practice.Setup.new()
	Inventory.add(s.kit, Inventory.weapon("rifle"))
	s.kit.loaded[0] = 2
	var you := s.make_player()
	eq(you.loaded, [2, 0])
	eq(names(you.pack), ["<步枪>"])
	you.pack[0].loaded = 0
	you.spare["pistol"] = 0
	eq(s.kit.pack[0].loaded, 5, "打仗用掉的不影响准备画面")
	eq(s.kit.spare["pistol"], 24)


# ---------- 战斗里 ----------

func battle() -> Battle:
	var you := TestCase.person("你", Unit.PLAYER, Vector2i(3, 3), 6, 5, 5, ["pistol", "knife"], "leather", {"pistol": 24})
	var foe := TestCase.person("敌", Unit.ENEMY, Vector2i(10, 10))
	return Battle.new([you, foe], 14, 14, FixedDice.new(), you)


func test_open_pack_costs_ap() -> void:
	var b := battle()
	var you: Unit = b.units[0]
	you.ap = 8
	eq(b.open_pack_problem(you), "")
	check(b.open_pack(you))
	eq(you.ap, 4, "打开背包花 4 点")
	has_text(b.messages[-1][0], "打开背包")
	you.ap = 3
	eq(b.open_pack_problem(you), "行动点不够 (要 4 点)")
	check(not b.open_pack(you))
	eq(you.ap, 3)
	check(b.open_pack_problem(b.units[1]) != "", "没轮到他")


func test_pickup_goes_to_hand_or_pack() -> void:
	var b := battle()
	var you: Unit = b.units[0]
	you.ap = 20
	var smg := Battle.GroundItem.new(Vector2i(4, 3), Inventory.weapon("smg"))
	var ammo := Battle.GroundItem.new(Vector2i(3, 4), Inventory.Item.new("ammo", "smg", 20))
	var vest := Battle.GroundItem.new(Vector2i(2, 3), Inventory.Item.new("armor", "metal"))
	b.ground = [smg, ammo, vest]
	check(b.pickup(you, smg))
	eq(you.hands, ["pistol", "knife"])
	eq(names(you.pack), ["<冲锋枪>"], "两只手都拿着东西: 放进背包")
	has_text(b.messages[-1][0], "放进背包")
	check(b.pickup(you, ammo))
	eq(you.spare, {"pistol": 24, "smg": 20})
	check(b.pickup(you, vest))
	eq(names(you.pack), ["<冲锋枪>", "<金属甲>"])
	eq(you.armor.id, "leather", "捡到的护甲不会自己穿上")
	eq(b.ground, [])
	eq(you.ap, 20 - 3 * Rules.PICKUP_AP)
	# 空着手捡武器: 直接拿在手上
	Inventory.unequip(you, 1)
	var pipe := Battle.GroundItem.new(Vector2i(4, 4), Inventory.weapon("pipe"))
	b.ground = [pipe]
	check(b.pickup(you, pipe))
	eq(you.hands, ["pistol", "pipe"])
	eq(you.active, 1)


func test_pickup_too_heavy() -> void:
	var b := battle()
	var you: Unit = b.units[0]
	you.stats["vigor"] = 1
	Inventory.add(you, Inventory.weapon("sledgehammer"))
	var vest := Battle.GroundItem.new(Vector2i(4, 3), Inventory.Item.new("armor", "metal"))
	b.ground = [vest]
	eq(b.pickup_problem(you, vest), "背不动了 (最多背 20 公斤)")
	check(not b.pickup(you, vest))


func test_throw_away() -> void:
	var b := battle()
	var you: Unit = b.units[0]
	Inventory.add(you, Inventory.weapon("rifle"))
	var first := b.throw_away(you, "pack", you.pack[0])
	eq(first.weapon_id, "rifle")
	eq(Rules.distance(first.pos, you.pos), 1, "扔在旁边")
	eq(you.pack, [])
	var second := b.throw_away(you, "hand", null, 0)
	eq(second.weapon_id, "pistol")
	eq(second.loaded, 8)
	eq(you.hands, ["", "knife"])
	check(second.pos != first.pos, "放在别的空地上")
	var third := b.throw_away(you, "armor")
	eq(third.item.id, "leather")
	eq(you.armor.id, "none")
	var fourth := b.throw_away(you, "pack", Inventory.entries(you)[0])
	eq(fourth.item.kind, "ammo")
	eq(fourth.item.count, 24)
	eq(you.spare, {})
	eq(b.ground.size(), 4)
	eq(b.throw_away(you, "armor"), null, "没穿护甲, 扔不了")
	has_text(b.messages[-1][0], "扔在地上")


func test_ai_only_picks_weapons() -> void:
	var b := battle()
	var foe: Unit = b.units[1]
	foe.hands = ["", ""]
	foe.loaded = [0, 0]
	var ammo := Battle.GroundItem.new(Vector2i(10, 11), Inventory.Item.new("ammo", "pistol", 10))
	b.ground = [ammo]
	b.end_turn()
	eq(b.current(), foe)
	AI.act(b, foe)
	eq(b.ground, [ammo], "敌人不捡子弹")
