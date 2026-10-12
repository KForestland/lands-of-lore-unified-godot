extends SceneTree

const Check = preload("res://scripts/lol2/original_game_check.gd")

func _initialize() -> void:
	var source := OS.get_cmdline_user_args()[0]
	assert(Check.verify(source).is_empty(), "Known original must pass")
	assert(not Check.verify("").is_empty(), "Empty path must fail")
	assert(not Check.verify("user://absent-original.exe").is_empty(), "Missing file must fail")
	var original := FileAccess.get_file_as_bytes(source)
	original[original.size() - 1] = original[original.size() - 1] ^ 1
	var altered := FileAccess.open("user://altered-original.exe", FileAccess.WRITE)
	altered.store_buffer(original)
	altered.close()
	assert(not Check.verify("user://altered-original.exe").is_empty(), "Same-size altered file must fail")
	altered = FileAccess.open("user://altered-original.exe", FileAccess.WRITE)
	altered.store_buffer(PackedByteArray([77, 90]))
	altered.close()
	assert(not Check.verify("user://altered-original.exe").is_empty(), "Truncated file must fail")
	DirAccess.remove_absolute("user://altered-original.exe")
	print("PASS: original, empty, missing, same-size mutation, truncated executable")
	quit()
