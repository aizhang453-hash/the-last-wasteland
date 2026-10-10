extends TestCase
## 跟人说话的规则: 读对话文件、回答的条件、走到一段时发生的事、说到哪了、写错了能不能查出来。

const SAMPLE := """
# 注释不管
人物: 老王
头像: 路人

== 开头
你好。
第二行。
* 你是谁? -> 介绍
* [学识 6] 聪明的问题 -> 介绍
* [学识 3以下] 笨的问题 -> 介绍
* [意志 5] [不记得 拿过钱] 给钱 -> 给钱
* [钱 10] 我有钱 -> 结束
* 打一架 -> 开打
* 走了 -> 结束

== 介绍
我是老王。
* 回去 -> 开头

== 给钱
> 钱 +20
> 记住 拿过钱
拿着。
* 谢了 -> 开头
"""


static func stats(intellect := 5, resolve := 5) -> Dictionary:
	return Practice.stats(3, 5, 5, intellect, 5, resolve)


static func texts(options: Array) -> Array:
	return options.map(func(o: Dialogue.Option) -> String: return o.text)


func test_parse() -> void:
	var d := Dialogue.parse(SAMPLE)
	eq(d.problems, [])
	eq(d.who, "老王")
	eq(d.face, "路人")
	eq(d.first, "开头")
	eq(d.parts.size(), 3)
	var start: Dialogue.Part = d.parts["开头"]
	eq(start.text, "你好。\n第二行。", "分几行写的话, 显示时也分行")
	eq(start.options.size(), 7)
	var smart: Dialogue.Option = start.options[1]
	eq(smart.text, "聪明的问题")
	eq(smart.target, "介绍")
	eq(smart.tag, "学识 6", "几分以上的能力值条件写在前面")
	eq(start.options[2].tag, "", "几分以下的不写")
	eq(start.options[3].conditions.size(), 2)
	eq(start.options[3].tag, "意志 5")
	eq(start.options[4].tag, "", "钱的条件不写")
	eq(d.parts["给钱"].effects, [["钱", 20], ["记住", "拿过钱"]])


func test_options_depend_on_stats() -> void:
	var d := Dialogue.parse(SAMPLE)
	var dumb := Dialogue.Talk.new(d, stats(2, 3))
	eq(texts(dumb.options()), ["你是谁?", "笨的问题", "打一架", "走了"])
	var smart := Dialogue.Talk.new(d, stats(7, 5))
	eq(texts(smart.options()), ["你是谁?", "聪明的问题", "给钱", "打一架", "走了"])
	var middle := Dialogue.Talk.new(d, stats(4, 4))
	eq(texts(middle.options()), ["你是谁?", "打一架", "走了"], "学识 4: 不聪明也不笨")


func test_stats_change_shows_up_right_away() -> void:
	var s := stats(5, 5)
	var talk := Dialogue.Talk.new(Dialogue.parse(SAMPLE), s)
	check(not texts(talk.options()).has("聪明的问题"))
	s["intellect"] = 6
	check(texts(talk.options()).has("聪明的问题"), "能力值是同一份, 改了马上算")


func test_money_and_flags() -> void:
	var memory := Dialogue.Memory.new()
	var talk := Dialogue.Talk.new(Dialogue.parse(SAMPLE), stats(5, 5), memory)
	eq(memory.money, 0)
	check(talk.choose(texts(talk.options()).find("给钱")))
	eq(talk.part.name, "给钱")
	eq(memory.money, 20)
	check(memory.flags.has("拿过钱"))
	talk.choose(0)
	eq(talk.part.name, "开头")
	var now := texts(talk.options())
	check(not now.has("给钱"), "拿过了, 不能再要")
	check(now.has("我有钱"), "钱有 20 了")
	eq(memory.money, 20, "回到开头不会再给")


func test_memory_stays_for_next_talk() -> void:
	var memory := Dialogue.Memory.new()
	var d := Dialogue.parse(SAMPLE)
	var first := Dialogue.Talk.new(d, stats(5, 5), memory)
	first.choose(texts(first.options()).find("给钱"))
	var second := Dialogue.Talk.new(d, stats(5, 5), memory)
	eq(memory.money, 20)
	check(not texts(second.options()).has("给钱"), "下次再说话还记得")


