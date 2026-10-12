extends RefCounted
## Development diagnostics (docs/dev-diagnostics.md). capture() is READ-ONLY: it reads the existing player projection
## (player_continuity.gd) and a few named quest values; it never calls a save/transfer packer that writes (the Hive's
## area_handoff() stores curse.requests_enabled() into its curse checkpoint, so the Hive is read from its owners).
## record() keeps the last save/load/transfer outcome per process, including early refusals that show no message.
const Continuity = preload("res://scripts/lol2/player_continuity.gd")
const HOSTS := {
	"res://scripts/lol2/cave_walkthrough.gd": "Cave",
	"res://scripts/lol2/museum_walkthrough.gd": "Museum",
	"res://scripts/lol2/hive_review.gd": "Hive",
	"res://scripts/lol2/jungle_walkthrough.gd": "Jungle",
}
const MAX_QUEST_KEYS := 40
const MAX_LOCALS := 20
static var last_operation: Dictionary = {}

## Identify a supported host by its script or a base script (cave_encounter extends the Cave, darker_jungle the Jungle).
static func host_kind(scene: Node) -> String:
	if scene == null or not is_instance_valid(scene): return ""
	return script_kind(scene.get_script())
static func script_kind(script: Variant) -> String:
	while script is Script:
		if HOSTS.has(script.resource_path): return HOSTS[script.resource_path]
		script = script.get_base_script()
	return ""

## Record one operation outcome and return the error unchanged, so callers can wrap a return value.
static func record(host: Node, operation: String, error: String) -> String:
	var area := host_kind(host)
	last_operation = {"operation": operation, "area": area if not area.is_empty() else "unknown",
		"outcome": "ok" if error.is_empty() else "refused", "reason": error, "msec": Time.get_ticks_msec()}
	return error

static func location(scene: Node) -> Dictionary:
	var player = scene.get("player") if scene != null and is_instance_valid(scene) else null
	if not player is Node3D or not player.is_inside_tree(): return {}
	var at: Vector3 = player.position
	var translation = scene.get("native_translation")
	if translation is Vector3: at = player.global_position - translation
	return {"x": snappedf(at.x, 0.1), "y": snappedf(at.z, 0.1), "h": snappedf(at.y, 0.1)}

static func ready(scene: Node, kind: String) -> bool:
	if not scene.is_inside_tree() or not scene.is_node_ready() or not scene.get("player") is Node3D: return false
	if kind == "Cave": return bool(scene.walkthrough_ready)
	if kind == "Hive": return scene.has_node("Warriors")
	return true

## Hive player fields straight from their owners (the same fields area_handoff() would carry), without area_handoff().
static func hive_packet(hive: Node) -> Dictionary:
	var inventory: Dictionary = hive.carried_inventory.duplicate(true)
	inventory.player_form = hive.player_form
	inventory.curse = hive.curse.snapshot()
	var health: int = int(hive.get_node("Warriors").health)
	if health > 0: inventory.health = health
	else: inventory.erase("health")
	var quests := {}
	if not hive.player_magic_checkpoint.is_empty(): quests.player_magic_reward_state = hive.player_magic_checkpoint.duplicate(true)
	if not hive.player_reward_checkpoint.is_empty(): quests.player_reward_state = hive.player_reward_checkpoint.duplicate(true)
	return {"inventory": inventory, "quests": quests}

static func player_fields(scene: Node, kind: String) -> Dictionary:
	match kind:
		"Cave": return Continuity.from_packet(scene._completion_state(), {})
		"Hive":
			var packet := hive_packet(scene)
			return Continuity.from_packet(packet.inventory, packet.quests)
		_:
			var quests = scene.get("quest_state")
			return Continuity.from_packet(scene.inventory_state(), quests if quests is Dictionary else {})

## A bounded, explicit quest summary from live owners. Cave _completion_state().chamber_complete is a departure
## constant, so the Cave shows its live chamber_arrival_state instead.
static func quest_summary(scene: Node, kind: String) -> Dictionary:
	var result := {}
	var owners = null
	match kind:
		"Cave":
			result.chamber_arrival_state = str(scene.chamber_arrival_state)
			owners = scene.get("quest_state")
		"Museum":
			result.introduction_state = str(scene.introduction_state)
			owners = scene.get("quest_state")
		"Jungle":
			owners = scene.get("quest_state")
			if owners is Dictionary and owners.get("monastery") is Dictionary:
				result.monastery_room = str(owners.monastery.get("room", ""))
				result.merge(bounded(owners.monastery.get("locals", {}), "monastery.", MAX_LOCALS))
		"Hive":
			owners = scene.get("carried_quest_checkpoint")
			if is_instance_valid(scene.wax): result.hive_wax_collected = scene.wax.collected
			if scene.monastery_checkpoint is Dictionary and scene.monastery_checkpoint.get("locals") is Dictionary:
				result.merge(bounded(scene.monastery_checkpoint.locals, "monastery.", MAX_LOCALS))
	if owners is Dictionary:
		var keys: Array = owners.keys().map(func(k): return str(k))
		keys.sort()
		result.owner_count = keys.size()
		result.owners = keys.slice(0, MAX_QUEST_KEYS)
		if keys.size() > MAX_QUEST_KEYS: result.owners_truncated = keys.size() - MAX_QUEST_KEYS
	return result

