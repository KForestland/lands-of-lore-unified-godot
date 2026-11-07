extends SceneTree
## Classic depth shading (tools/prepare_classic_depth_shading.py + classic_depth_shading.gdshaderinc). Headless:
## producer outputs and manifest, the region -> light descriptor binding, the native 0x1319B4 fixed-point formula at
## hand-computed points, and that both Cave index shaders parse with the shading code.
const ClassicShading = preload("res://scripts/lol2/classic_depth_shading.gd")
const ROOT := "res://assets/lol2/generated/classic_depth_shading/"
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("FAIL: " + message)

## GDScript copy of classic_row(): 16.16 distance, integer quotient fade, (fade * ambient) >> 7, * multiplier, clamp.
func native_row(distance: float, sector: Color) -> float:
	var delta := int(minf(distance, 32767.0) * 65536.0) - int(sector.g) * 65536
	var span := int(sector.b) * 65536
	var fade := 65536 if delta < 1 else (65536 - delta / int(sector.b) if delta < span else 0)
	var level := int(sector.a) * ((fade * int(sector.r)) >> 7)
	return float(clampi(level, 0, 0x3F0000)) / 65536.0

func _init() -> void:
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "manifest.json"))
	check(manifest is Dictionary and manifest.areas.has("L1_DC"), "manifest names L1_DC")
	var area: Dictionary = manifest.areas.L1_DC
	for file in area.outputs:
		var bytes := FileAccess.get_file_as_bytes(ROOT + file)
		var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(bytes)
		check(hash.finish().hex_encode() == area.outputs[file], "manifest sha256 of " + file)
	check(int(area.region_count) == 1954 and int(area.descriptor_count) == 173, "1954 regions, 173 light descriptors")
	check(area.inputs.shade_rows_0_63_sha256 == "2bc42e4e91afa880abae98ab4cc7f85b238496179c762b1371f8259733c51509", "shade rows 0..63 of the L1 texture file (G43 slice)")
	var shade := Image.load_from_file(ROOT + "shade_L1_DC.png")
	check(shade.get_width() == 256 and shade.get_height() == 64, "shade table 256x64")
	var row0_black := true
	for x in 256: row0_black = row0_black and shade.get_pixel(x, 0).r8 == 0
	check(row0_black, "row 0 maps every index to 0 (G43)")

	var shading := ClassicShading.new()
	check(shading.load_area("L1_DC"), "inputs load")
	var counts := {}
	for region in shading.regions:
		var row: Array = shading.regions[region]
		var key := "%d,%d,%d" % [int(row[0]), int(row[1]), int(row[2])]
		counts[key] = counts.get(key, 0) + 1
	check(counts.get("60,300,100", 0) == 1335, "1335 regions use ambient 60, fade start 300, span 100")
	check(shading.sector(99999) == ClassicShading.OFF, "unknown region stays unshaded")
	var common := Color(60, 300, 100, ClassicShading.SURFACE_MULTIPLIER)
	# Hand-computed from 0x1319B4 with [0xFD8A8] = 128 and no light records.
	check(native_row(0.0, common) == 60.0, "inside fade start: the ambient row (60)")
	check(native_row(300.0, common) == 60.0, "at fade start: still 60")
	check(native_row(350.0, common) == 30.0, "half way through the span: row 30")
	check(native_row(399.99, common) < 1.0, "end of span: row 0")
	check(native_row(400.0, common) == 0.0, "beyond fade start + span: black")
	check(native_row(0.0, Color(65, 800, 300, 128)) == 63.0, "ambient 65 clamps to row 63")
	check(native_row(10.0, Color(-5, 300, 100, 128)) == 0.0, "negative ambient clamps to 0")

	var include := FileAccess.get_file_as_string("res://scripts/lol2/classic_depth_shading.gdshaderinc")
	for token in ["0x3F0000", ">> 7", "delta / int(sector.z)", "65536 - delta", "global uniform sampler2D lol2_classic_shade"]:
		check(include.contains(token), "shader include keeps " + token)
	for path in ["res://scripts/lol2/indexed_wall_review.gdshader", "res://scripts/lol2/indexed_surface_review.gdshader"]:
		var shader: Shader = load(path)
		check(shader != null and shader.get_shader_uniform_list().size() > 0, "shader parses: " + path)
		check(shader.code.contains("classic_depth_shading.gdshaderinc") and shader.code.contains("classic_shade("), "shader applies shading: " + path)
	ClassicShading.clear()
	print("Classic depth shading: %d failures" % failures)
	if failures == 0: print("PASS classic depth shading inputs, formula and shaders")
	quit(0 if failures == 0 else 1)