func test_endings() -> void:
	var d := Dialogue.parse(SAMPLE)
	var talk := Dialogue.Talk.new(d, stats(5, 3))
	var opts := texts(talk.options())
	check(talk.choose(opts.find("走了")))
	eq(talk.ended, Dialogue.END)
	eq(talk.options(), [])
	check(not talk.choose(0), "说完了不能再选")
	var fight := Dialogue.Talk.new(d, stats(5, 3))
	fight.choose(texts(fight.options()).find("打一架"))
	eq(fight.ended, Dialogue.FIGHT)
	check(not fight.choose(99))


func test_history() -> void:
	var talk := Dialogue.Talk.new(Dialogue.parse(SAMPLE), stats(5, 3))
	eq(talk.history, [["npc", "你好。\n第二行。"]])
	talk.choose(0)
	eq(talk.history, [["npc", "你好。\n第二行。"], ["you", "你是谁?"], ["npc", "我是老王。"]])


func test_part_without_options_says_goodbye() -> void:
	var d := Dialogue.parse("== 开头\n再见。\n* [学识 10] 只有聪明人能说 -> 结束\n")
	eq(d.problems, [])
	var talk := Dialogue.Talk.new(d, stats(5, 5))
	eq(texts(talk.options()), ["(结束对话)"], "一个能选的都没有, 给一个结束对话, 免得卡住")
	talk.choose(0)
	eq(talk.ended, Dialogue.END)


func test_money_never_negative() -> void:
	var memory := Dialogue.Memory.new()
	memory.money = 10
	Dialogue.Talk.new(Dialogue.parse("== 开头\n> 钱 -50\n给我钱。\n* 好 -> 结束\n"), stats(), memory)
	eq(memory.money, 0)


func test_forget() -> void:
	var memory := Dialogue.Memory.new()
	memory.flags["欠钱"] = true
	Dialogue.Talk.new(Dialogue.parse("== 开头\n> 忘掉 欠钱\n算了。\n* 好 -> 结束\n"), stats(), memory)
	check(not memory.flags.has("欠钱"))


func test_full_width_symbols() -> void:
	var d := Dialogue.parse("人物：老王\n＝＝ 开头 ＝＝\n你好：外乡人【不是我】。\n＞ 钱 ＋5\n＊ 【学识 6】 问 → 结束\n＊ 走 -> 结束\n")
	eq(d.who, "老王")
	eq(d.parts.keys(), ["开头"])
	eq(d.parts["开头"].text, "你好：外乡人【不是我】。", "对方说的话里的符号不动")
	eq(d.parts["开头"].options[0].tag, "学识 6")
	eq(d.parts["开头"].options[0].target, "结束")


func test_conditions_other_spellings() -> void:
	var d := Dialogue.parse("== 开头\n嗯。\n* [洞察>=7] 甲 -> 结束\n* [洞察 ≤ 2] 乙 -> 结束\n* [体魄 4以上] 丙 -> 结束\n")
	eq(d.problems, [])
	var o: Array = d.parts["开头"].options
	eq(o[0].conditions, [{"stat": "observation", "value": 7, "most": false}])
	eq(o[1].conditions, [{"stat": "observation", "value": 2, "most": true}])
	eq(o[2].conditions, [{"stat": "vigor", "value": 4, "most": false}])


