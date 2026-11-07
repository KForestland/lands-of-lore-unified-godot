extends RefCounted
## Local lights for the Cave light field (cave_light_field.gdshaderinc) at the hosted native emitters:
## the 7 wall torches (cave_scenery_source.json template 73, light at the chained flame), the 48 lava flames
## (cave_lava_flames_source.json, templates 69/70/71) and the 27 tar pits (cave_tar_fires_source.json) while they burn
## (selector 2). Positions are the native placements; colour, intensity, range and the quadratic falloff are
## presentation adapters (docs/DEVIATIONS.md 2026-10-29). The nearest MAX_UPLOADED lights to the viewer are uploaded
## to every light-pass material when that set changes; nothing is saved.
const MAX_UPLOADED := 24
const SCENERY := "res://scripts/lol2/cave_scenery_source.json"
const LAVA := "res://scripts/lol2/cave_lava_flames_source.json"
const TAR := "res://scripts/lol2/cave_tar_fires_source.json"
## kind -> [colour * intensity, range, height of the light above the placement (fraction of the sprite top)]
const KINDS := {"torch": [Color(0.85, 0.62, 0.34), 320.0, 0.75], "lava": [Color(0.70, 0.36, 0.14), 220.0, 0.35],
	"tar": [Color(0.80, 0.48, 0.20), 240.0, 0.5]}
var lights: Array[Dictionary] = []  # {id, kind, position, color, range, prop}
var uploaded_key := ""

static func _row_light(id: String, kind: String, row: Dictionary, top: float, translation: Vector3) -> Dictionary:
	var spec: Array = KINDS[kind]
	var at := Vector3(row.position[0], row.position[1], row.position[2]) + translation + Vector3(0, top * float(spec[2]), 0)
	return {"id": kind + id, "kind": kind, "prop": id, "position": at, "color": spec[0], "range": float(spec[1])}

## Every emitter the contracts name, in a fixed order (torches, lava flames, tar pits).
static func collect(translation: Vector3 = Vector3.ZERO) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if FileAccess.file_exists(SCENERY):
		var scenery: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SCENERY))
		for id in scenery.props:
			var row: Dictionary = scenery.props[id]
			if int(row.template) == 73: out.append(_row_light(str(id), "torch", row, float(row.chain.top) if row.has("chain") else float(row.top), translation))
	if FileAccess.file_exists(LAVA):
		var lava: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LAVA))
		for id in lava.props:
			var row: Dictionary = lava.props[id]
			out.append(_row_light(str(id), "lava", row, float(lava.template_heights[str(int(row.template))]), translation))
	if FileAccess.file_exists(TAR):
		var tar: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TAR))
		for id in tar.props:
			var row: Dictionary = tar.props[id]
			var template: Dictionary = tar.templates[str(int(row.template))]
			out.append(_row_light(str(id), "tar", row, float(template.selectors[2].top), translation))
	return out

func build(host: Node3D) -> void:
	lights = collect(host.native_translation)
	uploaded_key = ""

## A tar pit lights only while its sequencer shows the burning loop (selector 2); torches and lava always.
static func active(light: Dictionary, tar_fires: Node) -> bool:
	if light.kind != "tar": return true
	if tar_fires == null or not is_instance_valid(tar_fires) or tar_fires.get("state") == null: return false
	var props: Dictionary = tar_fires.state.get("props", {})
	return props.has(light.prop) and int(props[light.prop].get("selector", 0)) == 2

## The MAX_UPLOADED active lights nearest to `from`, nearest first.
static func nearest(candidates: Array[Dictionary], from: Vector3, tar_fires: Node, limit: int = MAX_UPLOADED) -> Array[Dictionary]:
	var live: Array[Dictionary] = []
	for light in candidates:
		if active(light, tar_fires): live.append(light)
	live.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.position.distance_squared_to(from) < b.position.distance_squared_to(from))
	return live.slice(0, limit)

## Uploads the nearest set to the light-pass materials when it changed. Returns true when an upload happened.
func sync(host: Node3D, from: Vector3) -> bool:
	var chosen := nearest(lights, from, host.get("tar_fires"))
	var key := ""
	for light in chosen: key += str(light.id) + ";"
	if key == uploaded_key: return false
	uploaded_key = key
	var positions := PackedVector3Array()
	var colors := PackedVector4Array()
	for light in chosen:
		positions.append(light.position)
		colors.append(Vector4(light.color.r, light.color.g, light.color.b, light.range))
	while positions.size() < MAX_UPLOADED:
		positions.append(Vector3.ZERO); colors.append(Vector4(0, 0, 0, 1))
	for material in host.light_materials:
		material.set_shader_parameter("light_count", chosen.size())
		material.set_shader_parameter("light_positions", positions)
		material.set_shader_parameter("light_colors", colors)
	return true
