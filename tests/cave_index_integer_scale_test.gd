extends SceneTree
## Owner report 11:00 ("pixels moving in the wall"): windows larger than the 1920x1080 index cap were resolved at a
## fractional nearest scale (6144x3312 -> 1920x1035 = 3.2x), so wall texels alternated between 3 and 4 screen pixels
## as the view moved. The index size is now the window divided by a whole number.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var review = load("res://scripts/lol2/indexed_cave_wall_review.gd").new()
	var cases := {
		Vector2i(960, 540): Vector2i(960, 540),
		Vector2i(1920, 1080): Vector2i(1920, 1080),
		Vector2i(6144, 3312): Vector2i(1536, 828),
		Vector2i(3072, 1656): Vector2i(1536, 828),
		Vector2i(3840, 2160): Vector2i(1920, 1080),
		Vector2i(2560, 1440): Vector2i(1280, 720),
		Vector2i(2400, 1350): Vector2i(1200, 675),
	}
	for window in cases:
		var got: Vector2i = review._bounded_index_size(window)
		assert(got == cases[window], "%s -> %s, expected %s" % [window, got, cases[window]])
		assert(got.x <= review.INDEX_MAX_SIZE.x and got.y <= review.INDEX_MAX_SIZE.y, "Within the index cap")
		if got != window:
			assert(window.x % got.x == 0 and window.y % got.y == 0, "Whole-number resolve scale for %s" % window)
	# Old rule kept as a negative control: the owner window would have been 3.2x.
	var old_scale := minf(1920.0 / 6144.0, 1080.0 / 3312.0)
	assert(not is_equal_approx(fmod(1.0 / old_scale, 1.0), 0.0), "Old cap rule gives a fractional scale")
	review.free()
	print("PASS cave index integer scale: owner 6144x3312 -> 1536x828 (4x), windows <=1920x1080 unchanged")
	quit()
