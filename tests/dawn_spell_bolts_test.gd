extends SceneTree
## Modern Chain/Plasma bolts in a real physics world: hops in nearest order with one request per hop, hop limit and
## cycle fill, wall ends a chain, Plasma hit and bystander type filter, caster pass-through, save/load mid-flight,
## malformed state rejected, visuals follow the live bolts.
const Bolts=preload("res://scripts/lol2/dawn_spell_bolts.gd")
var world: Node3D
var bolts
var bodies: Dictionary={}
var failed:=false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, msg: String) -> bool:
	if not ok and not failed: failed=true;push_error(msg);quit(1)
	return ok

func body(key: String, at: Vector3, type: int=2, layer: int=2) -> void:
	var b:=StaticBody3D.new();b.collision_layer=layer;b.collision_mask=0
	var s:=CollisionShape3D.new();var sh:=SphereShape3D.new();sh.radius=18;s.shape=sh;b.add_child(s)
	world.add_child(b);b.global_position=at;bodies[key]={"body":b,"point":at,"type":type,"valid":true}

func wall(at: Vector3) -> void:
	var b:=StaticBody3D.new();b.collision_layer=1
	var s:=CollisionShape3D.new();var sh:=BoxShape3D.new();sh.size=Vector3(10,200,400);s.shape=sh;b.add_child(s)
	world.add_child(b);b.global_position=at

func fresh() -> void:
	if world!=null: world.queue_free();await process_frame
	world=Node3D.new();root.add_child(world);bodies={}
	bolts=Bolts.new();world.add_child(bolts)
	bolts.targets=func(): return bodies

func play(seconds: float) -> void:
	for i in int(seconds*60): bolts.advance(1.0/60.0);await physics_frame

