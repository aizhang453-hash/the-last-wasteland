class_name Dialogue
extends RefCounted
## 跟人说话的规则: 读对话文件, 记着说到哪一段、说过什么。只管规则, 不管画 (画在 dialogue_view.gd)。
## 对话文件放在 dialogues/ 里, 是普通的文字文件, 怎么写见 dialogues/README.md。简单说:
##   人物: 教官                对方叫什么
##   头像: 教官                用哪张头像 (Portrait.LOOKS 里的名字)
##   == 开头                   一段话的名字; 第一段就是一开口说的
##   对方说的话                (不是下面这些符号开头的行, 都是对方说的话)
##   > 钱 +20                  走到这一段时发生的事: 钱 +几 / 钱 -几 / 记住 某件事 / 忘掉 某件事
##   * [学识 6] 选项 -> 下一段  你能选的回答; 方括号里是条件, 都满足才出现; 箭头后面是下一段, 或者「结束」「开打」

const END := "结束"      ## 说完了, 回去
const FIGHT := "开打"    ## 说完了, 打起来
const ENDINGS := [END, FIGHT]
const MONEY := "钱"


## 一个能选的回答
class Option:
	var text := ""
	var target := ""         ## 选了以后去哪一段 (或者「结束」「开打」)
	## 条件, 都满足才出现。能力值和钱: {"stat": "intellect" 或 "钱", "value": 6, "most": false (false 是几分以上, true 是几分以下)};
	## 记没记住一件事: {"flag": "给过钱", "want": true (要记得) 或 false (要不记得)}
	var conditions: Array = []
	var tag := ""            ## 靠能力值换来的选项, 前面写的小牌子 (比如「学识 6」)
	var line := 0            ## 在文件第几行 (报错用)


## 一段: 对方说一番话, 你挑一个回答
class Part:
	var name := ""
	var text := ""           ## 对方说的话 (文件里分几行写, 显示时也分几行)
	var effects: Array = []  ## 走到这一段时发生的事: ["钱", 20] / ["记住", "给过钱"] / ["忘掉", "给过钱"]
	var options: Array = []
	var line := 0


## 你身上的钱和记住的事: 说话时会看、会改, 一直留着 (下次再说话还在)
class Memory:
	var money := 0
	var flags := {}


var who := "对方"        ## 对方叫什么 (回顾里写)
var face := ""           ## 头像
var parts := {}          ## 段名 -> Part
var first := ""          ## 第一段
var problems: Array = [] ## 文件里写错的地方, 每条是一句话 (「第 12 行: ……」)


static func load_file(path: String) -> Dialogue:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		var d := Dialogue.new()
		d.problems.append("打不开对话文件 %s" % path.get_file())
		return d
	return parse(f.get_as_text())


## 能力值的中文名 -> 代码里的名字 (「学识」-> "intellect"); 不是能力值返回 ""
static func stat_key(cn: String) -> String:
	for key in Rules.STAT_NAMES:
		if Rules.STAT_NAMES[key] == cn:
			return key
	return ""


