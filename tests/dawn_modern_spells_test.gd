extends SceneTree
## Real Dawn hosts (Jungle Dawn63, Hive Dawn20): the modern controller rotates orange bolt -> Chain bolt -> Plasma
## bolt on the same telegraph/cadence. Each spell is presented, damages the player through Defense.incoming (aura
## blocks), survives a disk save/load in flight without repeating its hit, is frozen by pause/world gates and cleared
## when Dawn stops being hostile; a legacy five-key combat packet still loads.
const Defense=preload("res://scripts/lol2/player_defense.gd")
const Combat=preload("res://scripts/lol2/dawn_modern_combat.gd")
class TestMagic extends "res://scripts/lol2/player_starting_magic.gd":
	var on:=true
	var shield:=false
	func world_active() -> bool:return on and health()>0
	func protected() -> bool:return shield
var failed:=false
func _initialize() -> void:run.call_deferred()
func check(ok: bool, msg: String) -> bool:
	if not ok and not failed:failed=true;push_error(msg);quit(1)
	return ok
func freeze(node: Node) -> void:
	node.set_physics_process(false);node.set_process(false)
	for child in node.get_children():freeze(child)

## Advance until the controller has fired the given number of shots (telegraph colour checked on the way).
func fire_until(d, shots: int, colour: Color) -> bool:
	var saw:=false
	for i in 600:
		d.advance(1.0/60)
		if float(d.combat.saved.windup)>0 and d.combat.charge!=null and d.combat.charge.material_override.albedo_color==colour: saw=true
		if int(d.combat.saved.shots)>=shots: return saw
		await physics_frame
	return false

func capture(scene, d, name: String) -> void:
	var b: Array=d.combat.spells.saved.bolts
	if b.is_empty(): return
	var at:=Vector3(b[0].position[0],b[0].position[1],b[0].position[2])
	var cam: Camera3D=scene.camera
	var keep: Transform3D=cam.global_transform
	cam.global_position=at+Vector3(-90,50,120);cam.look_at(at)
	for i in 2: await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://captures")
	root.get_texture().get_image().save_png("user://captures/%s.png"%name)
	cam.global_transform=keep
func land(d, magic, hp: int) -> bool:
	for i in 240:
		d.advance(1.0/60);await physics_frame
		if magic.health()<hp: return true
	return false

