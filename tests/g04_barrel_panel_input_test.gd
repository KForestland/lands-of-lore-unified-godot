extends "res://tests/g04_floor_input_test.gd"
const World=preload("res://scripts/lol2/act2_world_checkpoint.gd")
var hold_new:=false
func hold(node:Node):node.set_physics_process(false)
func arrived(node:Node):
 if hold_new and node.get_script()!=null and node.get_script().resource_path=="res://scripts/lol2/act2_progression.gd":node.ready.connect(hold.bind(node),CONNECT_ONE_SHOT)
func run():
 node_added.connect(arrived)
 var input:="res://tests/fixtures/g04_inputs/l10_barrel_switch_legacy.json"
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/g04_inputs/manifest.json"))
 var pin:Array=manifest.inputs.filter(func(row):return row.file=="l10_barrel_switch_legacy.json")
 if not check(pin.size()==1 and FileAccess.get_sha256(input)==pin[0].sha256,"Immutable existing barrel-switch checkpoint"):return
 var incoming:=preload("res://scripts/lol2/act2_save.gd").read_save(input,"lol2-restoration-map-L10_DC")
 scene=load("res://scenes/lol2/maps/L10_DC.tscn").instantiate();scene.adapter_exit_seeds=false
 root.add_child(scene);current_scene=scene;await settled()
 if not check(incoming.error.is_empty() and scene.apply_save(incoming.state).is_empty(),"Existing actual switch packet applies"):return
 scene.set_physics_process(true)
 await ticks(12);scene.set_physics_process(false)
 if not check(scene.quest_state.l10_barrel.switch and scene.player.is_on_floor(),"Existing switch is open and player grounded"):return
 var limit:Dictionary=World.mover_limits("L10_DC")["74"]
 var pose:Transform3D=scene.progression.hinges[74].transform
 if not check(pose.origin.y>limit.origin.y and World.mover_error(World.encode(pose),limit).is_empty(),"Actual source owner withdraws panel74 upward and save admits it"):return
 await key(KEY_F5)
 var read:=Saves.read_document(Saves.slot_path(1))
 if not check(read.error.is_empty() and read.state.area=="L10_DC" and read.state.area_save.quests.get("l10_barrel",{}).get("switch",false),"ActualF5 writes barrel owner and physical panel"):return
 var expected:Transform3D=World.decode(read.state.native_bank.L10_DC.world.movers["74"])
 hold_new=true
 if not await reload():return
 if not check(scene.progression.hinges[74].transform.is_equal_approx(expected) and scene.quest_state.l10_barrel.switch,"ActualF9 restores exact upward panel before first mover tick"):return
 print("PASS game-written switch checkpoint, realF5/F9 preserves barrel panel74 upward owner pose; held host/creatures, not an earned walk")
 quit()
