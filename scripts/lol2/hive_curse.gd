extends Node
const State = preload("res://scripts/lol2/hive_curse_state.gd")
const Curse = preload("res://scripts/lol2/player_curse.gd")
var checkpoint := State.initial()
var regions: Array = []
func _ready() -> void:
	regions = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/hive_curse/regions.json")).regions
	restore_admission()
func restore(value: Dictionary) -> void:
	assert(State.validate(value).is_empty())
	checkpoint = State.canonical(value)

## The shared player packet owns admission; the old Hive flag is only a
## migration source for saves made before that packet carried native flags.
func restore_admission() -> void:
	var curse = get_parent().curse
	if not curse.state.has("admission_flags"): curse.set_requests_enabled(checkpoint.enabled)
	checkpoint.enabled = curse.requests_enabled()
func region_at_player() -> int:
	var host = get_parent()
	if not host.player.is_on_floor(): return int(checkpoint.region)
	var p: Vector3 = host.player.position
	for row in regions:
		var foot := p.y-32.0
		if foot < float(row.get("floor_min",row.floor))-4.0 or foot > float(row.get("floor_max",row.floor))+4.0: continue
		var polygon := PackedVector2Array()
		for point in row.polygon: polygon.append(Vector2(point[0],point[1]))
		if Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),polygon): return int(row.region)
	return -1
func _physics_process(delta: float) -> void:
	if not get_parent().curse.active(): return
	advance(delta)
func advance(delta: float) -> void:
	if not is_finite(delta) or delta < 0: return
	var host = get_parent()
	var translated := int(host.monastery_checkpoint.get("globals",{}).get("GV_RUNES_TRANSLATED",0))
	var region := region_at_player()
	var previous_region := int(checkpoint.region)
	checkpoint.enabled = host.curse.requests_enabled()
	if State.enter(checkpoint,region,translated,host.player_form):
		# Native D6B20 rejects requests while its transformation busy bit is set.
		# Existing phase1/3 is the modern warning/deferred-morph equivalent.
		if int(host.curse.state.phase) not in [1,3]: host.curse.request_human()
	# Apply the region's command24/25 after its preceding human-return command.
	if region != previous_region and (region in [392,393] or (region in [812,818] and translated==0)):
		host.curse.set_requests_enabled(checkpoint.enabled)
	if not checkpoint.running: return
	checkpoint.remaining -= delta
	while checkpoint.remaining <= 0:
		checkpoint.remaining += float(State.draw(checkpoint,120,255))
		if checkpoint.enabled:
			var chosen := Curse.choose_form(host.player_form,int(host.curse.state.previous),State.draw(checkpoint,0,2))
			var duration := State.draw(checkpoint,120,150)
			host.curse.request_timed_form(chosen,float(duration))
