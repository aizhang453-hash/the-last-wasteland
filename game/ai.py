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
    - 拿武器的手废了: 换另一只手
    - 手上没武器、旁边地上有: 捡起来 (离得不远就走过去)
    - 枪里没子弹: 换子弹; 换不了就换另一只手
    - 能打就打 (这回合点数只够打一下, 还多出瞄准的 1 点, 就瞄准头或者腿)
      用枪的话, 太难打中而且点数够, 先走近一步
    - 打不着就往对头那边走一步
    """
    if battle.result or unit is not battle.current:
        return False
    target = nearest_foe(battle, unit)
    if target is None:
        return False
    w = unit.weapon

    if unit.arms_crippled() == 1 and not unit.hand_ok(unit.active):
        return battle.switch_hand(unit)

    if unit.hands[unit.active] is None and unit.arms_crippled() < 2:
        item = _nearest_item(battle, unit)
        if item and battle.pickup_problem(unit, item) is None:
            return battle.pickup(unit, item)
        if item and rules.distance(unit.pos, item.pos) <= 3 and battle.free_hand(unit) is not None:
            path = battle._search(unit, lambda p: rules.distance(p, item.pos) <= 1, item.pos)
            if path and battle.move(unit, path[0]):
                return True
        other = 1 - unit.active
        if unit.hands[other] and unit.hand_ok(other) and _usable(unit, other):
            return battle.switch_hand(unit)

    if w.magazine and unit.ammo_in_hand == 0:
        if battle.reload_problem(unit) is None:
            return battle.reload(unit)
        if unit.spare.get(unit.weapon_id, 0) == 0 and unit.hand_ok(1 - unit.active) and _usable(unit, 1 - unit.active):
            return battle.switch_hand(unit)
        if unit.spare.get(unit.weapon_id, 0) > 0:
            return False  # 有子弹, 只是点数不够换, 下回合再换

    # 手雷: 对头离自己太近 (会连自己一起炸), 有别的武器就换手, 没有就先不扔
    if w.kind == "throw" and rules.distance(unit.pos, target.pos) <= rules.BLAST_RADIUS + 1:
        other = 1 - unit.active
        if unit.hand_ok(other) and _usable(unit, other) and unit.hands[other] != unit.hands[unit.active]:
            return battle.switch_hand(unit)
        return False

    if battle.attack_problem(unit, target) is None:
        d = rules.distance(unit.pos, target.pos)
        far_gun = w.kind not in rules.CLOSE_KINDS
        if (far_gun and battle.hit_chance(unit, target) < 30 and d > 2
                and unit.ap >= unit.step_cost() + w.ap):
            if _step_toward(battle, unit, target):
                return True
        part = _pick_part(battle, unit, target)
        return battle.attack(unit, target, part) is not None

    # 打不着: 往前走一步。用枪的人在射程里只是点数不够, 就不走了 (留着点数当防御)
    if w.kind not in rules.CLOSE_KINDS and rules.distance(unit.pos, target.pos) <= w.range:
        return False
    if unit.ap >= unit.step_cost():
        return _step_toward(battle, unit, target)
    return False


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


def _usable(unit, hand):
    """那只手的东西能不能用 (空手也算能用: 用拳头)"""
    weapon_id = unit.hands[hand]
    if weapon_id is None or not WEAPONS[weapon_id].magazine:
        return True
    return unit.loaded[hand] > 0 or unit.spare.get(weapon_id, 0) > 0


def _step_toward(battle, unit, target):
    path = battle.path_next_to(unit, target)
    if not path:
        return False
    return battle.move(unit, path[0])
