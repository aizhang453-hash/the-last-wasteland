"""
战斗: 地图上的人、轮流行动、走路、攻击 (可以瞄准部位、连发、扔手雷)、换子弹、捡武器。
这里只管规则和数字, 不管画面 (画面在 screen.py), 所以可以单独测试。
"""

import math
import random
from collections import deque
from dataclasses import dataclass, field

from . import gear, rules

PLAYER = "player"
ENEMY = "enemy"

# 8 个方向: 横、竖、斜着都能走, 每步都算 1 格
DIRECTIONS = [(-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1)]

HAND_NAMES = ("右手", "左手")


class Unit:
    """战斗里的一个人 (玩家这边或者敌人)"""

    def __init__(self, name, side, stats, hands, armor="none", ammo=None, pos=(0, 0), short=None):
        self.name = name
        self.short = short or name[:1]  # 画面上排队头像里写的一个字
        self.side = side
        self.stats = dict(stats)
        self.hands = list(hands)  # 两只手拿的武器, 比如 ["pistol", "knife"]; None 是空手
        self.active = 0           # 现在用哪只手: 0 右手, 1 左手
        self.spare = dict(ammo or {})  # 备用子弹, 比如 {"pistol": 24}
        # 每只手的枪里现在有几发 (一开始是满的); 拿的是手雷的话, 是手上有几个手雷
        self.loaded = []
        for w in self.hands:
            weapon = gear.WEAPONS[w] if w else None
            if weapon and weapon.kind == "throw":
                self.loaded.append(self.spare.pop(w, 1))
            else:
                self.loaded.append(weapon.magazine if weapon else 0)
        self.burst = [False, False]  # 每只手上的枪是不是换成了连发 (记在枪上, 换手、捡起别的枪不会带过去)
        self.armor = gear.ARMORS[armor]
        self.max_hp = rules.max_hp(self.stats["vigor"])
        self.hp = self.max_hp
        self.pos = pos
        self.ap = 0        # 这回合还剩几点
        self.leftover = 0  # 上回合没用完的点数 (变成防御, 到自己下回合开始为止)
        # 被暴击打中部位以后的样子 (练习场里没有治疗, 这一局打完才好)
        self.crippled = set()      # 瘸了、废了的手脚, 比如 {"left_leg", "right_arm"}
        self.blind = False         # 眼睛看不见了: 命中 -30
        self.knocked_down = False  # 倒在地上: 下一回合先花 3 点爬起来
        self.knocked_out = False   # 被打晕: 下一回合不能动

    def __repr__(self):
        return f"<{self.name} {self.pos} 生命 {self.hp}/{self.max_hp}>"

    @property
    def alive(self):
        return self.hp > 0

    @property
    def weapon_id(self):
        if self.arms_crippled() == 2:
            return "kick"  # 两只手都废了, 只能踢
        return self.hands[self.active] or "fist"

    def hand_ok(self, hand):
        """这只手还能用吗 (胳膊没废)"""
        return rules.ARM_OF_HAND[hand] not in self.crippled

    def arms_crippled(self):
        return sum(1 for arm in rules.ARM_OF_HAND if arm in self.crippled)

    def legs_crippled(self):
        return sum(1 for leg in ("right_leg", "left_leg") if leg in self.crippled)

    def step_cost(self):
        """走一格花几点 (腿瘸了要多花)"""
        return rules.step_cost(self.legs_crippled())

    def statuses(self):
        """身上的伤 (给画面显示)"""
        words = []
        for key, name, _ in rules.BODY_PARTS:
            if key in self.crippled:
                words.append(f"{name}{'瘸了' if key.endswith('leg') else '废了'}")
        if self.blind:
            words.append("瞎了")
        if self.knocked_out:
            words.append("晕了")
        elif self.knocked_down:
            words.append("倒在地上")
        return words

    @property
    def weapon(self):
        return gear.WEAPONS[self.weapon_id]

    @property
    def ammo_in_hand(self):
        return self.loaded[self.active]

    def defense(self):
        return rules.defense(self.stats["agility"], self.armor.defense, self.leftover)

    def bursting(self):
        """现在是连发吗 (手上的武器能连发, 而且这把枪换成了连发)"""
        return self.burst[self.active] and bool(self.weapon.burst_ap)


