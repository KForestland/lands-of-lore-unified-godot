extends "res://tests/autosave_play_clock_test.gd"
## F18 boundary probes: the production drowning state/controller is supplied at a dry
## live pose to expose frame-order stale flags. No claim of walking into water.
const Liquid=preload("res://scripts/lol2/liquid_drowning.gd")
const Drowning=preload("res://scripts/lol2/river_drowning_state.gd")
const Admission=preload("res://scripts/lol2/save_admission.gd")
class CaveAdmissionProbe extends Node3D:
	var starting_magic:Node
	var player:CharacterBody3D
	var walkthrough_ready:=true
	var flying:=false
	var drowning=preload("res://scripts/lol2/river_drowning_state.gd").new()
func run()->void:
	locate_proof()
	assert(OS.get_environment("LOL2_PRIVATE_SAVE_CASE")=="1" and "--no-autosave" not in OS.get_cmdline_user_args())
	session=Session.for_tree(self);session.set_process(false)
	scene=load("res://scenes/lol2/maps/L10_DC.tscn").instantiate();root.add_child(scene);current_scene=scene;await settled()
	session.advance_play(0.0);await ticks(2);session.advance_play(0.0);await finish_write()
	assert(session.autosave_writes==1 and scene.can_save().is_empty())
	var safe:=FileAccess.get_file_as_bytes(Save.slot_path(0))
	var liquid:=Liquid.new();liquid.host=scene;liquid.set_physics_process(false);scene.add_child(liquid);scene.liquid_drowning=liquid
	assert(liquid.polygon_at(scene.player.position).is_empty(),"dry boundary probe must not be blocked by geometry")
	session.advance_play(599.99)
	liquid.drowning.advance(1.0,true)
	assert(liquid.drowning.active and not liquid.drowning.dead and scene.starting_magic.health()>0)
	assert(not scene.can_save().is_empty(),"active liquid drowning must reject save even before geometry catches up")
	session.advance_play(0.02)
	assert(not session.save_in_progress() and session.autosave_writes==1)
	assert(not Save.autosave(scene,"timer").is_empty())
	assert(FileAccess.get_file_as_bytes(Save.slot_path(0))==safe,"drowning preserves the usable autosave")
	liquid.drowning.advance(Drowning.LIMIT,true)
	assert(liquid.drowning.dead and not scene.can_save().is_empty())
	session.advance_play(601.0)
	assert(not session.save_in_progress() and session.autosave_writes==1)
	assert(not Save.autosave(scene,"arrival").is_empty())
	assert(FileAccess.get_file_as_bytes(Save.slot_path(0))==safe)
	liquid.drowning.reset()
	session.advance_play(5.01);await finish_write()
	assert(session.autosave_writes==2 and session.last_autosave_reason=="timer","pending timer retries after safety returns")
	assert(FileAccess.get_file_as_bytes(Save.backup_path(0))==safe)
	# Cave owns its state directly rather than through LiquidDrowning; same safety rule.
	var cave:=CaveAdmissionProbe.new();cave.starting_magic=scene.starting_magic;cave.player=scene.player;root.add_child(cave)
	assert(Admission.reason(cave).is_empty())
	cave.drowning.advance(1.0,true)
	assert(not Admission.reason(cave).is_empty(),"Cave active drowning rejects saving")
	cave.drowning.advance(Drowning.LIMIT,true)
	assert(not Admission.reason(cave).is_empty(),"Cave dead drowning rejects saving")
	cave.drowning.reset();assert(Admission.reason(cave).is_empty());cave.free()
	var receipt:={"passed":true,"scope":"injected boundary states at dry live pose; not an earned water walk","liquid_active_refused":true,"liquid_dead_refused":true,"cave_active_refused":true,"cave_dead_refused":true,"good_autosave_preserved":true,"safe_retry":true,"backup_preserved":true,"health":scene.starting_magic.health(),"resets":scene.resets}
	var f:=FileAccess.open(proof+"/receipt.json",FileAccess.WRITE);f.store_string(JSON.stringify(receipt,"  "));f.close()
	print("PASS F18 active/dead liquid drowning and Cave-owned drowning refuse snapshots; safe bytes retained; pending600s retries at safety; backup remains usable")
	scene.free();scene=null;current_scene=null
	await process_frame
	quit()
