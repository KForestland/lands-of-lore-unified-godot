extends SceneTree
## Owner F10 r12l 2026-10-28 15:20:52 ("and died here"): no crate-room Roach may start inside a solid scenery box of
## static_collision_L1_DC (its 6-radius body against each box, in the box's heading frame), and only the two cleared
## spawns differ from the source.
const State=preload("res://scripts/lol2/cave_roach_population_state.gd")
const Assemblies=preload("res://scripts/lol2/static_assemblies.gd")
const BODY_RADIUS:=6.0
var failures:=0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1;push_error(message)
func _initialize() -> void:
	var boxes: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/static_collision_L1_DC.json")).boxes
	var source: Array=JSON.parse_string(FileAccess.get_file_as_string(State.SOURCE)).actors
	var state:=State.initial()
	for row in source:
		var id:=str(int(row.actor))
		var p: Array=state.actors[id].position
		if State.SPAWN_CLEAR.has(id): check(p==State.SPAWN_CLEAR[id] and p!=row.position,"Roach %s starts at its cleared spawn" % id)
		else: check(p==row.position,"Roach %s keeps its source spawn" % id)
		for key in boxes:
			var b: Dictionary=boxes[key]
			if int(b.get("mode",2))==3 or float(b.height)<Assemblies.MIN_SOLID_HEIGHT: continue
			if float(p[1])>=float(b.h)+float(b.height) or float(p[1])+12.0<=float(b.h): continue
			var local: Vector3=Basis(Vector3.UP,-float(b.heading)/65536.0*TAU).inverse()*Vector3(float(p[0])-float(b.x),0,float(p[2])+float(b.y))
			var inside: bool=absf(local.x)<float(b.width)/2.0+BODY_RADIUS and absf(local.z)<maxf(float(b.depth),1.0)/2.0+BODY_RADIUS
			check(not inside,"Roach %s starts inside scenery box %s" % [id,key])
	if failures:
		push_error("FAIL: %d crate spawn checks" % failures);quit(1);return
	print("PASS cave Roach crate spawns: no Roach starts inside a solid scenery box; only actors 33/34 are moved")
	quit()