## 写错的地方都要查出来, 说清楚第几行
func test_problems() -> void:
	var cases := [
		["", "一段都没有"],
		["你好\n== 开头\n嗯\n", "第 1 行: 先写「== 段名」"],
		["== 开头\n嗯\n* 去 -> 不存在\n", "第 3 行: 找不到叫「不存在」的一段"],
		["== 开头\n嗯\n* 去哪\n", "第 3 行: 选项后面要写「-> 下一段的名字」"],
		["== 开头\n嗯\n* [魅力 6] 去 -> 结束\n", "第 3 行: 没有「魅力」这个能力值"],
		["== 开头\n嗯\n* [学识 很高] 去 -> 结束\n", "第 3 行: 看不懂的条件「学识 很高」"],
		["== 开头\n嗯\n* [学识 6 去 -> 结束\n", "第 3 行: 方括号没有关上"],
		["== 开头\n嗯\n* -> 结束\n", "第 3 行: 这个选项没有字"],
		["== 开头\n嗯\n* 去 -> \n", "第 3 行: 箭头后面要写下一段的名字"],
		["== 开头\n> 给他一把枪\n嗯\n", "第 2 行: 看不懂的「给他一把枪」"],
		["== 开头\n嗯\n== 开头\n啊\n", "第 3 行: 已经有一段叫「开头」了 (第 1 行)"],
		["== 结束\n嗯\n", "第 1 行: 「结束」是留着用的"],
		["== 开头\n* 去 -> 结束\n", "第 1 行: 「开头」这一段对方什么都没说"],
		["== \n嗯\n", "第 1 行: 「==」后面要写这一段的名字"],
		["== 开头\n嗯\n* [记得] 去 -> 结束\n", "第 3 行: 「记得」后面要写记的是什么事"],
	]
	for c in cases:
		var d := Dialogue.parse(c[0])
		check(not d.problems.is_empty(), "应该查出错: %s" % c[1])
		if not d.problems.is_empty():
			has_text(d.problems[0], c[1])


func test_missing_file() -> void:
	var d := Dialogue.load_file("res://dialogues/没有这个文件.txt")
	has_text(d.problems[0], "打不开")
	var talk := Dialogue.Talk.new(d, stats())
	eq(talk.ended, Dialogue.END, "一段都没有, 直接结束, 不会出错")


## dialogues/ 里的每个对话文件: 没写错、头像找得到、每一段都走得到、走进去都走得出来
func test_shipped_dialogues() -> void:
	var files := Array(DirAccess.get_files_at("res://dialogues")).filter(func(f: String) -> bool: return f.ends_with(".txt"))
	check(files.has("trainer.txt"))
	for file in files:
		var d := Dialogue.load_file("res://dialogues/" + file)
		eq(d.problems, [], file)
		check(Portrait.LOOKS.has(d.face), "%s 的头像「%s」找不到" % [file, d.face])
		var reach := {d.first: true}
		var todo := [d.first]
		while not todo.is_empty():
			var part: Dialogue.Part = d.parts[todo.pop_back()]
			for o in part.options:
				if d.parts.has(o.target) and not reach.has(o.target):
					reach[o.target] = true
					todo.append(o.target)
		for name in d.parts:
			check(reach.has(name), "%s: 「%s」这一段走不到" % [file, name])
			check(_can_end(d, name), "%s: 走进「%s」就出不来了" % [file, name])


func _can_end(d: Dialogue, start: String) -> bool:
	var seen := {start: true}
	var todo := [start]
	while not todo.is_empty():
		var part: Dialogue.Part = d.parts[todo.pop_back()]
		if part.options.is_empty():
			return true  # 一个回答都没有会给「结束对话」
		for o in part.options:
			if o.target in Dialogue.ENDINGS:
				return true
			if not seen.has(o.target):
				seen[o.target] = true
				todo.append(o.target)
	return false


## 练习场教官: 默认的准备 (学识 2、意志 3) 能看到笨的回答; 学识、意志高了, 能问别的、能要钱
func test_trainer_with_different_stats() -> void:
	var d := Dialogue.load_file("res://dialogues/trainer.txt")
	var setup := Practice.Setup.new()
	var plain := Dialogue.Talk.new(d, setup.stats)
	var words := texts(plain.options())
	check(words.any(func(t: String) -> bool: return t.begins_with("打……打架")), "学识 2: 说话结结巴巴")
	check(not words.any(func(t: String) -> bool: return t.contains("命中几率")))
	var memory := Dialogue.Memory.new()
	var clever := Dialogue.Talk.new(d, Practice.stats(1, 5, 2, 6, 3, 7), memory)
	words = texts(clever.options())
	check(words.any(func(t: String) -> bool: return t.contains("命中几率")))
	var ask := words.find(words.filter(func(t: String) -> bool: return t.contains("辛苦钱"))[0])
	clever.choose(ask)
	eq(memory.money, 20)
	clever.choose(0)
	check(not texts(clever.options()).any(func(t: String) -> bool: return t.contains("辛苦钱")), "要过一次就没了")
