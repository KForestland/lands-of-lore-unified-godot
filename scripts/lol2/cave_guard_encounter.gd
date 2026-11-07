extends Node3D
## Runtime controller. Caller supplies world-active gate and authoritative local7.
## Clock60Hz, camera-ray visibility and grounded polygon contact are port adapters.
## Native region navigation and crossbow world-recovery consumers remain unhosted.
const State=preload("res://scripts/lol2/cave_guard_encounter_state.gd")
const Body=preload("res://scripts/lol2/player_form_body.gd")
var src:=State.Sequence.source()
var geometry:=State.Movement.source()
var external:=State.Delayed.source()
var host: Node3D
var state: Dictionary={}
var movement: Node3D
var movie: Node3D
var delayed_voice: AudioStreamPlayer3D
var applied_pending:=0
var tick_fraction:=0.0
func setup(owner_host: Node3D, saved: Variant=null) -> String:
	host=owner_host
	var packet: Variant=State.initial_packet(src,geometry) if saved==null else saved
	var error:=validate_packet(packet)
	if not error.is_empty():return error
	movement=preload("res://scripts/lol2/cave_guard_movement.gd").new();add_child(movement)
	error=movement.setup(host.native_translation,packet.encounter.movement,host if host.has_method("_indexed_material") else null)
	if not error.is_empty():return error
	movie=preload("res://scripts/lol2/cave_guard_movie.gd").new();add_child(movie)
	error=movie.setup(src,host.camera,host.native_translation)
	if not error.is_empty():return error
	if host.get("index_view")!=null:
		var rgb:=preload("res://scripts/lol2/cave_guard_rgb_view.gd").new();add_child(rgb);rgb.setup(host,movie)
	var clip: Dictionary=external.audio["323"]
	if FileAccess.get_sha256(clip.path)!=str(clip.wav_sha256):return "Delayed guard voice hash differs."
	delayed_voice=AudioStreamPlayer3D.new();delayed_voice.stream=AudioStreamWAV.load_from_file(clip.path);delayed_voice.unit_size=160;delayed_voice.max_distance=1200
	var p: Array=external.timer.position;delayed_voice.position=host.native_translation+Vector3(p[0],p[1],p[2]);add_child(delayed_voice)
	return restore(packet)
func validate_packet(packet: Variant) -> String:
	return State.validate_packet(packet,src,geometry)
func checkpoint() -> Dictionary:
	return {"version":1,"encounter":state.duplicate(true),"applied_pending":applied_pending,"tick_fraction":tick_fraction}
func restore(packet: Variant) -> String:
	var error:=validate_packet(packet)
	if not error.is_empty():return error
	state=State.canonical(packet.encounter);applied_pending=int(packet.applied_pending);tick_fraction=float(packet.tick_fraction)
	movement.state=state.movement;movement.present();movie.voice.stop();delayed_voice.stop();present(false,true)
	return ""
func input_locked() -> bool:return not state.is_empty() and state.input_locked
func guard_visible() -> bool:
	if not state.prop_present:return false
	var point: Vector3=movie.global_position+Vector3.UP*45
	if not host.camera.is_position_in_frustum(point):return false
	# Native admission is the guard prop being drawn (prop456 kind5); the bars are drawn see-through, so Luther sees the
	# guard through closed bars 71 (longplay 12:10-12:40). The ray stands in for "drawn", so it ignores the bar bodies.
	var exclude: Array[RID]=[host.player.get_rid()];exclude.append_array(movement.bar_rids())
	var ray:=PhysicsRayQueryParameters3D.create(host.camera.global_position,point,1,exclude)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
func apply_pending() -> void:
	while applied_pending<state.pending.size():
		var row: Dictionary=state.pending[applied_pending];var b:=str(row.raw).hex_decode()
		if b[0]==2 and b[1]==1 and b[4]==32:
			if is_instance_valid(host.inventory):host.inventory.queue_free();host.inventory=null
		elif b[0]==18 and b[1]==1:
			var target: Vector3=host.native_translation+Vector3(b.decode_s16(4),b.decode_s16(8),-b.decode_s16(6))
			# Floor lookup is a port adapter. Search from the current walking elevation;
			# a ray starting at world y=0 selects an overhead floor in this stacked chamber.
			if b.decode_s16(8)==0:target.y=host.player.global_position.y-Body.FOOT_OFFSET
			var ray:=PhysicsRayQueryParameters3D.create(target+Vector3.UP*64,target-Vector3.UP*512,1,[host.player.get_rid()]);var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(ray)
			if not hit.is_empty():target.y=hit.position.y
			host.player.global_position=target+Vector3.UP*Body.FOOT_OFFSET;host.player.velocity=Vector3.ZERO
			var focus: Vector3=Vector3(movie.global_position.x,host.player.global_position.y,movie.global_position.z)
			host.player.look_at(focus);host.camera.rotation=Vector3.ZERO
		else:
			push_error("Unconsumed guard host command: "+str(row.raw));return
		applied_pending+=1
