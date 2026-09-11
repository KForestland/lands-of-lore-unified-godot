extends Control
func _ready() -> void:
	var available := FileAccess.file_exists("res://assets/lol2/generated/original_floors/full_walk.json")
	if "--setup-smoke" in OS.get_cmdline_user_args():
		print("Source checkout setup: generated assets present=", available)
		get_tree().quit()
		return
	var label := Label.new()
	label.position = Vector2(30, 30)
	label.text = "Lands of Lore restoration research\n\nGenerated game assets are not included in this source checkout.\nRead docs/RESTORATION_STATUS.md for setup requirements and current limits.\n\nWith generated assets available, use tools/lol2/run_full_cave.sh."
	add_child(label)