static func parse(source: String) -> Dialogue:
	var d := Dialogue.new()
	var part: Part = null
	var n := 0
	for raw in source.split("\n"):
		n += 1
		var line := _plain_start(raw.strip_edges())
		if line == "" or line.begins_with("#"):
			continue
		if line.begins_with("=="):
			part = Part.new()
			part.name = line.lstrip("=").rstrip("=＝").strip_edges()
			part.line = n
			if part.name == "":
				d.problems.append("第 %d 行: 「==」后面要写这一段的名字" % n)
			elif part.name in ENDINGS:
				d.problems.append("第 %d 行: 「%s」是留着用的, 段名换一个" % [n, part.name])
			elif d.parts.has(part.name):
				d.problems.append("第 %d 行: 已经有一段叫「%s」了 (第 %d 行)" % [n, part.name, d.parts[part.name].line])
			else:
				d.parts[part.name] = part
				if d.first == "":
					d.first = part.name
		elif part == null:
			var colon := line.replace("：", ":").find(":")
			var key := line.substr(0, colon).strip_edges() if colon > 0 else ""
			if key == "人物":
				d.who = line.substr(colon + 1).strip_edges()
			elif key == "头像":
				d.face = line.substr(colon + 1).strip_edges()
			else:
				d.problems.append("第 %d 行: 先写「== 段名」, 再写对方说的话" % n)
		elif line.begins_with("*"):
			part.options.append(_option(line.substr(1), n, d))
		elif line.begins_with(">"):
			var effect := _effect(line.substr(1).strip_edges(), n, d)
			if not effect.is_empty():
				part.effects.append(effect)
		else:
			part.text += ("\n" if part.text != "" else "") + line
	if d.parts.is_empty():
		d.problems.append("一段都没有 (要写「== 段名」)")
	for p in d.parts.values():
		if p.text == "":
			d.problems.append("第 %d 行: 「%s」这一段对方什么都没说" % [p.line, p.name])
		for o in p.options:
			if o.target != "" and not (o.target in ENDINGS or d.parts.has(o.target)):
				d.problems.append("第 %d 行: 找不到叫「%s」的一段" % [o.line, o.target])
	return d


## 用中文输入法容易在行首打出全角的符号 (＊ ＞ ＝＝), 换成半角的。对方说的话里的符号不动
static func _plain_start(line: String) -> String:
	for pair in [["＊", "*"], ["＞", ">"], ["＝＝", "=="]]:
		if line.begins_with(pair[0]):
			return pair[1] + line.substr(pair[0].length())
	return line


static func _option(body: String, n: int, d: Dialogue) -> Option:
	var o := Option.new()
	o.line = n
	var rest := body.strip_edges()
	for pair in [["【", "["], ["】", "]"], ["［", "["], ["］", "]"], ["→", "->"]]:  # 全角的方括号、箭头也认
		rest = rest.replace(pair[0], pair[1])
	while rest.begins_with("["):
		var close := rest.find("]")
		if close < 0:
			d.problems.append("第 %d 行: 方括号没有关上" % n)
			break
		var c := _condition(rest.substr(1, close - 1).strip_edges(), n, d)
		if not c.is_empty():
			o.conditions.append(c)
			if o.tag == "" and c.has("stat") and c["stat"] != MONEY and not c["most"]:
				o.tag = "%s %d" % [Rules.STAT_NAMES[c["stat"]], c["value"]]
		rest = rest.substr(close + 1).strip_edges()
	var arrow := rest.rfind("->")
	if arrow < 0:
		d.problems.append("第 %d 行: 选项后面要写「-> 下一段的名字」" % n)
		o.text = rest
		o.target = END
	else:
		o.text = rest.substr(0, arrow).strip_edges()
		o.target = rest.substr(arrow + 2).strip_edges()
		if o.target == "":
			d.problems.append("第 %d 行: 箭头后面要写下一段的名字" % n)
	if o.text == "":
		d.problems.append("第 %d 行: 这个选项没有字" % n)
	return o


## 方括号里的条件: [学识 6] 6 分以上, [学识 3以下] 3 分以下, [钱 10] 钱有 10 以上, [记得 某件事], [不记得 某件事]
static func _condition(words: String, n: int, d: Dialogue) -> Dictionary:
	for key in ["不记得", "记得"]:
		if words.begins_with(key):
			var flag := words.substr(key.length()).strip_edges()
			if flag == "":
				d.problems.append("第 %d 行: 「%s」后面要写记的是什么事" % [n, key])
				return {}
			return {"flag": flag, "want": key == "记得"}
	var m := RegEx.create_from_string("^(\\S+?)\\s*(>=|<=|≥|≤)?\\s*(\\d+)\\s*(以上|以下)?$").search(words)
	if m == null:
		d.problems.append("第 %d 行: 看不懂的条件「%s」(能写: 学识 6、学识 3以下、钱 10、记得 某件事、不记得 某件事)" % [n, words])
		return {}
	var name := m.get_string(1)
	var key := MONEY if name == MONEY else stat_key(name)
	if key == "":
		d.problems.append("第 %d 行: 没有「%s」这个能力值 (能写: %s、钱)" % [n, name, "、".join(Rules.STAT_NAMES.values())])
		return {}
	var most := m.get_string(2) in ["<=", "≤"] or m.get_string(4) == "以下"
	return {"stat": key, "value": int(m.get_string(3)), "most": most}


