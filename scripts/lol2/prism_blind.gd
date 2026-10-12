extends RefCounted
## "8-Prism" on-hit adapter (docs/prism-effects.md). Source handler7 (0x965DC) on event5 (melee hit, inference):
## draw 1..1000; the player's current region flag (+0x1C bit 0x200, enclosed) needs draw > 749 (~25%), an open
## region draw > 249 (~75%). Success binds a mode-3 effect that sends the target a 0xA-duration status (read as
## 10 s). Modern adapter: a successful landed hit with the Prism equipped BLINDS the living creature for SECONDS
## (it neither pursues nor attacks, a started attack is cancelled); a repeat success refreshes, never stacks.
## Weapon damage is unchanged. Blinds are transient combat state ({actor id: seconds left} on the population),
## like Net holds: save/load, restore and area change release them. Region flags: prism_blind_regions.json.
const ITEM := "museum:prop280:Prism"
const SECONDS := 10.0
const DRAW_MAX := 1000
const ENCLOSED_ABOVE := 749
const OPEN_ABOVE := 249
const REGIONS := "res://scripts/lol2/prism_blind_regions.json"
## Host scripts -> region table areas; any other host (e.g. the darker Jungle) has no table and counts as enclosed.
const AREAS := {"museum_walkthrough.gd": "museum", "jungle_walkthrough.gd": "jungle", "hive_review.gd": "hive", "cave_walkthrough.gd": "cave"}
const FOOT := preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
static var _table: Dictionary = {}

static func equipped(item: String) -> bool:
	return item == ITEM

static func success(draw: int, enclosed: bool) -> bool:
	return draw > (ENCLOSED_ABOVE if enclosed else OPEN_ABOVE)

static func table() -> Dictionary:
	if _table.is_empty():
		var data = JSON.parse_string(FileAccess.get_file_as_string(REGIONS))
		_table = data if data is Dictionary and data.get("version") == 1 else {"areas": {}}
	return _table

static func area_of(host: Node) -> String:
	var script: Script = host.get_script()
	return str(AREAS.get(script.resource_path.get_file(), "")) if script != null else ""

## Source region flag at a host-local source point (x, foot height, z): area default unless inside an exception.
static func enclosed_at(area: String, local: Vector3) -> bool:
	var row: Dictionary = table().areas.get(area, {})
	if row.is_empty(): return true
	for region in row.exceptions:
		if local.y < float(region.floor_min) - 4.0 or local.y > float(region.ceiling_max): continue
		var polygon := PackedVector2Array()
		for p in region.polygon: polygon.append(Vector2(p[0], p[1]))
		if Geometry2D.is_point_in_polygon(Vector2(local.x, local.z), polygon): return not bool(row.default_enclosed)
	return bool(row.default_enclosed)

## The attacking player's region, in the host's source frame (Cave hosts carry native_translation).
static func player_enclosed(host: Node) -> bool:
	var origin = host.get("native_translation")
	var local: Vector3 = host.player.global_position - (origin if origin is Vector3 else Vector3.ZERO)
	local.y -= FOOT
	return enclosed_at(area_of(host), local)

## After a landed hit: roll for a still-living target when the Prism is the equipped weapon.
## Returns the draw (1..1000), or 0 when not eligible; blinds[id] is set on success.
static func apply(blinds: Dictionary, id: String, item: String, alive: bool, rng: RandomNumberGenerator, enclosed: bool) -> int:
	if not equipped(item) or not alive: return 0
	var draw := rng.randi_range(1, DRAW_MAX)
	if success(draw, enclosed): blinds[id] = SECONDS
	return draw

static func blinded(blinds: Dictionary, id: String) -> bool:
	return float(blinds.get(id, 0.0)) > 0.0

## World time only (callers skip this while the world is paused).
static func tick(blinds: Dictionary, delta: float) -> void:
	if not is_finite(delta) or delta <= 0: return
	for id in blinds.keys():
		blinds[id] = maxf(0.0, float(blinds[id]) - delta)
		if blinds[id] <= 0.0: blinds.erase(id)

static func feedback(name: String) -> String:
	return "The Prism's light blinds the %s." % name.to_lower()

## Host feedback line: save_feedback (Jungle/Cave/Museum hosts) or the Hive interface HUD notice.
static func notify(host: Node, text: String) -> void:
	if host.has_method("save_feedback"): host.save_feedback(text)
	elif is_instance_valid(host.get("interface_hud")):
		host.interface_hud.hint.text = text
		host.interface_hud.save_notice_remaining = 2.5

static func new_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng
