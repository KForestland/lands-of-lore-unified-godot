extends SceneTree
const Binder = preload("res://scripts/lol2/act2_progression.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1;print("FAIL arrival adapter: ",message)
func _initialize(): run.call_deferred()
func run():
	for row in [[8,1,"local",13,1],[14,1,"local",22,1],[17,1,"local",0,10],[19,1,"e58",52,0],[19,2,"e58",52,1],[9,1,"object",0,2]]:
		for enabled in [false,true]:
			set_meta("lol2_level_change",true)
			set_meta("lol2_map_start_selector",int(row[1]))
			var scene=load(Binder.LEVEL_SCENES[int(row[0])]).instantiate()
			scene.adapter_exit_seeds=enabled
			root.add_child(scene)
			scene.set_physics_process(false)
			var p=scene.progression
			p.set_physics_process(false)
			p.change_scene_enabled=false
			var value: int
			if row[2]=="local": value=int(p.native.locals.get(int(row[3]),-1))
			elif row[2]=="e58": value=int(p.native.locals_e58.get(int(row[3]),-1))
			else: value=p.native.field("control:82","byte_0x25",-1)
			check(value==int(row[4]) if enabled else p.seeds_applied.is_empty(),"L%d/%d flag%s value%d" % [row[0],row[1],enabled,value])
			if int(row[0])==19:
				p.enter_region(2369)
				check(p.level_changes.size()==1 if enabled else p.level_changes.is_empty(),"native conditional branch retained")
				if enabled: check(int(p.level_changes[0].selector)==int(row[1]),"entry/return chooses corresponding native edge")
			scene.queue_free();await process_frame
	if failures==0:print("PASS arrival-only predicate adapters ON/OFF, original conditional evaluation retained")
	quit(0 if failures==0 else 1)