func advance(delta: float, active: bool, local7: int) -> void:
	if state.is_empty():return
	if not active or not is_finite(delta) or delta<=0:present(false);return
	var p: Vector3=host.player.global_position-host.native_translation
	State.enter(state,src,geometry,Vector2(p.x,p.z),p.y-Body.FOOT_OFFSET,host.player.is_on_floor(),int(host.player_form),local7)
	apply_pending()
	if state.sequence.phase=="armed" and guard_visible():State.rendered(state,src,geometry,local7)
	tick_fraction+=delta*60.0
	while tick_fraction>=1.0:
		tick_fraction-=1.0
		State.Delayed.advance_audio(state.delayed,1.0/60.0)
		State.timer_step(state,src,geometry,1,local7)
		State.movement_step(state,src,geometry,65536,local7)
		State.movie_step(state,src,geometry,1.0/60.0,local7)
	apply_pending();movement.state=state.movement;movement.present();present(true)
func use_lever(id: int, local7: int) -> bool:
	return State.use_lever(state,src,geometry,id,local7)
func present(active: bool, restoring: bool=false) -> void:
	movie.show_state(state.sequence,state.prop_present,active,restoring)
	var clock:=float(state.delayed.audio);var clip: Dictionary=external.audio["323"]
	if clock<0 or clock>=float(clip.samples)/float(clip.rate):delayed_voice.stop()
	elif active and (restoring or not delayed_voice.playing):delayed_voice.play(clock)
	delayed_voice.stream_paused=not active
func _exit_tree() -> void:
	if is_instance_valid(delayed_voice):delayed_voice.stop()

## Enter skips the line now playing (dialogue_skip.gd): the playing guard clip (selector) goes to its last step; the sequencer
## then moves on to the next selector (its callback group) as at the clip's natural end.
func skip_line() -> bool:
	if state.is_empty() or not active() or state.sequence.phase!="playing":return false
	var d: float=State.Sequence.duration(src,int(state.sequence.selector))
	if float(state.sequence.elapsed)>=d-1.0/4096:return false
	state.sequence.elapsed=d-1.0/4096;movie.voice.stop();return true

func active() -> bool:
	if not host.walkthrough_ready or get_tree().paused or host.flying or Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED:return false
	if host.chamber_arrival_state!="not_started" or host.drowning.dead:return false
	if host.starting_magic==null or host.starting_magic.health()<=0:return false
	if is_instance_valid(host.inventory) or is_instance_valid(host.video_overlay):return false
	if host.guard_controls!=null and host.guard_controls.input_locked():return false
	if host.captain!=null and host.captain.intro_active():return false
	return true
func target_lever() -> int:
	if not active() or input_locked():return -1
	if host.get("hand_item")!=null and str(host.hand_item)!="":return -1
	var origin: Vector3=host.camera.global_position
	var best: int=-1;var nearest:=INF
	for id in State.LEVERS:
		var body: Node3D=movement.bodies[str(id)]
		# Mounted levers can have their placement origin inside a wall. Test the
		# original face centres; never discard the wall hit or widen the aim cone.
		for local_point in movement.face_centers[str(id)]:
			var target: Vector3=body.to_global(local_point)
			var offset:=target-origin
			if offset.length()>96 or offset.length()<0.001 or (-host.camera.global_basis.z).dot(offset.normalized())<0.97:continue
			var ray:=PhysicsRayQueryParameters3D.create(origin,target,1,[host.player.get_rid()]);var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(ray)
			if not hit.is_empty() and hit.collider!=body:continue
			if offset.length()<nearest:nearest=offset.length();best=id
	return best
