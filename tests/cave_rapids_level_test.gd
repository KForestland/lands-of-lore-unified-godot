extends SceneTree
var cave
const Save=preload("res://scripts/lol2/walkthrough_save.gd")
func _initialize() -> void:run.call_deferred()
func fail(message: String) -> void:push_error(message);quit(1)
func ray_floor(row: Dictionary, exclude: Array[RID]=[]) -> Dictionary:
	var p:=Vector2.ZERO
	for q in row.polygon:p+=Vector2(q[0],q[1])/4.0
	var t: Vector3=cave.native_translation
	return cave.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(t+Vector3(p.x,-290,p.y),t+Vector3(p.x,-396,p.y),1,exclude))
func run() -> void:
	cave=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate();root.add_child(cave);current_scene=cave
	for i in range(600):
		await process_frame
		if cave.walkthrough_ready:break
	if not cave.walkthrough_ready or cave.rapids_floors==null:return fail("Cave rapids owner missing")
	cave.set_physics_process(false);Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var floors: Node3D=cave.rapids_floors
	await physics_frame;await physics_frame
	for row in floors.State.source().floors:
		var id:=str(int(row.region));var hit:=ray_floor(row)
		if hit.is_empty() or hit.collider!=floors.floors[id].body or absf(hit.position.y-cave.native_translation.y+395)>0.02:return fail("Original rapids floor collision missing "+id)
		if not ray_floor(row,[floors.floors[id].body.get_rid()]).is_empty():return fail("Duplicate static floor retained "+id)
		if floors.floors[id].meshes[0].material_override!=cave.indexed_floor_materials["310"]:return fail("Rapids animation material not shared")
	# Ordinary host physics: stand on region10, then let the rising body carry the capsule.
	var rider_row: Dictionary=floors.State.source().floors[2]
	var center:=Vector2.ZERO
	for q in rider_row.polygon:center+=Vector2(q[0],q[1])/4.0
	var old_position: Vector3=cave.player.global_position
	cave.player.global_position=cave.native_translation+Vector3(center.x,-362.9,center.y);cave.player.velocity=Vector3.ZERO
	cave.set_physics_process(true)
	for i in range(30):await physics_frame
	if not cave.player.is_on_floor():return fail("Player cannot stand on actual region10")
	cave.camera.rotation.x=deg_to_rad(-85)
	await capture("rapids_before")
	if not cave._quicksave("user://rapids_initial.json").is_empty():return fail("Initial floor save failed")
	if not cave.river_water.submerged(cave.player.global_position-cave.native_translation):return fail("Original Rapids water query missing")
	if not cave.rapids_trigger.receive_hit(1,1,1):return fail("Riding sequence start rejected")
	if cave.river_water.submerged(cave.player.global_position-cave.native_translation):return fail("Stone floor still classified as water before rising")
	for i in range(40):await physics_frame
	var native_player: Vector3=cave.player.global_position-cave.native_translation
	print("RAPIDS_RIDER native=",native_player," grounded=",cave.player.is_on_floor()," floor=",floors.state.floors["10"].height)
	if not cave.player.is_on_floor() or absf(native_player.y-(-311+32))>1.0:return fail("Rising floor did not carry standing player")
	await capture("rapids_after")
	cave.set_physics_process(false)
	if not cave._quickload("user://rapids_initial.json").is_empty():return fail("Initial floor rewind failed")
	if not cave.river_water.submerged(cave.player.global_position-cave.native_translation):return fail("Rewinding Rapids did not restore water query")
	cave.player.global_position=old_position;cave.player.velocity=Vector3.ZERO
	await physics_frame;await physics_frame
	var initial: Dictionary=floors.checkpoint()
	floors.advance(1.0,false)
	if floors.checkpoint()!=initial:return fail("Inactive floor mutated")
	# Supply an admitted hit to enter the complete shared batch; player input is not exercised here.
	if not cave.rapids_trigger.receive_hit(1,1,1):return fail("Source material/motion start rejected")
	floors.advance(1.0/120,true)
	for i in range(10):floors.advance(1.0/60,true)
	if cave.cave_local7!=0:return fail("Early local7 completion")
	var partial: Dictionary=floors.checkpoint()
	if not cave._quicksave("user://rapids_mid.json").is_empty():return fail("Main Cave rapids save rejected")
	for i in range(15):floors.advance(1.0/60,true)
	await physics_frame;await physics_frame
	if cave.cave_local7!=1:return fail("Region10 completion did not set shared local7")
	for row in floors.State.source().floors:
		var hit:=ray_floor(row);var id:=str(int(row.region))
		if hit.is_empty() or hit.collider!=floors.floors[id].body or absf(hit.position.y-cave.native_translation.y-row.target)>0.02:return fail("Raised floor collision wrong "+id)
		if floors.floors[id].meshes[0].visible or not floors.floors[id].meshes[1].visible:return fail("Material transition missing")
		var mesh: MeshInstance3D=floors.floors[id].meshes[1]
		if cave.occluder_by_source[mesh].global_transform!=mesh.global_transform:return fail("Raised floor depth mask stale")
	if not cave._quickload("user://rapids_mid.json").is_empty():return fail("Main Cave rapids load rejected")
	if floors.checkpoint()!=partial or cave.cave_local7!=0:return fail("Partial height/fraction/local bank restore differs")
	var bad: Dictionary=cave._save_state();bad.cave_local7=1
	if Save.validate(bad,cave._checkpoint_count()).is_empty():return fail("Inconsistent local7/floor packet accepted")
	bad=cave._save_state();bad.rapids_floors.state.floors["10"].height=-100
	var file:=FileAccess.open("user://rapids_invalid.json",FileAccess.WRITE);file.store_string(JSON.stringify(bad));file.close()
	if cave._quickload("user://rapids_invalid.json").is_empty() or floors.checkpoint()!=partial:return fail("Invalid floor load mutated world")
	print("PASS actual Cave original/raised floor collision without static duplicates, shared water animation, stone swap/depth masks, main save/load intermediate height/fraction/local7 and malformed-packet atomicity. Standing player carried by ordinary host physics. Control103 input and preceding effects remain separate.")
	cave.queue_free();await process_frame;await process_frame;quit()

func capture(label: String) -> void:
	for i in range(3):await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://tests")
	root.get_texture().get_image().save_png("user://tests/"+label+".png")
