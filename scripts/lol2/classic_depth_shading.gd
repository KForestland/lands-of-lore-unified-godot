extends RefCounted
## Classic depth shading inputs (tools/prepare_classic_depth_shading.py) for classic_depth_shading.gdshaderinc.
## Static geometry carries its region's sector in CUSTOM0; moving sprites use the viewer's region (adapter, see DEVIATIONS).
const ROOT := "res://assets/lol2/generated/classic_depth_shading/"
const NAV := "res://assets/lol2/generated/creature_nav/L1_DC.json"
## [0xFD8A8]: run-time surface byte, file source untraced (G38). 128 is the neutral value of mult * (x >> 7).
const SURFACE_MULTIPLIER := 128.0
const OFF := Color(0, 0, 0, 0)
const Navigation = preload("res://scripts/lol2/creature_navigation.gd")

var regions: Dictionary = {}
var navigation: Navigation
var view_region := -2

func load_area(area: String) -> bool:
	var path := ROOT + "sectors_%s.json" % area
	var image := Image.load_from_file(ROOT + "shade_%s.png" % area)
	if not FileAccess.file_exists(path) or image == null or image.is_empty():
		push_warning("Classic depth shading inputs missing for %s: run tools/prepare_classic_depth_shading.py" % area)
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not parsed.get("regions") is Dictionary:
		push_warning("Invalid classic depth shading sectors for %s" % area)
		return false
	regions = parsed.regions
	RenderingServer.global_shader_parameter_set("lol2_classic_shade", ImageTexture.create_from_image(image))
	navigation = Navigation.new()
	if navigation.load_graph(NAV) != "": navigation = null
	return true

## Sector of one source region as CUSTOM0 / uniform value; OFF when unknown (the surface stays unshaded).
func sector(region: int) -> Color:
	var row: Variant = regions.get(str(region))
	if not row is Array: return OFF
	return Color(float(row[0]), float(row[1]), float(row[2]), SURFACE_MULTIPLIER)

## Viewer region for moving sprites. native = Godot position minus the fixture translation.
func update_view(native: Vector3) -> void:
	var region := navigation.region_at(native) if navigation != null else -1
	if region == view_region: return
	view_region = region
	var value := sector(region)
	RenderingServer.global_shader_parameter_set("lol2_classic_view_sector", Vector4(value.r, value.g, value.b, value.a))

## Owner direction 2026-10-29: the decoded depth shading is an "original darkness" option, default OFF (project.godot
## shader global lol2_classic_shading_enabled). Pass --original-darkness or press O in the Cave to turn it on.
## The engine meta mirrors the shader global (the headless dummy renderer does not read globals back).
static func enabled() -> bool:
	if Engine.has_meta("lol2_classic_shading_enabled"): return bool(Engine.get_meta("lol2_classic_shading_enabled"))
	var setting: Variant = ProjectSettings.get_setting("shader_globals/lol2_classic_shading_enabled")
	return setting is Dictionary and setting.get("value", false) == true

static func set_enabled(on: bool) -> void:
	Engine.set_meta("lol2_classic_shading_enabled", on)
	RenderingServer.global_shader_parameter_set("lol2_classic_shading_enabled", on)

static func clear() -> void:
	RenderingServer.global_shader_parameter_set("lol2_classic_view_sector", Vector4(0, 0, 0, -1))
