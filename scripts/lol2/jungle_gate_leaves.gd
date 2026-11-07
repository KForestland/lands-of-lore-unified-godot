extends Node3D
## Live village gate-leaf consumer on the Jungle host (jungle_gate_leaves_state.gd). It removes broken leaves from the
## village gate (no mesh, no collision), draws the linked fallen leaf (controls 80/81, template74 faces with original
## materials 514/742), plays original sound452 (jugcrash) at control81, and runs regions 588/3895/3896/3897 relinks.
## Producer: the owner-approved modern "Force gate" E action (2026-10-25): aimed at a closed, reachable, unoccluded leaf,
## it supplies the gate context mask0 0x0800 with after-durability 0 (before = source durability 5) to the source consumer.
## It is not the original sword/Spark path and computes no damage; the native 0x0800 producer is untraced. Without
## predicate196 (Killed_Confidante and the Huline alert) it only shows a hint. A carried held item is put away first and
## is never consumed; the hand is restored if nothing happens.
const State=preload("res://scripts/lol2/jungle_gate_leaves_state.gd")
const MEDIA:="res://assets/lol2/generated/jungle_gate_leaves/"
const REACH:=110.0
var host: Node3D
var hooks: Dictionary={}
var src: Dictionary
var state: Dictionary
var inside: Array=[]
var panels: Dictionary={}
var crash: AudioStreamPlayer3D
var effects_log: Array=[]

static func assets_ready() -> bool:
	return FileAccess.file_exists(State.SOURCE) and FileAccess.file_exists(MEDIA+"sounds/452.wav") and FileAccess.file_exists(MEDIA+"material_0514.png") and FileAccess.file_exists(MEDIA+"material_0742.png")

func setup(owner_host: Node3D, supplied_hooks: Dictionary={}, saved: Variant=null) -> String:
	host=owner_host;hooks=supplied_hooks;src=State.source()
	var materials:={}
	for c in State.CONTROLS:
		var mesh:=ArrayMesh.new()
		for face in src.controls[c].faces:
			if not materials.has(face.material):
				var m:=StandardMaterial3D.new();m.albedo_texture=ImageTexture.create_from_image(Image.load_from_file(MEDIA+str(face.material)))
				m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;m.cull_mode=BaseMaterial3D.CULL_DISABLED
				m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR;materials[face.material]=m
			var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_material(materials[face.material])
			for i in [0,1,2,0,2,3]:
				var p: Array=face.vertices[i];st.set_uv(Vector2(face.uv[i][0],face.uv[i][1]));st.add_vertex(Vector3(p[0],p[1],p[2]))
			st.commit(mesh)
		var node:=MeshInstance3D.new();node.mesh=mesh;node.name="FallenLeaf%s"%c;add_child(node);panels[c]=node
	crash=AudioStreamPlayer3D.new();crash.stream=AudioStreamWAV.load_from_file(MEDIA+"sounds/452.wav");crash.unit_size=300;add_child(crash)
	return restore(saved if saved!=null else initial())

func initial() -> Dictionary: return {"version":1,"state":State.initial(src),"inside":[]}
func checkpoint() -> Dictionary: return {"version":1,"state":state.duplicate(true),"inside":inside.duplicate()}
static func validate(packet: Variant) -> String:
	if not packet is Dictionary or packet.size()!=3 or not (packet.get("version") is int or packet.get("version") is float) or float(packet.version)!=1.0: return "Invalid gate leaf packet."
	var src:=State.source()
	var error:=State.validate(packet.get("state"),src)
	if not error.is_empty(): return error
	if not packet.get("inside") is Array: return "Invalid gate leaf region history."
	for id in packet.inside:
		if not (id is int or id is float) or not src.relink.has(str(int(id))) or float(id)!=floor(float(id)) or packet.inside.count(id)!=1: return "Invalid gate leaf region."
	return ""

## Atomic: an invalid packet changes nothing.
func restore(packet: Variant) -> String:
	var error:=validate(packet)
	if not error.is_empty(): return error
	state=State.canonical(packet.state);inside=packet.inside.map(func(r): return int(r))
	present();return ""

func origin() -> Vector3:
	var value=host.get("native_translation")
	return value if value is Vector3 else Vector3.ZERO
func context() -> Dictionary:
	if hooks.has("context") and hooks.context is Callable and hooks.context.is_valid():
		var value=hooks.context.call()
		if value is Dictionary: return value
	return {"locals":{},"shared":{}}
func linked(leaf: int) -> bool: return state.is_empty() or State.linked(state,leaf)

func apply(effects: Array) -> void:
	for e in effects:
		effects_log.append(e)
		if str(e.type)=="sound" and int(e.request)==int(src.sound.request):
			var p: Array=src.controls[str(int(src.sound.object))].position
			crash.global_position=Vector3(p[0],p[1],p[2])+origin();crash.play()
	if effects_log.size()>40: effects_log=effects_log.slice(-40)
	present()