@dataclass
class AttackResult:
    attacker: Unit
    target: Unit
    weapon: gear.Weapon
    chance: int   # 命中几率
    hit: bool
    crit: bool
    damage: int
    killed: bool
    shots: int = 1      # 打了几发 (连发最多 10 发)
    hits: int = 0       # 打中目标几发
    part: str = None    # 瞄准的部位 (没瞄准是 None)
    effect: str = None  # 暴击打中部位的效果, 写进战斗记录的话 (比如「持枪强盗的左腿瘸了!」)
    effect_short: str = None  # 同一件事的短说法, 飘在人头上 (比如「左腿瘸了」)
    strays: list = field(default_factory=list)  # 连发歪掉的子弹打中的别人: [(人, 伤害, 倒下没有)]
    paths: list = field(default_factory=list)   # 连发每发子弹飞到哪: [(终点格子坐标, 打中的人或 None)]


@dataclass
class ThrowResult:
    """扔手雷的结果"""
    attacker: Unit
    weapon: gear.Weapon
    aim: tuple       # 往哪一格扔
    landing: tuple   # 落在哪一格 (扔偏了就不是 aim)
    chance: int
    hit: bool
    victims: list    # 炸到的人: [(人, 伤害, 倒下没有)]


@dataclass
class GroundItem:
    """掉在地上的武器"""
    pos: tuple
    weapon_id: str
    loaded: int  # 枪里还有几发


