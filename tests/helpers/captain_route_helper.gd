extends RefCounted
const Items=preload("res://scripts/lol2/cave_captain_items.gd")
var cave
func key(code: int, pressed: bool=true) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed
	Input.parse_input_event(event);Input.flush_buffered_events()
func healthy() -> bool:
	if cave.roach.model.player_health<=0 or cave.resets>0:return false
	if cave.roach.model.player_health<=15 and cave.player_magic_checkpoint.player.mana>=2:
		key(KEY_2);key(KEY_Q)
	return true
func walk(point: Vector2, limit: int=2400) -> bool:
	key(KEY_W)
	for i in range(limit):
		if not healthy():key(KEY_W,false);return false
		if cave.captain.intro_active():
			key(KEY_W,false)
			for wait in range(3600):
				await cave.get_tree().physics_frame
				if not cave.captain.intro_active():break
			key(KEY_W)
		var target: Vector3=Vector3(point.x,cave.player.global_position.y-cave.native_translation.y,point.y)+cave.native_translation
		cave.player.look_at(target);cave.camera.rotation=Vector3.ZERO
		await cave.get_tree().physics_frame
		var p: Vector3=cave.player.global_position-cave.native_translation
		if Vector2(p.x,p.z).distance_to(point)<18:
			key(KEY_W,false);print("WALK ",point," captain state=",cave.captain.state.source.captain.state)
			return true
	key(KEY_W,false);return false
func run(host) -> bool:
	cave=host
	for point in [Vector2(-1500,-4690),Vector2(-1845,-4674)]:
		if not await walk(point):printerr("Captain detour: "+str("plate approach "+str(point)));return false
	for i in range(3600):
		await cave.get_tree().physics_frame
		if cave.captain.state.movie_done:break
	if not cave.captain.state.movie_done:printerr("Captain detour: "+str("intro was not earned"));return false
	for point in [Vector2(-2070,-4610),Vector2(-2240,-4420),Vector2(-2300,-4330),Vector2(-2310,-4190),Vector2(-2440,-4185)]:
		if not await walk(point):printerr("Captain detour: "+str("lure approach "+str(point)));return false
	var captain=cave.captain
	var body: CharacterBody3D=cave.guard_population.bodies["56"]
	for i in range(3600):
		if not healthy():printerr("Captain detour: "+str("lure injury"));return false
		cave.camera.look_at(body.global_position+Vector3.UP*24)
		if captain.state.source.captain.state==0 and cave.guard_population.aimed()=="56":
			key(KEY_1);key(KEY_Q)
		await cave.get_tree().physics_frame
		if int(captain.state.source.captain.state)==1:break
	if int(captain.state.source.captain.state)!=1:printerr("Captain detour: "+str("source surrender admission/Spark"));return false
	for i in range(1800):
		await cave.get_tree().physics_frame
		if int(captain.state.source.captain.state)==2:break
	for use in range(2):
		cave.camera.look_at(body.global_position+Vector3.UP*24)
		await cave.get_tree().physics_frame
		key(KEY_E);await cave.get_tree().physics_frame;await cave.get_tree().physics_frame
	if Items.SWORD not in cave.carried_items() or Items.ARMOR not in cave.carried_items():printerr("Captain detour: "+str("aimed reward grants"));return false
	# Return by walked corridor to resume the ordinary first-Roach route.
	for point in [Vector2(-2310,-4190),Vector2(-2300,-4330),Vector2(-2240,-4420),Vector2(-2070,-4610),Vector2(-1500,-4690)]:
		if not await walk(point):printerr("Captain return blocked: "+str(point));return false
	print("PASS earned captain detour returned to main cave route with both rewards")
	return true