func present() -> void:
	if state.is_empty(): return
	for c in panels:
		panels[c].position=origin();panels[c].visible=bool(state.controls[c])
	var gate=host.get("village_gate")
	if gate!=null and is_instance_valid(gate) and gate.has_method("set_leaf_removed"):
		for l in State.LEAVES: gate.set_leaf_removed(int(l),not bool(state.leaves[l]))

## ---- regions (source relink groups) -----------------------------------------------------------------------------
func _physics_process(_delta: float) -> void:
	if state.is_empty() or get_tree().paused or not is_instance_valid(host.get("player")): return
	var now: Array=[];var pos: Vector3=host.player.global_position-origin()
	var foot: float=pos.y-preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
	for id in src.relink:
		var row: Dictionary=src.relink[id]
		if foot<float(row.floor.min())-4 or foot>float(row.floor.max())+6: continue
		var poly:=PackedVector2Array()
		for v in row.polygon: poly.append(Vector2(v[0],v[1]))
		if not Geometry2D.is_point_in_polygon(Vector2(pos.x,pos.z),poly): continue
		now.append(int(id))
		if int(id) not in inside: apply(State.enter_region(state,src,int(id)))
	inside=now

## ---- Force gate (owner-approved modern action) ------------------------------------------------------------------
func _active() -> bool:
	if host.get_tree().paused or host.get("flying") or Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED: return false
	if host.has_method("actor_input_locked") and host.actor_input_locked(): return false
	if host.get("interface_hud")!=null and is_instance_valid(host.interface_hud) and host.interface_hud.get("cursor_active"): return false
	return host.get("starting_magic")==null or host.starting_magic.world_active()

## The aimed, reachable, unoccluded closed leaf (0 when none).
func target() -> int:
	if state.is_empty() or not _active(): return 0
	var gate=host.get("village_gate")
	if gate==null or not is_instance_valid(gate) or int(gate.pose)!=0: return 0
	var from: Vector3=host.camera.global_position
	var ray:=PhysicsRayQueryParameters3D.create(from,from-host.camera.global_basis.z*REACH,1,[host.player.get_rid()])
	var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or not hit.collider.has_meta("source_movable"): return 0
	var leaf:=int(hit.collider.get_meta("source_movable"))
	return leaf if str(leaf) in State.LEAVES and State.linked(state,leaf) else 0

func _stowable() -> bool: return host.hand_item=="" or host.hand_item in host.carried_collected
func _held_label(id: String) -> String:
	var text: String=preload("res://scripts/lol2/item_catalog.gd").label(id)
	return text if text!="" else id.get_slice(":",id.get_slice_count(":")-1).replace("_"," ")

## Contextual refusal text for the aimed leaf ("" when the story prerequisites hold).
func refusal_hint() -> String:
	var ctx:=context()
	if int(ctx.get("shared",{}).get("29",0))!=1: return "The village gate is closed."
	if int(ctx.get("locals",{}).get("39",0))!=1: return "The gate is barred and watched. You cannot force it now."
	return ""

func interaction_hint() -> String:
	if target()==0: return ""
	var refused:=refusal_hint()
	if not refused.is_empty(): return refused
	if host.hand_item=="": return "E — Force gate"
	return "E — Force gate (puts away %s)"%_held_label(host.hand_item) if _stowable() else ""

func _feedback(text: String) -> void:
	if host.has_method("save_feedback"): host.save_feedback(text)

func use() -> bool:
	var leaf:=target()
	return leaf!=0 and force(leaf)

## The action on an already aimed leaf (use() supplies the aim): refuse with a hint, or stow a carried held item and run
## the consumer with the supplied context. Returns true when it handled the press.
func force(leaf: int) -> bool:
	if state.is_empty() or not str(leaf) in State.LEAVES or not State.linked(state,leaf): return false
	var refused:=refusal_hint()
	if not refused.is_empty():
		_feedback(refused);return true
	if not _stowable(): return false
	var held: String=host.hand_item
	host.hand_item=""
	var context_hit:={"mask0":0x0800,"before":int(src.leaves[str(leaf)].durability),"after":0}
	var e:=State.hit(state,src,leaf,context_hit,context())
	if e.is_empty():
		host.hand_item=held;return false
	apply(e)
	if is_instance_valid(host.get("interface_hud")): host.interface_hud.refresh_equipment()
	_feedback(("%s put away. "%_held_label(held) if held!="" else "")+"The gate gives way.")
	return true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E and use(): get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	var text:=interaction_hint()
	if text.is_empty() or not is_instance_valid(host.get("interface_hud")): return
	host.interface_hud.hint.text=text
	host.interface_hud.save_notice_remaining=0.2