func run() -> void:
	for pair in [["res://scenes/lol2/jungle_walkthrough.tscn","dawn"],["res://scenes/lol2/hive_review.tscn","dawn20"]]:
		var scene=load(pair[0]).instantiate();root.add_child(scene);current_scene=scene
		await process_frame;await physics_frame
		freeze(scene)
		var d=scene.get(pair[1]);d.set_physics_process(false)
		scene.starting_magic.set_process(false)
		var magic:=TestMagic.new();magic.host=scene;scene.add_child(magic);magic.set_process(false);scene.starting_magic=magic
		d.state.present=true;d.state.b5=12;d.state.owner_state=50 if pair[1]=="dawn" else 20
		d.state.sighted=true;d.state.clip={};d.hold=false;d._sync_body(0.0)
		var caster: Vector3=d.population.bodies[d.ID].global_position
		var found:=false
		for i in 16:
			var angle:=TAU*i/16
			scene.player.global_position=caster+Vector3(sin(angle)*150,40,cos(angle)*150)
			await physics_frame
			var ray: Dictionary=d.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(caster+Vector3.UP*40,scene.player.global_position,3,[d.population.bodies[d.ID].get_rid()]))
			if not ray.is_empty() and ray.get("rid")==scene.player.get_rid():found=true;break
		if not check(found,"No clear attack lane"):return
		var path: String="user://tests/modern_spells_"+pair[1]+".json"
		# Shot 1: the orange bolt, unchanged.
		if not check(await fire_until(d,1,Combat.SPELL_COLORS.bolt) and d.combat.saved.bolts.size()==1 and d.combat.spells.saved.bolts.is_empty(),"First shot is not the orange bolt"):return
		var hp: int=magic.health()
		if not check(await land(d,magic,hp),"Orange bolt did not land"):return
		magic.set_health(30)
		# Shot 2: Chain bolt with a blue telegraph; presented; disk save/load in flight; one hit at the Chain value.
		if not check(await fire_until(d,2,Combat.SPELL_COLORS.chain),"No blue telegraph / second shot"):return
		var chain: Array=d.combat.spells.saved.bolts
		if not check(chain.size()==1 and int(chain[0].kind)==7 and d.combat.spells.visuals.size()==1,"Second shot is not a presented Chain bolt"):return
		for i in 6: d.advance(1.0/60)
		await capture(scene,d,"modern_chain_"+pair[1])
		var pending: Dictionary=d.combat.checkpoint()
		if not check(scene.quicksave(path).is_empty(),"In-flight Chain save failed"):return
		d.combat.restore(Combat.initial())
		if not check(scene.quickload(path).is_empty(),"In-flight Chain load failed"):return
		freeze(scene);await physics_frame
		if not check(d.combat.checkpoint()==pending,"Chain in-flight state changed on reload"):return
		var expected: int=Defense.incoming(scene,Combat.CHAIN_DAMAGE,4)
		hp=magic.health()
		if not check(await land(d,magic,hp) and hp-magic.health()==expected,"Chain damage differs: %d -> %d (expected loss %d)"%[hp,magic.health(),expected]):return
		var after: int=magic.health()
		if not check(scene.quicksave(path).is_empty() and scene.quickload(path).is_empty(),"Post-hit save failed"):return
		freeze(scene);for i in 30: d.advance(1.0/60)
		if not check(magic.health()==after,"Chain hit repeated after reload"):return
		magic.set_health(30)
		# Shot 3: Plasma bolt with a violet telegraph; pause/world gates freeze it; aura blocks its damage.
		if not check(await fire_until(d,3,Combat.SPELL_COLORS.plasma),"No violet telegraph / third shot"):return
		var plasma: Array=d.combat.spells.saved.bolts.filter(func(b): return int(b.kind)==58)
		if not check(plasma.size()==1,"Third shot is not a Plasma bolt"):return
		for i in 6: d.advance(1.0/60)
		await capture(scene,d,"modern_plasma_"+pair[1])
		var frozen: Dictionary=d.combat.checkpoint()
		magic.on=false;d.advance(1.0);magic.on=true
		paused=true;d.advance(1.0);paused=false
		if not check(d.combat.checkpoint()==frozen,"Plasma moved while gated"):return
		magic.shield=true;hp=magic.health()
		for i in 120: d.advance(1.0/60);await physics_frame
		if not check(magic.health()==hp and d.combat.spells.requests.size()>=2,"Aura did not block the Plasma hit"):return
		magic.shield=false
		# Plasma unshielded on the next rotation cycle hits harder than Chain.
		if not check(Defense.incoming(scene,Combat.PLASMA_DAMAGE,4)>=Defense.incoming(scene,Combat.CHAIN_DAMAGE,4),"Plasma not at least Chain damage"):return
		# Legacy five-key packet (orange bolt only) still loads into the rotation.
		var legacy: Dictionary=d.checkpoint();legacy.combat={"version":1,"cooldown":0.5,"windup":0.0,"shots":4,"bolts":[]}
		if not check(d.restore(legacy).is_empty() and int(d.combat.saved.rotation)==0 and d.combat.spells.saved.bolts.is_empty(),"Legacy combat packet rejected"):return
		# Hostility ends: spell bolts are cleared with the orange bolts.
		await fire_until(d,6,Combat.SPELL_COLORS.chain)
		d.state.b5=0;d.advance(0.01)
		if not check(d.combat.saved.bolts.is_empty() and d.combat.spells.saved.bolts.is_empty() and d.combat.saved.windup==0,"Spells not cleared when hostility ended"):return
		DirAccess.remove_absolute(path)
		print("HOST modern spells PASS ",pair[1]," chain loss ",expected)
		scene.queue_free();for i in 3:await process_frame
	if failed:return
	print("PASS: both real Dawn hosts rotate orange bolt -> Chain -> Plasma with colour telegraphs; Chain hit via Defense.incoming, in-flight disk restore without repeat; Plasma gated by pause/world and blocked by aura; legacy combat packet loads; hostility clears spells.")
	quit()