class Battle:
    """
    一场战斗。
    画面要知道发生了什么 (好放动画), 就看 events 列表:
      ("move", 人, 走过的格子) / ("attack", AttackResult) / ("reload", 人) / ("switch", 人)
      ("drop", 人, 地上的东西) / ("pickup", 人, 地上的东西) / ("getup", 人) / ("stunned", 人)
      ("throw", ThrowResult)
    文字框里的话在 log 列表里: (这句话, 种类), 种类是 info / player / enemy / good / bad
    """

    def __init__(self, units, width=14, height=14, rng=None, initiator=None):
        self.width = width
        self.height = height
        self.units = list(units)
        self.rng = rng or random.Random()
        self.log = []
        self.events = []
        self.ground = []    # 掉在地上的武器 (GroundItem)
        self.result = None  # None 还在打; "won" 赢了; "lost" 输了
        self.round = 1
        # 开打时先动手的一方先打第一下, 之后每一轮按反应值排队
        first = initiator or self.units[0]
        self.order = self._base_order()
        self.order.remove(first)
        self.order.insert(0, first)
        self.turn = 0
        self.say("第 1 轮。" + ("你先动手。" if first.side == PLAYER else f"{first.name}先动手!"), "info")
        self._begin_turn()

    # ---------- 轮流 ----------

    def _base_order(self):
        """反应值高的先动; 一样高比灵巧; 还一样就玩家这边先动"""
        side_rank = {PLAYER: 0, ENEMY: 1}
        alive = [u for u in self.units if u.alive]
        return sorted(alive, key=lambda u: (-rules.reaction(u.stats["observation"]),
                                            -u.stats["agility"], side_rank[u.side]))

    @property
    def current(self):
        return self.order[self.turn]

    def _begin_turn(self):
        u = self.current
        u.ap = rules.action_points(u.stats["agility"])
        u.leftover = 0  # 上回合留下的防御, 到自己回合开始就没了
        if u.knocked_down:
            u.knocked_down = False
            u.ap = max(0, u.ap - rules.GET_UP_AP)
            self.events.append(("getup", u))
            self.say(f"{u.name}爬了起来 (花 {rules.GET_UP_AP} 点)。", self._kind(u))

    def end_turn(self):
        """结束现在这个人的回合: 没用完的点数变成防御, 轮到下一个还活着的人"""
        if self.result:
            return
        u = self.current
        u.leftover = u.ap
        u.ap = 0
        while True:
            self.turn += 1
            if self.turn >= len(self.order):
                self.round += 1
                self.order = self._base_order()
                self.turn = 0
                self.say(f"第 {self.round} 轮。", "info")
            nxt = self.current
            if not nxt.alive:
                continue
            if nxt.knocked_out:  # 晕着: 这回合跳过, 也没有防御加成
                nxt.knocked_out = False
                nxt.leftover = 0
                self.events.append(("stunned", nxt))
                self.say(f"{nxt.name}晕着, 这回合动不了。", self._kind(nxt))
                continue
            break
        self._begin_turn()

    def _not_your_turn(self, unit):
        """不能行动的原因 (打完了、没轮到、已经倒下了); 能行动返回 None"""
        if self.result or unit is not self.current:
            return "还没轮到"
        if not unit.alive:
            return "已经倒下了"
        return None

    def has_acted(self, unit):
        """这一轮已经轮过了吗 (给排队头像用)"""
        return unit in self.order and self.order.index(unit) < self.turn

    # ---------- 地图和走路 ----------

    def in_bounds(self, pos):
        return 0 <= pos[0] < self.width and 0 <= pos[1] < self.height

    def unit_at(self, pos):
        """这格上站着的活人 (倒下的人可以踩过去)"""
        for u in self.units:
            if u.alive and u.pos == pos:
                return u
        return None

    def _search(self, unit, is_goal, toward):
        """
        从这个人脚下出发找路 (一格一格往外找, 找到的就是最短的路)。
        is_goal(格子) 说哪些格子算到了; toward 是大概往哪儿走,
        一样短的路里先试离它近的方向, 走出来的路比较直。
        返回走过的格子 (不含起点); 找不到返回 None。
        """
        start = unit.pos
        if is_goal(start):
            return []
        came_from = {start: None}
        queue = deque([start])
        while queue:
            here = queue.popleft()
            nexts = [(here[0] + dx, here[1] + dy) for dx, dy in DIRECTIONS]
            nexts.sort(key=lambda p: (p[0] - toward[0]) ** 2 + (p[1] - toward[1]) ** 2)
            for nxt in nexts:
                if nxt in came_from or not self.in_bounds(nxt) or self.unit_at(nxt):
                    continue
                came_from[nxt] = here
                if is_goal(nxt):
                    path = [nxt]
                    while came_from[path[-1]] != start:
                        path.append(came_from[path[-1]])
                    return path[::-1]
                queue.append(nxt)
        return None

    def find_path(self, unit, dest):
        """走到 dest 的路; 走不到 (有人站着、出了地图) 返回 None"""
        if not self.in_bounds(dest) or self.unit_at(dest):
            return None
        return self._search(unit, lambda p: p == dest, dest)

    def path_within(self, unit, pos, dist):
        """走到离 pos 不超过 dist 格的最短路 (已经够近了返回 [])"""
        return self._search(unit, lambda p: rules.distance(p, pos) <= dist, pos)

    def path_next_to(self, unit, target):
        """走到 target 旁边 (挨着, 斜着也算) 的最短路"""
        return self.path_within(unit, target.pos, 1)

    def move_cost(self, unit, path):
        """走这条路要花几点"""
        return len(path) * unit.step_cost()

    def reachable(self, unit):
        """这回合还能走到的格子: {格子: 要几步}"""
        result = {}
        steps = {unit.pos: 0}
        queue = deque([unit.pos])
        max_steps = unit.ap // unit.step_cost()
        while queue:
            here = queue.popleft()
            if steps[here] >= max_steps:
                continue
            for dx, dy in DIRECTIONS:
                nxt = (here[0] + dx, here[1] + dy)
                if nxt in steps or not self.in_bounds(nxt) or self.unit_at(nxt):
                    continue
                steps[nxt] = steps[here] + 1
                result[nxt] = steps[nxt]
                queue.append(nxt)
        return result

    def move(self, unit, dest):
        """沿最短路走到 dest, 一格花 1 点 (腿瘸了多花)。走不到或者点数不够, 返回 False, 什么都不变"""
        if self._not_your_turn(unit):
            return False
        path = self.find_path(unit, dest)
        if not path or self.move_cost(unit, path) > unit.ap:
            return False
        unit.ap -= self.move_cost(unit, path)
        start = unit.pos
        unit.pos = dest
        self.events.append(("move", unit, [start] + path))
        return True

    # ---------- 攻击 ----------

    def attack_cost(self, unit, part=None):
        """打一下花几点 (瞄准部位多花 1 点; 连发看武器)"""
        if unit.bursting():
            return unit.weapon.burst_ap
        return unit.weapon.ap + (rules.AIM_AP if part else 0)

    def attack_range(self, unit):
        """能打多远 (格)"""
        w = unit.weapon
        if w.kind in rules.CLOSE_KINDS:
            return 1
        if w.kind == "throw":
            return rules.throw_range(unit.stats["vigor"])
        return w.range

    def attack_problem(self, unit, target, part=None):
        """能打就返回 None; 打不了返回原因 (给画面显示)"""
        if self._not_your_turn(unit):
            return self._not_your_turn(unit)
        if not target.alive or target.side == unit.side:
            return "不能打这个人"
        w = unit.weapon
        if unit.arms_crippled() < 2:
            if not unit.hand_ok(unit.active):
                return f"{HAND_NAMES[unit.active]}废了, 先换手"
            if w.hands == 2 and unit.arms_crippled():
                return f"{w.name}要两只手都好才能用"
        if part and unit.bursting():
            return "连发不能瞄准"
        if part and w.kind == "throw":
            return "手雷不能瞄准"
        d = rules.distance(unit.pos, target.pos)
        if w.kind in rules.CLOSE_KINDS:
            if d > 1:
                return "要走到旁边才能打"
        elif d > self.attack_range(unit):
            far = "扔" if w.kind == "throw" else "射程"
            return f"太远了 ({w.name}{far} {self.attack_range(unit)} 格)"
        if w.magazine and unit.ammo_in_hand == 0:
            return "没子弹了, 先换子弹"
        cost = self.attack_cost(unit, part)
        if unit.ap < cost:
            return f"行动点不够 (要 {cost} 点)"
        return None

    def hit_chance(self, unit, target, part=None):
        # 手雷是往那一格扔, 不看人躲不躲得开, 所以不减防御
        defense = 0 if unit.weapon.kind == "throw" else target.defense()
        return rules.hit_chance(unit.stats, unit.weapon, defense,
                                rules.distance(unit.pos, target.pos),
                                aim_penalty=rules.PART_PENALTY[part] if part else 0, blind=unit.blind)

    def crit_chance(self, unit, part=None):
        return rules.crit_chance(unit.stats["observation"], rules.aim_crit_bonus(part))

    def attack(self, unit, target, part=None):
        """
        打一下 (part 是瞄准的部位, 不瞄准就是 None)。打不了返回 None。
        打了返回 AttackResult; 连发也是一个 AttackResult (shots、hits 说打了几发中了几发);
        扔手雷返回 ThrowResult。
        """
        if self.attack_problem(unit, target, part):
            return None
        w = unit.weapon
        if w.kind == "throw":
            return self._throw(unit, target.pos)
        if unit.bursting():
            return self._burst(unit, target)
        unit.ap -= self.attack_cost(unit, part)
        if w.magazine:
            unit.loaded[unit.active] -= 1
        chance = self.hit_chance(unit, target, part)
        hit = self.rng.randint(1, 100) <= chance
        crit = False
        damage = 0
        if hit:
            # 打中了再掷一次, 看暴没暴击
            crit = self.rng.randint(1, 100) <= self.crit_chance(unit, part)
            raw = self.rng.randint(w.dmg_min, w.dmg_max)
            if w.kind in rules.CLOSE_KINDS:
                raw += rules.melee_bonus(unit.stats["vigor"])
            damage = rules.damage_after_armor(raw, crit, target.armor)
            target.hp = max(0, target.hp - damage)
        result = AttackResult(unit, target, w, chance, hit, crit, damage, not target.alive,
                              hits=int(hit), part=part)

        where = f"{target.name}的{rules.PART_NAMES[part]}" if part else target.name
        text = f"{unit.name}用{w.name}打{where} (命中 {chance}%)……"
        if not hit:
            text += "没打中。"
        elif crit:
            text += f"暴击! {damage} 点伤害!"
        elif damage == 0:
            text += "打中了, 可是没打穿护甲。"
        else:
            text += f"打中了, {damage} 点伤害。"
        self.say(text, self._kind(unit))
        if result.killed:
            self.events.append(("attack", result))
            self.say(f"{target.name}倒下了。", self._victim_kind(target))
            self._check_end()
            return result
        # 暴击打中瞄准的部位: 特殊效果
        dropped = None
        if crit and part:
            result.effect, result.effect_short, dropped = self._crit_effect(target, part)
        self.events.append(("attack", result))
        if dropped:
            self.events.append(("drop", target, dropped))
        if result.effect:
            self.say(result.effect, self._victim_kind(target))
        return result

    def _crit_effect(self, target, part):
        """暴击打中部位以后发生什么。返回 (战斗记录里的话, 飘在头上的短说法, 掉在地上的东西)"""
        name = target.name
        part_name = rules.PART_NAMES[part]
        if part.endswith("leg"):
            if part in target.crippled:
                return None, None, None
            target.crippled.add(part)
            return f"{name}的{part_name}瘸了!", f"{part_name}瘸了", None
        if part.endswith("arm"):
            if part in target.crippled:
                return None, None, None
            target.crippled.add(part)
            item = self._drop(target, rules.ARM_OF_HAND.index(part))
            if item:
                weapon = gear.WEAPONS[item.weapon_id].name
                return f"{name}的{part_name}废了, {weapon}掉在地上!", f"{part_name}废了", item
            return f"{name}的{part_name}废了!", f"{part_name}废了", None
        if part == "groin":
            target.knocked_down = True
            return f"{name}疼得倒在地上!", "倒地", None
        if part == "head":
            target.knocked_out = True
            return f"{name}被打晕了!", "打晕了", None
        if part == "eyes":
            if target.blind:
                return None, None, None
            target.blind = True
            return f"{name}的眼睛看不见了!", "瞎了", None
        return None, None, None  # 身上: 只是伤害翻倍

    def _drop(self, unit, hand):
        """这只手上的武器掉到旁边的空地上 (没空地就掉在脚下)"""
        wid = unit.hands[hand]
        if not wid:
            return None
        spots = [(unit.pos[0] + dx, unit.pos[1] + dy) for dx, dy in DIRECTIONS]
        spots = [p for p in spots if self.in_bounds(p) and not self.unit_at(p) and not self.item_at(p)]
        pos = self.rng.choice(spots) if spots else unit.pos
        item = GroundItem(pos, wid, unit.loaded[hand])
        unit.hands[hand] = None
        unit.loaded[hand] = 0
        unit.burst[hand] = False
        self.ground.append(item)
        return item

    def _burst(self, unit, target):
        """
        连发 (照原版): 一次打 10 发 (枪里不够就有几发打几发)。
        三分之一 (往上取整, 10 发就是 4 发) 对准目标飞, 剩下的往左右两边各歪 10 度飞。
        每发子弹沿着自己那条线飞, 路上碰到的每个人按先后各算一次中不中, 打中谁就停在谁身上
        (敌人、同伴、挡在中间的人都可能)。离得近, 歪的子弹也常常落在目标身上; 离得远就散开了。
        暴击只算打中目标的那几发。
        """
        w = unit.weapon
        shots = min(rules.BURST_ROUNDS, unit.ammo_in_hand)
        unit.ap -= w.burst_ap
        unit.loaded[unit.active] -= shots
        chance = self.hit_chance(unit, target)
        crit_chance = self.crit_chance(unit)
        aim = math.atan2(target.pos[1] - unit.pos[1], target.pos[0] - unit.pos[0])
        spread = math.radians(rules.BURST_SPREAD)
        center, side_a, side_b = rules.burst_split(shots)
        angles = [aim] * center + [aim + spread] * side_a + [aim - spread] * side_b
        hits = crits = damage = 0
        strays = {}   # 别人被打中: {人: 伤害}
        paths = []
        for angle in angles:
            people, end = self._trace(unit, angle, w.range)
            hit_who = None
            for person in people:
                p_chance = chance if person is target else self.hit_chance(unit, person)
                if self.rng.randint(1, 100) > p_chance:
                    continue
                crit = person is target and self.rng.randint(1, 100) <= crit_chance
                dealt = rules.damage_after_armor(self.rng.randint(w.dmg_min, w.dmg_max), crit, person.armor)
                person.hp = max(0, person.hp - dealt)
                if person is target:
                    hits += 1
                    crits += crit
                    damage += dealt
                else:
                    strays[person] = strays.get(person, 0) + dealt
                hit_who = person
                break
            paths.append((hit_who.pos if hit_who else end, hit_who))
        result = AttackResult(unit, target, w, chance, hits > 0, crits > 0, damage, not target.alive,
                              shots=shots, hits=hits,
                              strays=[(u, d, not u.alive) for u, d in strays.items()], paths=paths)
        self.events.append(("attack", result))
        text = f"{unit.name}用{w.name}连发打{target.name} (每发命中 {chance}%)……"
        if hits == 0:
            text += f"{shots} 发都没打中他。"
        else:
            text += f"{shots} 发里打中他 {hits} 发" + (f", 有 {crits} 发暴击" if crits else "") + f", 一共 {damage} 点伤害。"
        self.say(text, self._kind(unit))
        if result.killed:
            self.say(f"{target.name}倒下了。", self._victim_kind(target))
        for u, dealt, killed in result.strays:
            self.say(f"有子弹打中了{u.name}, {dealt} 点伤害。", self._victim_kind(u))
            if killed:
                self.say(f"{u.name}倒下了。", self._victim_kind(u))
        if result.killed or any(killed for _, _, killed in result.strays):
            self._check_end()
        return result

    def _trace(self, unit, angle, max_range):
        """
        从这个人这里往 angle 方向画一条线, 一直到射程或者地图边上。
        返回 (线上碰到的活人, 按先后; 线的终点 (格子坐标, 可以是小数))
        """
        sx, sy = unit.pos
        dx, dy = math.cos(angle), math.sin(angle)
        people = []
        end = unit.pos
        t = 0.5
        while True:
            px, py = sx + dx * t, sy + dy * t
            tile = (math.floor(px + 0.5), math.floor(py + 0.5))
            if not self.in_bounds(tile) or rules.distance(unit.pos, tile) > max_range:
                break
            end = (px, py)
            u = self.unit_at(tile)
            if u is not None and u is not unit and u not in people:
                people.append(u)
            t += 0.25
        return people, end

    def _throw(self, unit, aim):
        """
        扔手雷: 扔准了落在瞄的那一格, 扔偏了落在旁边 1～2 格。
        落点周围 3×3 里的人都被炸到 (包括自己和同伴), 每个人分开算伤害, 再过护甲。
        """
        w = unit.weapon
        unit.ap -= w.ap
        unit.loaded[unit.active] -= 1
        if unit.loaded[unit.active] <= 0:
            unit.hands[unit.active] = None  # 手雷扔完了, 手空了
            unit.loaded[unit.active] = 0
        chance = rules.hit_chance(unit.stats, w, 0, rules.distance(unit.pos, aim), blind=unit.blind)  # 不减防御
        hit = self.rng.randint(1, 100) <= chance
        landing = aim
        if not hit:
            spots = [(aim[0] + dx, aim[1] + dy) for dx in range(-2, 3) for dy in range(-2, 3)
                     if (dx, dy) != (0, 0)]
            spots = [p for p in spots if self.in_bounds(p)]
            landing = self.rng.choice(spots) if spots else aim
        victims = []
        for u in self.units:
            if u.alive and rules.distance(u.pos, landing) <= rules.BLAST_RADIUS:
                dealt = rules.damage_after_armor(self.rng.randint(w.dmg_min, w.dmg_max), False, u.armor)
                u.hp = max(0, u.hp - dealt)
                victims.append((u, dealt, not u.alive))
        result = ThrowResult(unit, w, aim, landing, chance, hit, victims)
        self.events.append(("throw", result))
        self.say(f"{unit.name}扔出手雷 (命中 {chance}%)……" + ("扔准了!" if hit else "扔偏了!"), self._kind(unit))
        if not victims:
            self.say("手雷炸了, 没炸到人。", "info")
        for u, dealt, killed in victims:
            self.say(f"{u.name}被炸到, {dealt} 点伤害。", self._victim_kind(u))
            if killed:
                self.say(f"{u.name}倒下了。", self._victim_kind(u))
        self._check_end()
        if not self.result and not unit.alive:
            self.end_turn()  # 把自己炸倒了, 剩下的点数也用不了了
        return result

    def toggle_burst(self, unit):
        """冲锋枪换成连发 / 单发, 不花点数"""
        if self._not_your_turn(unit) or not unit.weapon.burst_ap:
            return False
        unit.burst[unit.active] = not unit.burst[unit.active]
        mode = "连发" if unit.burst[unit.active] else "单发"
        self.say(f"{unit.name}的{unit.weapon.name}换成{mode}。", self._kind(unit))
        return True

    def _check_end(self):
        # 两边同时倒下 (比如手雷连自己一起炸了) 算输
        if not any(u.alive for u in self.units if u.side == PLAYER):
            self.result = "lost"
            self.say("这一局输了。", "bad")
        elif not any(u.alive for u in self.units if u.side == ENEMY):
            self.result = "won"
            self.say("敌人全倒下了, 你赢了!", "good")

    # ---------- 换子弹、换手 ----------

    def reload_problem(self, unit):
        if self._not_your_turn(unit):
            return self._not_your_turn(unit)
        if unit.arms_crippled() and unit.weapon_id != "kick" and not unit.hand_ok(unit.active):
            return f"{HAND_NAMES[unit.active]}废了"
        w = unit.weapon
        if not w.magazine:
            return f"{w.name}不用子弹"
        if unit.ammo_in_hand >= w.magazine:
            return "子弹是满的"
        if unit.spare.get(unit.weapon_id, 0) <= 0:
            return "没有备用子弹了"
        if unit.ap < rules.RELOAD_AP:
            return f"行动点不够 (要 {rules.RELOAD_AP} 点)"
        return None

    def reload(self, unit):
        """把手上的枪装满 (用备用子弹), 花 2 点"""
        if self.reload_problem(unit):
            return False
        w = unit.weapon
        n = min(w.magazine - unit.ammo_in_hand, unit.spare[unit.weapon_id])
        unit.loaded[unit.active] += n
        unit.spare[unit.weapon_id] -= n
        unit.ap -= rules.RELOAD_AP
        self.events.append(("reload", unit))
        self.say(f"{unit.name}换了子弹 ({w.name} {unit.ammo_in_hand}/{w.magazine})。", self._kind(unit))
        return True

    def switch_hand(self, unit):
        """换用另一只手的武器, 不花点数"""
        if self._not_your_turn(unit):
            return False
        unit.active = 1 - unit.active
        self.events.append(("switch", unit))
        self.say(f"{unit.name}换成{HAND_NAMES[unit.active]}的{unit.weapon.name}。", self._kind(unit))
        return True

    # ---------- 地上的武器 ----------

    def item_at(self, pos):
        for item in self.ground:
            if item.pos == pos:
                return item
        return None

    def free_hand(self, unit):
        """能拿东西的空手: 先看现在用的这只, 再看另一只; 没有返回 None"""
        for hand in (unit.active, 1 - unit.active):
            if unit.hands[hand] is None and unit.hand_ok(hand):
                return hand
        return None

    def pickup_problem(self, unit, item):
        if self._not_your_turn(unit):
            return self._not_your_turn(unit)
        if rules.distance(unit.pos, item.pos) > 1:
            return "要走到旁边才能捡"
        if unit.arms_crippled() == 2:
            return "两只手都废了, 捡不了"
        if self.free_hand(unit) is None:
            return "两只手都拿着东西"
        w = gear.WEAPONS[item.weapon_id]
        if w.hands == 2 and unit.arms_crippled():
            return f"{w.name}要两只手都好才能用"
        if unit.ap < rules.PICKUP_AP:
            return f"行动点不够 (要 {rules.PICKUP_AP} 点)"
        return None

    def pickup(self, unit, item):
        """捡起地上的武器 (站在旁边就能捡), 花 2 点, 拿在空着的手上并换成用它"""
        if self.pickup_problem(unit, item):
            return False
        hand = self.free_hand(unit)
        unit.hands[hand] = item.weapon_id
        unit.loaded[hand] = item.loaded
        unit.burst[hand] = False  # 捡起来的枪先是单发
        unit.active = hand
        unit.ap -= rules.PICKUP_AP
        self.ground.remove(item)
        self.events.append(("pickup", unit, item))
        self.say(f"{unit.name}捡起了{gear.WEAPONS[item.weapon_id].name}。", self._kind(unit))
        return True

    # ---------- 其他 ----------

    @staticmethod
    def _kind(unit):
        """这个人做的事, 在战斗记录里用什么颜色"""
        return "player" if unit.side == PLAYER else "enemy"

    @staticmethod
    def _victim_kind(unit):
        """这个人挨打、倒下: 是你这边的就是坏消息, 是敌人就是好消息"""
        return "bad" if unit.side == PLAYER else "good"

    def say(self, text, kind="info"):
        self.log.append((text, kind))

    def take_events(self):
        """画面拿走新发生的事 (拿走以后就清空)"""
        events, self.events = self.events, []
        return events
