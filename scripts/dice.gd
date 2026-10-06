class_name Dice
extends RefCounted
## 掷骰子。战斗里所有随机的事都从这里来, 测试时可以换成「每次掷出给定的数」。

var rng := RandomNumberGenerator.new()


func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()


## 掷一个 a 到 b 之间的整数 (包括 a 和 b)
func roll(a: int, b: int) -> int:
	return rng.randi_range(a, b)


## 从一堆里随便挑一个
func pick(items: Array) -> Variant:
	return items[rng.randi_range(0, items.size() - 1)]
