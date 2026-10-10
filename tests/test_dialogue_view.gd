extends TestCase
## 说话的画面: 不开窗口, 直接把鼠标键盘的事件交给画面, 看点了有没有反应。画得对不对看截图 (screenshots.gd)。

const SAMPLE := """
人物: 老王
头像: 路人

== 开头
你好。
* 你是谁? -> 介绍
* [学识 6] 聪明的问题 -> 介绍
* 打一架 -> 开打
* 走了 -> 结束

== 介绍
我是老王。我在这里修了很多年的东西, 收音机、水泵、发电机, 什么都修, 坏得再厉害的也修过。
有人说我脾气不好, 其实只是不爱说话。你要是有东西要修, 就放在门口, 过两天再来拿。
钱的事好说, 有多少给多少, 没有就拿别的东西换。
* 回去 -> 开头
"""

var view: DialogueView
var memory: Dialogue.Memory
var finished: Array = []


func before_each() -> void:
	memory = Dialogue.Memory.new()
	finished = []
	view = DialogueView.new(Dialogue.Talk.new(Dialogue.parse(SAMPLE), Practice.Setup.new().stats, memory))
	view.finished.connect(func(how: String): finished.append(how))


func after_each() -> void:
	view.free()


func click(p: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	var ev := InputEventMouseButton.new()
	ev.position = p
	ev.button_index = button
	ev.pressed = true
	view._gui_input(ev)


func hover(p: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = p
	view._gui_input(ev)


## 第 i 行回答在画面上的位置
func row_pos(i: int) -> Vector2:
	return Vector2(DialogueView.OPT_BOX.position.x + 100, view.opt_top() + i * DialogueView.OPT_LINE + 12)


func test_hover_and_click_option() -> void:
	eq(view.option_rows().size(), 3, "学识 2: 聪明的问题不出现")
	hover(row_pos(1))
	eq(view.option_at(view.mouse), 1)
	eq(view.option_at(row_pos(5)), -1, "下面空着的地方不是回答")
	eq(view.option_at(Vector2(600, 300)), -1)
	click(row_pos(0))
	eq(view.talk.part.name, "介绍")
	check(view.speak_left > 0, "对方开始说话 (嘴一张一合)")


func test_number_keys() -> void:
	view.press_key(KEY_1)
	eq(view.talk.part.name, "介绍")
	view.press_key(KEY_5)
	eq(view.talk.part.name, "介绍", "没有第 5 个, 不动")
	view.press_key(KEY_KP_1)
	eq(view.talk.part.name, "开头")


func test_finished_signal() -> void:
	view.press_key(KEY_3)
	eq(finished, [Dialogue.END])
	before_each_again()
	view.press_key(KEY_2)
	eq(finished, [Dialogue.FIGHT])


func before_each_again() -> void:
	view.free()
	before_each()


func test_tags_show_on_options() -> void:
	var s := Practice.stats(1, 5, 5, 7, 5, 1)
	view.begin(Dialogue.Talk.new(Dialogue.parse(SAMPLE), s, memory))
	var rows := view.option_rows()
	eq(rows.size(), 4)
	eq(rows[1][1], "[学识 6] 聪明的问题")


func test_long_reply_scrolls() -> void:
	view.press_key(KEY_1)
	var lines := view.reply_lines()
	check(lines.size() > view.reply_fit(), "这段话太长, 一次显示不完 (%d 行)" % lines.size())
	eq(view.reply_scroll, 0)
	click(DialogueView.REPLY_BOX.position + Vector2(100, 10), MOUSE_BUTTON_WHEEL_DOWN)
	eq(view.reply_scroll, 1)
	for i in 20:
		view.press_key(KEY_DOWN)
	eq(view.reply_scroll, lines.size() - view.reply_fit(), "翻到底就不动了")
	click(DialogueView.REPLY_BOX.position + Vector2(100, 10))
	eq(view.reply_scroll, lines.size() - view.reply_fit() - 1, "点上半边往上翻")
	view.press_key(KEY_UP)
	view.press_key(KEY_UP)
	view.press_key(KEY_UP)
	view.press_key(KEY_UP)
	eq(view.reply_scroll, 0)
	click(row_pos(0))
	eq(view.reply_scroll, 0, "换了一段, 从头显示")


func test_review() -> void:
	view.press_key(KEY_1)
	view.press_key(KEY_1)
	click(DialogueView.REVIEW_BTN.get_center())
	check(view.reviewing)
	var rows := view.review_rows()
	eq(rows[0][0], "老王:")
	eq(rows[1][0], "你好。")
	check(rows.any(func(r: Array) -> bool: return r[0] == "你:"))
	check(rows.any(func(r: Array) -> bool: return r[0] == "你是谁?"))
	view.press_key(KEY_1)
	eq(view.talk.part.name, "开头", "开着回顾, 数字键不选回答")
	var bottom := view.review_scroll
	eq(bottom, maxi(0, rows.size() - view.review_fit()), "先看最近说的")
	click(DialogueView.REVIEW_UP.get_center())
	check(view.review_scroll < bottom or bottom == 0)
	click(DialogueView.REVIEW_DONE.get_center())
	check(not view.reviewing)
	view.press_key(KEY_R)
	check(view.reviewing)
	view.press_key(KEY_ESCAPE)
	check(not view.reviewing)


func test_barter_later() -> void:
	click(DialogueView.BARTER_AT)
	has_text(view.hint, "以后才有")
	view.step(DialogueView.HINT_TIME + 0.1)
	eq(view.hint, "")
	view.press_key(KEY_B)
	has_text(view.hint, "交易")


func test_money_shows() -> void:
	memory.money = 35
	eq(view.talk.memory.money, 35, "钱数小屏幕显示的就是这个")


func test_many_options_scroll() -> void:
	var lines := "== 开头\n挑一个。\n"
	for i in 9:
		lines += "* 第 %d 个回答, 写得很长很长很长很长很长很长很长很长很长很长很长很长很长 -> 结束\n" % (i + 1)
	view.begin(Dialogue.Talk.new(Dialogue.parse(lines), Practice.Setup.new().stats, memory))
	var rows := view.option_rows()
	check(rows.size() > view.opt_fit(), "回答太多, 一屏放不下")
	click(DialogueView.OPT_BOX.get_center(), MOUSE_BUTTON_WHEEL_DOWN)
	eq(view.opt_scroll, 1)
	eq(view.option_at(row_pos(0)), rows[1][0], "翻了一行, 最上面是第二行")
	view.press_key(KEY_9)
	eq(finished, [Dialogue.END], "数字键不管翻没翻, 都是第几个回答")


# ---------- 准备画面和整个游戏 ----------

func test_setup_talk_button() -> void:
	var sv := SetupView.new()
	var asked := [false]
	sv.talk_requested.connect(func(): asked[0] = true)
	var ev := InputEventMouseButton.new()
	ev.position = SetupView.TALK_BTN.get_center()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	sv._gui_input(ev)
	check(asked[0])
	sv.mouse = SetupView.TALK_BTN.get_center()
	has_text(sv.hovered_help(), "说话")
	sv.free()


func test_main_talk_then_fight() -> void:
	var main: Control = load("res://scripts/main.gd").new()
	main._ready()
	main._on_talk()
	var dv: DialogueView = main.dialogue_view
	check(dv != null and dv.visible and not main.setup_view.visible)
	eq(dv.talk.dialogue.who, "教官")
	var fight: int = dv.talk.options().map(func(o: Dialogue.Option) -> String: return o.target).find(Dialogue.FIGHT)
	dv.choose(fight)
	check(not dv.visible)
	check(main.arena != null and main.arena.visible, "说「开打」就直接开打")
	main.free()


func test_main_talk_then_back() -> void:
	var main: Control = load("res://scripts/main.gd").new()
	main._ready()
	main.setup.change("agility", -1)  # 还有 1 点没分
	main._on_talk()
	var dv: DialogueView = main.dialogue_view
	dv.choose(dv.talk.options().map(func(o: Dialogue.Option) -> String: return o.target).find(Dialogue.FIGHT))
	check(main.setup_view.visible and main.arena == null, "点数没分完, 不能开打, 回到准备画面")
	has_text(main.setup_view.hint, "没分完")
	main._on_talk()
	check(dv.visible, "再说一次, 用的还是同一个画面")
	dv.choose(dv.talk.options().map(func(o: Dialogue.Option) -> String: return o.target).find(Dialogue.END))
	check(main.setup_view.visible and not dv.visible)
	main.free()
