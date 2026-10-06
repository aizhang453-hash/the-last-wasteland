class_name TestCase
extends RefCounted
## 测试的底子: 每个测试文件 extends 它, 里面以 test_ 开头的函数就是一条测试。
## 用 check / eq / has_text 检查, 不对就记下来 (测试接着跑完, 最后一起报)。

var failures: Array = []
var current_test := ""


func check(ok: bool, what := "") -> void:
	if not ok:
		failures.append("%s: 不对 %s" % [current_test, what])


func eq(actual: Variant, expected: Variant, what := "") -> void:
	if typeof(actual) != typeof(expected) and not (_is_number(actual) and _is_number(expected)):
		failures.append("%s: 应该是 %s, 实际是 %s (类型不一样) %s" % [current_test, expected, actual, what])
	elif actual != expected:
		failures.append("%s: 应该是 %s, 实际是 %s %s" % [current_test, expected, actual, what])


func has_text(text: String, part: String, what := "") -> void:
	if not text.contains(part):
		failures.append("%s: 「%s」里应该有「%s」 %s" % [current_test, text, part, what])


func _is_number(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


## 掷骰子每次都掷出给定的数 (给完了就掷出最小的那个数); 挑东西用固定的随机数
class FixedDice:
	extends Dice

	var rolls: Array

	func _init(p_rolls: Array = []) -> void:
		super(0)
		rolls = p_rolls.duplicate()

	func roll(a: int, b: int) -> int:
		var value: int = rolls.pop_front() if not rolls.is_empty() else a
		return clampi(value, a, b)


## 造一个人 (测试用): 别的能力值都是 1
static func person(p_name: String, side: String, p: Vector2i, agility := 5, observation := 5, vigor := 5,
		hands := ["pistol", ""], armor := "none", ammo := {}) -> Unit:
	var s := Practice.stats(1, agility, vigor, 1, observation, 1)
	return Unit.new(p_name, side, s, hands, armor, ammo, p)
