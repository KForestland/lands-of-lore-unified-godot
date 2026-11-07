extends SceneTree
## Lever 67 -> gate 71 (L1 g12490/g12514 kind-4 use, gate 71 kind-6 value15/16 -> g12556/g12562), and the upgrade of
## saves made before the two movables were exported.
const State=preload("res://scripts/lol2/cave_guard_encounter_state.gd")
func fail(message: String) -> void:
	push_error(message);quit(1)
func _initialize() -> void:
	var src:=State.Sequence.source();var geometry:=State.Movement.source()
	if geometry.movables.size()!=10:return fail("Expected ten movables.")
	var lever:=State.Movement.record(geometry,67);var gate:=State.Movement.record(geometry,71)
	# Native constructor fields (placement bytes 34/36/37): lever as 64, gate as 70.
	if [int(lever.mode),int(lever.travel),int(lever.speed_byte)]!=[0,45,40] or [int(gate.mode),int(gate.travel),int(gate.speed_byte)]!=[0,100,60]:return fail("Motion fields.")
	var s:=State.initial(src,geometry)
	if s.movable_states["67"]!=0 or s.movable_states["71"]!=0:return fail("Initial owner states.")
	if not State.use_lever(s,src,geometry,67,0):return fail("Lever 67 refused.")
	if s.movable_states["67"]!=1 or s.movement.objects["71"].target!=100*65536 or s.movement.objects["67"].target!=45*65536:return fail("g12490 effects.")
	if s.groups.map(func(n):return int(n))!=[12490]:return fail("g12490 receipt.")
	for i in range(240):State.movement_step(s,src,geometry,65536,0)
	if s.movement.objects["71"].current!=100*65536 or s.movement.objects["71"].status!=1:return fail("Gate 71 did not finish rising.")
	if s.groups.map(func(n):return int(n))!=[12490,12556]:return fail("Raised gate must run g12556 once: "+str(s.groups))
	if not State.validate(s,src,geometry).is_empty():return fail(State.validate(s,src,geometry))
	var saved=JSON.parse_string(JSON.stringify(s));if not State.validate(saved,src,geometry).is_empty():return fail("Save roundtrip.")
	if not State.use_lever(s,src,geometry,67,0):return fail("Lever 67 back refused.")
	if s.movable_states["67"]!=0 or s.movement.objects["71"].target!=0:return fail("g12514 effects.")
	for i in range(240):State.movement_step(s,src,geometry,65536,0)
	if s.movement.objects["71"].current!=0 or s.groups.map(func(n):return int(n))!=[12490,12556,12514,12562]:return fail("Gate 71 lowering: "+str(s.groups))
	if s.pending.size()!=0:return fail("No host command may stay pending: "+str(s.pending))
	# A pre-r12m save holds the other eight movables only.
	var old:=State.initial_packet(src,geometry)
	for id in ["67","71"]:
		old.encounter.movable_states.erase(id);old.encounter.movement.objects.erase(id)
	var legacy=JSON.parse_string(JSON.stringify(old))
	if not State.validate_packet(legacy,src,geometry).is_empty():return fail("Legacy save refused.")
	if legacy.encounter.movable_states.get("67")!=0 or legacy.encounter.movement.objects.get("71",{}).get("status")!=0:return fail("Legacy upgrade values.")
	var partial=JSON.parse_string(JSON.stringify(old));partial.encounter.movable_states.erase("64")
	if State.validate_packet(partial,src,geometry).is_empty():return fail("A seven-movable bank must still be refused.")
	print("PASS lever 67 -> gate 71: g12490 raise, gate end g12556, g12514 lower, gate end g12562, no pending host command, save roundtrip, legacy eight-movable save upgraded, malformed bank refused.")
	quit()
