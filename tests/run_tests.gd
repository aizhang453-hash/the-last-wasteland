extends SceneTree
## 跑全部测试。
## 运行方法: 在游戏文件夹里输入
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tests/run_tests.gd
## 新拿到的仓库 (没有 .godot 文件夹) 要先跑一次 Godot --headless --path . --import, 让 Godot 认识各个脚本
## (Windows 上把前面换成 Godot 的路径)。全部通过最后一行是「全部通过」。
## 注意: 脚本出错 (SCRIPT ERROR) Godot 只会打印出来, 不会算成失败, 所以也要看输出里有没有 SCRIPT ERROR。


func _init() -> void:
	var here: String = get_script().resource_path.get_base_dir()
	var total := 0
	var failures: Array = []
	var files := Array(DirAccess.get_files_at(here))
	files.sort()
	for file in files:
		if not (file.begins_with("test_") and file.ends_with(".gd")) or file == "test_case.gd":
			continue
		var script: GDScript = load(here + "/" + file)
		var methods := []
		for m in script.get_script_method_list():
			if String(m.name).begins_with("test_") and not methods.has(m.name):
				methods.append(m.name)
		for m in methods:
			var t = script.new()
			t.current_test = "%s %s" % [file.get_basename(), m]
			if t.has_method("before_each"):
				t.before_each()
			t.call(m)
			if t.has_method("after_each"):
				t.after_each()
			total += 1
			failures.append_array(t.failures)
		print("%s: %d 条" % [file, methods.size()])
	for f in failures:
		print("  ✗ ", f)
	if failures.is_empty():
		print("一共 %d 条测试, 全部通过" % total)
	else:
		print("一共 %d 条测试, %d 处不对" % [total, failures.size()])
	quit(0 if failures.is_empty() else 1)
