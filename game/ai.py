"""
敌人怎么行动 (电脑控制的人)。
每次只做一件事 (走一步、打一下、换子弹……), 画面好一件一件放给玩家看。
测试里也用它来替玩家打。
"""

from . import rules
from .gear import WEAPONS

AIM_AT = 35  # 瞄准某个部位的命中几率到这么多, 才值得瞄


def nearest_foe(battle, unit):
    """离这个人最近的、还活着的对头"""
    foes = [u for u in battle.units if u.alive and u.side != unit.side]
    if not foes:
        return None
    return min(foes, key=lambda u: rules.distance(unit.pos, u.pos))


def act(battle, unit):
    """
    让这个人做一件事。做了返回 True; 没什么能做的了返回 False (该结束回合了)。
    想法很简单:
    - 枪里没子弹: 能换子弹就换
    - 手上没武器、旁边地上有: 捡起来 (离得不远就走过去)
    - 挑一只最好用的手 (见 _best_hand); 不是现在这只就换过去。
      挑法每次都一样, 换过去以后就不会再换回来 (换手不花点数, 来回换会没完没了)
    - 能打就打 (这回合点数只够打一下, 还多出瞄准的 1 点, 就瞄准头或者腿)
      用枪的话, 太难打中而且点数够, 先走近一步
    - 打不着就往对头那边走一步
    """
    if battle.result or unit is not battle.current or not unit.alive:
        return False
    target = nearest_foe(battle, unit)
    if target is None:
        return False

    if unit.weapon.magazine and unit.ammo_in_hand == 0 and battle.reload_problem(unit) is None:
        return battle.reload(unit)

    if unit.hands[unit.active] is None and unit.arms_crippled() < 2:
        item = _nearest_item(battle, unit)
        if item and battle.pickup_problem(unit, item) is None:
            return battle.pickup(unit, item)
        if item and rules.distance(unit.pos, item.pos) <= 3 and battle.free_hand(unit) is not None:
            path = battle.path_within(unit, item.pos, 1)
            if path and battle.move(unit, path[0]):
                return True

    best = _best_hand(battle, unit, target)
    if best != unit.active:
        return battle.switch_hand(unit)
    w = unit.weapon
    if _hand_score(battle, unit, unit.active, target) is None:
        return False  # 两只手都没法用 (比如手雷离得太近、枪没子弹), 这回合算了

    if battle.attack_problem(unit, target) is None:
        d = rules.distance(unit.pos, target.pos)
        far_gun = w.kind not in rules.CLOSE_KINDS
        if (far_gun and battle.hit_chance(unit, target) < 30 and d > 2
                and unit.ap >= unit.step_cost() + w.ap):
            if _step_toward(battle, unit, target):
                return True
        part = _pick_part(battle, unit, target)
        return battle.attack(unit, target, part) is not None

    # 打不着: 往前走一步。用枪、扔手雷的人在够得着的地方只是点数不够 (或者要换子弹), 就不走了 (留着点数当防御)
    if w.kind not in rules.CLOSE_KINDS and rules.distance(unit.pos, target.pos) <= battle.attack_range(unit):
        return False
    if unit.ap >= unit.step_cost():
        return _step_toward(battle, unit, target)
    return False


def _hand_score(battle, unit, hand, target):
    """
    这只手现在好不好用: 不能用返回 None; 拳头 1 分; 拿着能用的武器 3 分
    (枪空了但还有备用子弹也算 3 分: 点数不够换就等下回合换, 不为这个换到别的手上去)。
    两只手都废了就只能踢, 算 1 分。
    """
    if unit.arms_crippled() == 2:
        return 1
    if not unit.hand_ok(hand):
        return None
    wid = unit.hands[hand]
    if wid is None:
        return 1
    w = WEAPONS[wid]
    if w.hands == 2 and unit.arms_crippled():
        return None
    if w.kind == "throw" and rules.distance(unit.pos, target.pos) <= rules.BLAST_RADIUS + 1:
        return None  # 对头离得太近, 扔手雷会连自己一起炸
    if w.magazine and unit.loaded[hand] == 0 and unit.spare.get(wid, 0) == 0:
        return None  # 枪空了, 也没有备用子弹
    return 3


def _best_hand(battle, unit, target):
    """最好用的那只手; 一样好就留在现在这只 (不白换)"""
    best, best_score = unit.active, _hand_score(battle, unit, unit.active, target)
    other = 1 - unit.active
    score = _hand_score(battle, unit, other, target)
    if score is not None and (best_score is None or score > best_score):
        best = other
    return best


def _pick_part(battle, unit, target):
    """点数只够打一下、还多出瞄准的 1 点时, 瞄准头 (能打晕) 或者腿 (能打瘸)"""
    if unit.bursting() or unit.weapon.kind == "throw":
        return None
    cost = unit.weapon.ap
    if not (cost + rules.AIM_AP <= unit.ap < cost * 2):
        return None
    if battle.hit_chance(unit, target, "head") >= AIM_AT:
        return "head"
    legs = [leg for leg in ("right_leg", "left_leg") if leg not in target.crippled]
    if legs:
        leg = battle.rng.choice(legs)
        if battle.hit_chance(unit, target, leg) >= AIM_AT:
            return leg
    return None


def _nearest_item(battle, unit):
    if not battle.ground:
        return None
    return min(battle.ground, key=lambda it: rules.distance(unit.pos, it.pos))


def _step_toward(battle, unit, target):
    path = battle.path_next_to(unit, target)
    if not path:
        return False
    return battle.move(unit, path[0])