## At most `limit` entries (sorted by name) as prefix+name; the number left out is shown as prefix+"truncated".
static func bounded(values: Variant, prefix: String, limit: int) -> Dictionary:
	var result := {}
	if not values is Dictionary: return result
	var keys: Array = values.keys().map(func(k): return str(k))
	keys.sort()
	for key in keys.slice(0, limit): result[prefix + key] = values[key]
	if keys.size() > limit: result[prefix + "truncated"] = keys.size() - limit
	return result

## Observed health and status from the live owner. Unlike the player projection (travel semantics: the Hive packet omits
## health at 0), this always shows the value, including zero and death.
static func vitals_from(health: Variant, source: String, dead := false) -> Dictionary:
	if not (health is int or health is float): return {"health": null, "source": source, "status": "unknown"}
	return {"health": int(health), "source": source, "status": "dead" if int(health) <= 0 or dead else "alive"}
static func vitals(scene: Node, kind: String) -> Dictionary:
	match kind:
		"Cave":
			var dead: bool = scene.drowning != null and bool(scene.drowning.dead)
			if scene.roach == null: return vitals_from(null, "no cave combat (roach)", dead)
			return vitals_from(scene.roach.model.player_health, "roach.model.player_health", dead)
		"Hive": return vitals_from(scene.get_node("Warriors").health, "Warriors.health")
		_: return vitals_from(scene.health, "health")

## Pending transfer refusal kept by a HiveRoute node (it does not show a message).
static func route_error(scene: Node) -> String:
	var route = scene.get_node_or_null("HiveRoute")
	return str(route.last_error) if route != null and route.get("last_error") != null else ""

static func capture(scene: Node) -> Dictionary:
	var report := {"captured_msec": Time.get_ticks_msec(), "area": "", "status": "no scene", "location": {}, "vitals": {}, "player": {}, "quests": {}, "last_operation": last_operation.duplicate(), "route_error": ""}
	if scene == null or not is_instance_valid(scene): return report
	var kind := host_kind(scene)
	report.area = kind if not kind.is_empty() else (scene.scene_file_path.get_file().get_basename() if not scene.scene_file_path.is_empty() else str(scene.name))
	report.location = location(scene)
	if kind.is_empty():
		report.status = "unsupported"
		return report
	if not ready(scene, kind):
		report.status = "loading"
		return report
	report.status = "ready"
	report.vitals = vitals(scene, kind)
	report.player = player_fields(scene, kind)
	report.quests = quest_summary(scene, kind)
	report.route_error = route_error(scene)
	return report

## Deterministic: the age of the last operation is measured at capture time (captured_msec), not when formatting.
static func format(report: Dictionary) -> String:
	var lines: Array[String] = ["LoL2 diagnostics | %s | %s" % [report.area if not str(report.area).is_empty() else "-", report.status]]
	var at: Dictionary = report.location
	lines.append("Location: " + ("X %.1f  Y %.1f  H %.1f" % [at.x, at.y, at.h] if not at.is_empty() else "-"))
	var op: Dictionary = report.last_operation
	if op.is_empty(): lines.append("Last operation: none this session")
	else: lines.append("Last operation: %s %s in %s%s (%.1f s before capture)" % [op.operation, op.outcome, op.area, (" — " + op.reason) if not str(op.reason).is_empty() else "", (int(report.get("captured_msec", op.msec)) - int(op.msec)) / 1000.0])
	if not str(report.route_error).is_empty(): lines.append("Route refusal: " + report.route_error)
	var vital: Dictionary = report.vitals
	if not vital.is_empty(): lines.append("Vitals: health %s, %s (%s)" % ["-" if vital.health == null else str(vital.health), vital.status, vital.source])
	if not report.player.is_empty():
		lines.append("Player:")
		var keys: Array = report.player.keys(); keys.sort()
		for key in keys: lines.append("  %s = %s" % [key, report.player[key]])
	if not report.quests.is_empty():
		lines.append("Quests:")
		var keys: Array = report.quests.keys(); keys.sort()
		for key in keys:
			var value = report.quests[key]
			lines.append("  %s = %s" % [key, ", ".join(value) if value is Array else str(value)])
	return "\n".join(lines)