## 「>」后面写的事: 钱 +20 / 钱 -5 / 记住 某件事 / 忘掉 某件事
static func _effect(words: String, n: int, d: Dialogue) -> Array:
	var m := RegEx.create_from_string("^钱\\s*([+-]?)\\s*(\\d+)$").search(words.replace("＋", "+").replace("－", "-"))
	if m != null:
		var amount := int(m.get_string(2))
		return [MONEY, -amount if m.get_string(1) == "-" else amount]
	for key in ["记住", "忘掉"]:
		if words.begins_with(key) and words.substr(key.length()).strip_edges() != "":
			return [key, words.substr(key.length()).strip_edges()]
	d.problems.append("第 %d 行: 看不懂的「%s」(能写: 钱 +20、钱 -5、记住 某件事、忘掉 某件事)" % [n, words])
	return []


## 一段里一个能选的都没有的时候, 给一个「结束对话」, 免得卡住
static func goodbye() -> Option:
	var o := Option.new()
	o.text = "(结束对话)"
	o.target = END
	return o


## 一次说话: 现在说到哪一段, 说过的话 (「回顾」里看)
class Talk:
	var dialogue: Dialogue
	var stats: Dictionary    ## 你的能力值 (救世主系统六项)
	var memory: Dialogue.Memory
	var part: Dialogue.Part = null
	var history: Array = []  ## 说过的话: ["npc" 或 "you", 说的话]
	var ended := ""          ## 说完了: 「结束」或「开打」; 还在说是 ""

	func _init(p_dialogue: Dialogue, p_stats: Dictionary, p_memory: Dialogue.Memory = null) -> void:
		dialogue = p_dialogue
		stats = p_stats
		memory = p_memory if p_memory != null else Dialogue.Memory.new()
		if dialogue.parts.has(dialogue.first):
			go(dialogue.first)
		else:
			ended = Dialogue.END

	## 走到某一段 (或者结束)
	func go(name: String) -> void:
		if name in Dialogue.ENDINGS:
			ended = name
			return
		part = dialogue.parts[name]
		for e in part.effects:
			match e[0]:
				Dialogue.MONEY:
					memory.money = maxi(0, memory.money + e[1])
				"记住":
					memory.flags[e[1]] = true
				"忘掉":
					memory.flags.erase(e[1])
		history.append(["npc", part.text])

	func passes(c: Dictionary) -> bool:
		if c.has("flag"):
			return memory.flags.has(c["flag"]) == c["want"]
		var have: int = memory.money if c["stat"] == Dialogue.MONEY else stats.get(c["stat"], 0)
		return have <= c["value"] if c["most"] else have >= c["value"]

	## 现在能选的回答 (条件不满足的不出现; 一个都没有就给一个「结束对话」)
	func options() -> Array:
		if ended != "" or part == null:
			return []
		var list := part.options.filter(func(o: Dialogue.Option) -> bool: return o.conditions.all(passes))
		if list.is_empty():
			list = [Dialogue.goodbye()]
		return list

	## 选第 i 个回答 (从 0 数)。选不了返回 false
	func choose(i: int) -> bool:
		var list := options()
		if i < 0 or i >= list.size():
			return false
		var o: Dialogue.Option = list[i]
		history.append(["you", o.text])
		go(o.target)
		return true
