extends Node
## Long arm chute softlock adapter (docs/museum-tiny-enclosure.md). Regions 957/959-966 fit a human (clearance 50-70)
## but their only exits, 958 (20) and 967 (30), admit only the tiny form. Inside the chute the shared curse refuses
## every morph except to form2 (it waits, as when there is no room), and a player who is already human or beast there
## (an older save, or a timed form that ran out) is given the held tiny form again; the duct human-return regions
## 967/1463 end it as usual. Native admission/timing for this case is unproven; this is a modern adapter.
const SOURCE := "res://scripts/lol2/museum_tiny_enclosure_source.json"
const Body = preload("res://scripts/lol2/player_form_body.gd")
const Curse = preload("res://scripts/lol2/player_curse.gd")
const TINY := 2
const MESSAGE := "The passage is too low. You shrink back into the small form."
var host: Node3D
var regions: Dictionary = {}

static func assets_ready() -> bool:
	return FileAccess.file_exists(SOURCE)

func setup(owner: Node3D) -> String:
	name = "MuseumTinyEnclosure"
	host = owner
	var source = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	if not source is Dictionary or int(source.get("version",0)) != 1 or source.get("regions",{}).size() != 9: return "Invalid Museum tiny enclosure source."
	regions = source.regions
	return ""

func inside() -> bool:
	var p: Vector3 = host.player.global_position
	var foot := p.y - Body.FOOT_OFFSET
	for row in regions.values():
		if foot < float(row.floor[0]) - 1.0 or foot > float(row.floor[1]) + 3.0: continue
		var polygon := PackedVector2Array()
		for vertex in row.polygon: polygon.append(Vector2(float(vertex[0]), float(vertex[1])))
		if Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), polygon): return true
	return false

## Shared curse hook: a pending morph waits while it would leave the player in the chute in a form that cannot exit.
func blocks(target: int) -> bool:
	return target != TINY and inside()

## Tiny form never collides where a larger form stood except the cylinder rim on the 44-degree slope, which the mover
## resolves; the shared room query would refuse the shrink everywhere on the chute slope.
func shrinks_in_place(target: int) -> bool:
	return target == TINY and inside()

func _physics_process(_delta: float) -> void:
	var curse = host.get("curse")
	if curse == null or not curse.active(): return
	rescue()

## Already human or beast inside the chute with no transformation pending: request the held tiny form (duration 0, as
## the Cave region631 held form). Bypasses admission and the nonhuman->nonhuman refusal, like the Long arm owed form.
func rescue() -> bool:
	var curse = host.curse
	if int(host.player_form) == TINY or int(curse.state.phase) != 0 or not inside(): return false
	curse.cancel_aura()
	curse.state.merge({"phase":1,"previous":int(host.player_form),"target":TINY,"remaining":Curse.WARNING_SECONDS,"duration":0.0},true)
	if host.has_method("save_feedback"): host.save_feedback(MESSAGE)
	return true