func run() -> void:
	# 1. Chain: caster at origin, three creatures east; nearest first; 3 hops (draw 0).
	await fresh()
	body("dawn",Vector3(0,40,0));body("a",Vector3(300,40,0));body("b",Vector3(500,40,40));body("c",Vector3(700,40,-40))
	bolts.exclude=[bodies.dawn.body.get_rid()]
	await physics_frame;await physics_frame
	var id: int=bolts.cast_chain("dawn",Vector3(0,40,0),"a",0)
	if not check(id==1 and bolts.visuals.size()==1,"Chain not cast"):return
	await play(4.0)
	var hops: Array=bolts.requests.map(func(r): return r.to)
	if not check(hops==["a","b","c"] and bolts.requests.all(func(r): return r.amount==10 and r.mask==0x11 and r.subtype==0x54 and r.source=="dawn"),"Chain hops differ: %s"%[hops]):return
	await play(1.0)
	if not check(bolts.saved.bolts.is_empty() and bolts.visuals.is_empty(),"Chain bolt not retired"):return
	# 2. Fewer creatures than hops cycles the list (original fill rule): a,b,a for limit 3.
	await fresh()
	body("dawn",Vector3(0,40,0));body("a",Vector3(300,40,0));body("b",Vector3(450,40,0))
	bolts.exclude=[bodies.dawn.body.get_rid()];await physics_frame;await physics_frame
	bolts.cast_chain("dawn",Vector3(0,40,0),"a",0);await play(5.0)
	if not check(bolts.requests.map(func(r): return r.to)==["a","b","a"],"Cycle fill differs: %s"%[bolts.requests.map(func(r): return r.to)]):return
	# 3. A wall ends the chain without a hit.
	await fresh()
	body("dawn",Vector3(0,40,0));body("a",Vector3(300,40,0));wall(Vector3(150,40,0))
	bolts.exclude=[bodies.dawn.body.get_rid()];await physics_frame;await physics_frame
	bolts.cast_chain("dawn",Vector3(0,40,0),"a",95);await play(2.0)
	if not check(bolts.requests.is_empty() and bolts.saved.bolts.is_empty(),"Wall did not end the chain"):return
	# 4. Plasma: one hit on the target; a prop-type bystander in the way absorbs it harmlessly, a creature takes it.
	await fresh()
	body("dawn",Vector3(0,40,0));body("player",Vector3(400,40,0),2)
	bolts.exclude=[bodies.dawn.body.get_rid()];await physics_frame;await physics_frame
	bolts.cast_plasma("dawn",Vector3(0,40,0),"player");await play(2.5)
	if not check(bolts.requests.size()==1 and bolts.requests[0].to=="player" and bolts.requests[0].subtype==0x3A and bolts.requests[0].amount==10,"Plasma hit differs: %s"%[bolts.requests]):return
	await fresh()
	body("dawn",Vector3(0,40,0));body("player",Vector3(400,40,0),2);body("crate",Vector3(200,40,0),5)
	bolts.exclude=[bodies.dawn.body.get_rid()];await physics_frame;await physics_frame
	bolts.cast_plasma("dawn",Vector3(0,40,0),"player");await play(2.5)
	if not check(bolts.requests.is_empty(),"Plasma damaged a non-creature bystander"):return
	await fresh()
	body("dawn",Vector3(0,40,0));body("player",Vector3(400,40,0),2);body("guard",Vector3(200,40,0),2)
	bolts.exclude=[bodies.dawn.body.get_rid()];await physics_frame;await physics_frame
	bolts.cast_plasma("dawn",Vector3(0,40,0),"player");await play(2.5)
	if not check(bolts.requests.size()==1 and bolts.requests[0].to=="guard","Plasma bystander creature not hit"):return
	# 5. Save/load mid-flight continues identically; malformed state is rejected atomically.
	await fresh()
	body("dawn",Vector3(0,40,0));body("player",Vector3(800,40,0),2)
	bolts.exclude=[bodies.dawn.body.get_rid()];await physics_frame;await physics_frame
	bolts.cast_plasma("dawn",Vector3(0,40,0),"player");await play(0.5)
	var saved: Dictionary=JSON.parse_string(JSON.stringify(bolts.checkpoint()))
	await play(0.5)
	if not check(bolts.restore(saved).is_empty() and bolts.visuals.size()==1,"Restore failed"):return
	var bad:=saved.duplicate(true);bad.bolts[0].life=99
	var before: Dictionary=bolts.checkpoint()
	if not check(not bolts.restore(bad).is_empty() and bolts.checkpoint()==before,"Malformed state applied"):return
	await play(3.0)
	if not check(bolts.requests.size()==1 and bolts.requests[0].to=="player","Restored Plasma did not land once"):return
	# 6. Lead review boundaries (J): a save taken inside the health callback is post-hit (no replay); proximity arrival
	# does not hit through a near wall; fractional identities are rejected.
	await fresh()
	body("dawn",Vector3(0,40,0));body("player",Vector3(300,40,0))
	bolts.exclude=[bodies.dawn.body.get_rid()];await physics_frame;await physics_frame
	var captured: Array=[{}]
	bolts.deliver=func(_r): captured[0]=bolts.checkpoint()
	bolts.cast_plasma("dawn",Vector3(275,40,0),"player");bolts.advance(1.0/60.0)
	var count:int=bolts.requests.size()
	if not check(count==1 and bolts.restore(captured[0]).is_empty(),"Callback checkpoint restore failed"):return
	await play(1.0)
	if not check(bolts.requests.size()==count,"Restoring a callback checkpoint repeated the hit"):return
	await fresh()
	body("dawn",Vector3(0,40,0));body("player",Vector3(300,40,0));wall(Vector3(285,40,0))
	bolts.exclude=[bodies.dawn.body.get_rid()];await physics_frame;await physics_frame
	bolts.cast_plasma("dawn",Vector3(270,40,0),"player");await play(1.0)
	if not check(bolts.requests.is_empty(),"Proximity arrival hit through a wall"):return
	var frac:=Bolts.initial();frac.next_id=1.5
	if not check(not Bolts.validate(frac).is_empty(),"Fractional identity accepted"):return
	# 7. A wall right behind the creature just struck still stops the chain (struck body excluded from the sweep,
	# not skipped after the fact); a bystander creature is hit once, not re-contacted.
	await fresh()
	body("dawn",Vector3(0,40,0));body("a",Vector3(300,40,0));body("b",Vector3(600,40,0));wall(Vector3(330,40,0))
	bolts.exclude=[bodies.dawn.body.get_rid()];await physics_frame;await physics_frame
	bolts.cast_chain("dawn",Vector3(0,40,0),"a",95);await play(3.0)
	if not check(bolts.requests.map(func(r): return r.to)==["a"],"Chain passed a wall behind its struck target: %s"%[bolts.requests.map(func(r): return r.to)]):return
	await fresh()
	body("dawn",Vector3(0,40,0));body("a",Vector3(600,40,0));body("guard",Vector3(300,40,0))
	bolts.exclude=[bodies.dawn.body.get_rid()];await physics_frame;await physics_frame
	bolts.cast_chain("dawn",Vector3(0,40,0),"a",95);await play(4.0)
	var to: Array=bolts.requests.map(func(r): return r.to)
	if not check(to.count("guard")<=2 and to[0]=="guard" and to.has("a") and not (to.size()>1 and to[1]=="guard"),"Bystander re-contacted: %s"%[to]):return
	world.queue_free();await process_frame
	if failed: return
	print("PASS dawn spell bolts: chain hops a->b->c (10 each) then retires, cycle fill a,b,a, wall ends chain, Plasma single hit, prop bystander absorbs, creature bystander hit, caster pass-through, save/load mid-flight, malformed rejected; J review: callback checkpoint no replay, no hit through near wall, fractional ids rejected; wall behind struck target stops chain; bystander not re-contacted.")
	quit()
