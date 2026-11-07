extends SceneTree
## Village Confidante hit callback on the live module (headless; supplied minimal host, not a route).
## receive_damage(id, amount) is the population-style hit callback (player_starting_magic basic Spark). Native mode1
## admits the kill group only when the hit-context dword +0x1E >= threshold 1; Grok's replay b63a4ba, rerun by Codex
## (AI_COMMS/codex_act1_review_20261025/village_dispatch), shows +0x1E 0 queues nothing and keeps the one-shot, >=1 queues
## it exactly once. Checks: amounts 0 and -3 return false and leave the whole checkpoint and the host Soul unchanged; a
## later amount 8 is admitted (local39=1, Soul-1, death segment); a second amount 8 changes nothing (one-shot 0x80).
const Live=preload("res://scripts/lol2/jungle_confidante.gd")
const State=preload("res://scripts/lol2/jungle_confidante_state.gd")
class Magic extends RefCounted:
	func movie_world_active() -> bool: return true
class Host extends Node3D:
	var starting_magic:=Magic.new()
	var native_translation:=Vector3.ZERO
	var player:=CharacterBody3D.new()
	var camera:=Camera3D.new()
	var soul:=5
var failed:=false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, msg: String) -> bool:
	if not ok and not failed: failed=true;push_error(msg);quit(1)
	return ok
func run() -> void:
	if not check(Live.assets_ready(),"Confidante media not staged"): return
	var host:=Host.new();root.add_child(host);host.add_child(host.player);host.add_child(host.camera)
	var node:=Live.new();host.add_child(node)
	var ctx:=func() -> Dictionary: return {"locals":{"6":0,"33":0},"shared":{"0":host.soul,"25":0,"29":0,"47":1}}
	var shared:=func(e: Dictionary) -> void:
		if str(e.name)=="GV_LUTHERS_SOUL": host.soul=clampi(host.soul+int(e.value),0,10)
	if not check(node.setup(host,{"context":ctx,"shared":shared}).is_empty(),"Setup"): return
	node.apply(State.sight(node.state,node.src,1465,node.context()))
	if not check(int(node.state.controls["123"].segment)==3 and node.bodies["123"].collision_layer==1,"Barrel sight must show control123"): return
	var before:=JSON.stringify(node.checkpoint())
	for amount in [0,-3]:
		if not check(not node.receive_damage("control123",amount) and JSON.stringify(node.checkpoint())==before and host.soul==5,"Amount %d must change nothing"%amount): return
	if not check(not bool(node.state.controls["123"].struck),"Rejected hit spent the one-shot"): return
	if not check(node.receive_damage("control123",8) and node.killed() and host.soul==4 and int(node.state.controls["123"].segment)==1 and int(node.state.controls["123"].owner_state)==5,"Amount 8 must kill once"): return
	var after:=JSON.stringify(node.checkpoint())
	if not check(not node.receive_damage("control123",8) and JSON.stringify(node.checkpoint())==after and host.soul==4,"Second hit must change nothing"): return
	print("PASS confidante hit callback: amounts 0/-3 rejected without mutation, 8 admitted once, one-shot kept")
	quit(0)
