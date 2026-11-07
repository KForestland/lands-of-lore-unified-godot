extends SceneTree
## Owner F10 2026-11-03 17:35:21 "no sound from the guy" (Kelsrick), 17:48:05 "dawn do not speak no sound", 17:55:37
## "cant hear what he says" (Bacatta). Their voice players kept AudioStreamPlayer3D's default unit_size 10: with the
## inverse-distance model a line spoken 150 units away played about 20*log10(150/10) = 23.5 dB down, while the
## Confidante, Kit'yara and the drunk use 300. Headless, real hosts: every Jungle/Hive talker voice has the shared speech
## reach (>= 120, the smallest reach any talker used before) and Kelsrick/Dawn/Bacatta/Dawn20 use VOICE_UNIT_SIZE.
const REACH:=preload("res://scripts/lol2/jungle_kelsrick.gd").VOICE_UNIT_SIZE
var failed:=false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, msg: String) -> bool:
	if not ok and not failed: failed=true;push_error("FAIL: "+msg);quit(1)
	return ok
func boot(path: String) -> Node:
	set_meta("lol2_jungle_handoff",{"collected":[],"equipped_item":"","equipped_armor":""})
	var scene: Node=load(path).instantiate();root.add_child(scene);current_scene=scene
	for i in 1500:
		await process_frame
		if scene.get("ready_for_review") or scene.get("walkthrough_ready")==true: break
	return scene
func run() -> void:
	var jungle: Node=await boot("res://scenes/lol2/jungle_walkthrough.tscn")
	var players:={"kelsrick":jungle.kelsrick.voice,"dawn":jungle.dawn.voice,"kityara":jungle.kityara.voice,"drunk":jungle.drunk.voice,
		"bacatta65":jungle.bacatta65.voice,"actor62":jungle.actor62.voice,"exit_woman":jungle.exit_woman.voice,"confidante123":jungle.confidante.voices["123"],"confidante112":jungle.confidante.voices["112"]}
	for owner in jungle.bacatta.voices: players["bacatta:"+str(owner)]=jungle.bacatta.voices[owner]
	for name in players:
		var p: AudioStreamPlayer3D=players[name]
		if not check(p!=null and p.attenuation_model==AudioStreamPlayer3D.ATTENUATION_DISABLED,"%s voice fades with distance"%name): return
		if not check(p!=null and p.unit_size>=120.0,"%s voice unit_size %s"%[name,p.unit_size if p!=null else -1.0]): return
	for name in ["kelsrick","dawn","bacatta:bacatta"]:
		if not check(is_equal_approx(players[name].unit_size,REACH),"%s voice reach %s != %s"%[name,players[name].unit_size,REACH]): return
	var count:=players.size()
	players.clear()
	jungle.queue_free();await process_frame;await process_frame
	var hive: Node=await boot("res://scenes/lol2/hive_review.tscn")
	if not check(hive.dawn20!=null and is_equal_approx(hive.dawn20.voice.unit_size,REACH),"Hive Dawn20 voice reach"): return
	hive.queue_free();await process_frame;await process_frame
	print("PASS npc_voice_reach_test: %d Jungle talker voices >= 120 and Hive Dawn20 (Kelsrick, Dawn, Bacatta, Dawn20 at %s)"%[count,REACH])
	quit()
