extends SceneTree
const Curse = preload("res://scripts/lol2/player_curse.gd")
const Body = preload("res://scripts/lol2/player_form_body.gd")
class Host extends Node3D:
	var player_form := 0
	var health := 7
	var player := CharacterBody3D.new()
	var camera := Camera3D.new()
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var host := Host.new()
	root.add_child(host)
	host.player.add_child(CollisionShape3D.new())
	host.add_child(host.player)
	host.player.add_child(host.camera)
	host.player.position.y = 32.1
	Body.apply(host.player,host.camera,0,false)
	var curse := Curse.new()
	host.add_child(curse)
	curse.set_physics_process(false)
	# Script admission is saved independently of pending morph clocks. Disabling
	# new requests cannot consume RNG or erase a previously accepted request.
	curse.set_requests_enabled(false)
	var denied := curse.snapshot()
	assert(not curse.request_cave_curse() and not curse.request_timed_form(2,120) and not curse.request_human())
	assert(curse.snapshot()==denied)
	curse.restore(JSON.parse_string(JSON.stringify(denied)))
	assert(not curse.requests_enabled() and Curse.valid(curse.snapshot(),0))
	for flags in [-1,1,17,49,256,0.5,"48",NAN]:
		var malformed:=denied.duplicate(true);malformed.admission_flags=flags
		assert(not Curse.valid(malformed,0))
	curse.restore(Curse.initial())
	curse.restore_legacy_dawn_admission(["020100002500"])
	assert(not curse.requests_enabled())
	curse.restore(Curse.initial())
	curse.restore_legacy_dawn_admission(["020100002500","020100002400"])
	assert(curse.requests_enabled())
	curse.set_requests_enabled(false)
	curse.restore_legacy_dawn_admission(["020100002400"])
	assert(not curse.requests_enabled(),"Historical receipts cannot overwrite modern saved admission")
	curse.restore(Curse.initial())
	curse.state.seed = 2 # Reproducible restoration RNG fixture: lizard first.
	var before_request := curse.snapshot()
	assert(curse.request_cave_curse())
	assert(curse.state.target == 2 and curse.state.duration >= 60 and curse.state.duration <= 90)
	assert(not curse.request_cave_curse())
	var original := curse.snapshot()
	curse.restore(before_request)
	assert(curse.request_cave_curse())
	assert(curse.snapshot() == original,"Restoring before contact preserves form and duration draws")
	assert(Curse.valid(original,0))
	curse.set_requests_enabled(false)
	curse.advance(-1)
	var gated_original:=original.duplicate(true);gated_original.admission_flags=0
	assert(curse.snapshot() == gated_original)
	curse.advance(Curse.WARNING_SECONDS)
	assert(host.player_form == 2 and curse.state.phase == 2)
	assert(host.health == 30,"Successful morph must restore full health")
	assert(not curse.requests_enabled(),"Pending transformation must preserve disabled requests")
	host.health = 7
	assert(Curse.valid(curse.snapshot(),2))
	var roof := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100,10,100)
	collider.shape = box
	roof.add_child(collider)
	host.add_child(roof)
	roof.position = Vector3(150,25,0)
	await physics_frame
	await physics_frame
	host.player.position.x = 150
	curse.advance(100)
	assert(host.player_form == 2 and curse.state.phase == 3)
	assert(Curse.valid(curse.snapshot(),2))
	var blocked := curse.snapshot()
	curse.advance(10)
	assert(curse.snapshot() == blocked)
	assert(host.health == 7,"Blocked morph must not heal")
	host.player.position.x = 0
	curse.advance(0)
	assert(host.player_form == 0 and curse.state.phase == 0)
	assert(host.health == 30,"Human return must restore health")
	host.health = 5
	curse.restore(curse.snapshot())
	assert(host.health == 5,"Loading curse state must not heal")
	assert(Curse.valid(curse.snapshot(),0))
	assert(not curse.request_cave_curse(),"Completed cave flag survives return")
	for field in ["phase","previous","target","remaining","duration","seed"]:
		var bad := original.duplicate(true)
		bad[field] = NAN
		assert(not Curse.valid(bad,0))
	var bad := original.duplicate(true)
	bad.previous = 2
	assert(not Curse.valid(bad,0))
	curse.restore(Curse.initial())
	assert(not curse.request_timed_form(2,151))
	assert(curse.request_timed_form(2,150))
	assert(Curse.valid(curse.snapshot(),0))
	curse.advance(Curse.WARNING_SECONDS)
	assert(host.player_form == 2 and Curse.valid(curse.snapshot(),2))
	assert(not curse.request_timed_form(1,120),"Native admission rejects nonhuman to nonhuman")
	assert(curse.request_human())
	curse.advance(0)
	assert(host.player_form == 0 and Curse.valid(curse.snapshot(),0))
	# A grounded saved pose may sit just below the support plane. That contact
	# must not prevent a smaller form; genuine floor/ceiling overlap still blocks.
	var floor_body := StaticBody3D.new()
	var floor_collider := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(100,10,100)
	floor_collider.shape = floor_box
	floor_body.add_child(floor_collider)
	host.add_child(floor_body)
	floor_body.position.y = -5
	host.player.safe_margin = 0.05
	host.player.position = Vector3(0,32.1,0)
	Body.apply(host.player,host.camera,1,false)
	for tick in range(30):
		await physics_frame
		host.player.velocity = Vector3(0,-10,0)
		host.player.move_and_slide()
	assert(host.player.is_on_floor())
	host.player.position.y = 31.99965
	assert(Body.apply(host.player,host.camera,0),"Support-plane precision must not trap the saved beast form")
	host.player.position.y = 31.8
	assert(not Body.apply(host.player,host.camera,0),"Meaningful floor penetration remains rejected")
	host.player.position.y = 31.99965
	roof.position = Vector3(0,50,0)
	await physics_frame
	await physics_frame
	assert(not Body.apply(host.player,host.camera,0),"Foot tolerance must not reduce required ceiling clearance")
	host.free()
	print("PASS curse: deterministic selection, one-time flag, warning, timed lizard, blocked return and retry, state validation")
	quit()
