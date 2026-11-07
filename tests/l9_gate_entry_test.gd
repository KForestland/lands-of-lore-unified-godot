extends SceneTree

# Exercise the actual CLI dispatch, including the frames after the scene switch.
# run_regressions supplies --l9-preview and the verified original executable.
const SETTINGS := "user://original_game.cfg"
var saved_settings: PackedByteArray
var had_settings := false

func _initialize() -> void:
	run.call_deferred()

func finish(code: int) -> void:
	if had_settings:
		var file := FileAccess.open(SETTINGS, FileAccess.WRITE)
		file.store_buffer(saved_settings)
	else:
		DirAccess.remove_absolute(SETTINGS)
	quit(code)

func run() -> void:
	had_settings = FileAccess.file_exists(SETTINGS)
	if had_settings:
		saved_settings = FileAccess.get_file_as_bytes(SETTINGS)
	if not "--l9-preview" in OS.get_cmdline_user_args():
		print("FAIL missing L9 CLI test arguments")
		finish(1)
		return
	if change_scene_to_file("res://scenes/lol2/original_game_gate.tscn") != OK:
		print("FAIL gate scene load")
		finish(1)
		return
	for frame in 300:
		await process_frame
		if current_scene == null or current_scene.get_script().resource_path != "res://scripts/lol2/dragon_level.gd":
			continue
		var dragon_id := current_scene.get_instance_id()
		for settle in 30:
			await process_frame
			if current_scene == null or current_scene.get_instance_id() != dragon_id:
				print("FAIL L9 CLI entry switched scenes again")
				finish(1)
				return
		if not get_meta("original_game_verified", false):
			print("FAIL original executable was not verified")
			finish(1)
			return
		current_scene.queue_free()
		await process_frame
		print("PASS L9 CLI entry remains in dragon level")
		finish(0)
		return
	print("FAIL L9 CLI entry timed out")
	finish(1)
