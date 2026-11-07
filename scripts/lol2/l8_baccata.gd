extends Node3D
## Original trap location and actor116; book-led rescue, summary and departure adapter.
const KEY:="l8_baccata"
const AIM:=Vector3(4549,125,-1006)
const Catalog=preload("res://scripts/lol2/item_catalog.gd")
const MEDIA:="res://assets/lol2/generated/l8_baccata/"
var host:Node3D
var trapped:MeshInstance3D
var material:StandardMaterial3D
var frames:Array[Texture2D]=[]
var hint:Label
var clock:=0.0
var presented:=-1
static func initial()->Dictionary:return {"version":1,"phase":0,"elapsed":0.0}
static func validate(s:Variant)->String:
 if not s is Dictionary or s.size()!=3 or s.get("version")!=1:return "Invalid Baccata rescue."
 var phase=s.get("phase")
 if not (phase is float or phase is int) or not is_finite(phase) or phase!=floor(phase) or phase<0 or phase>3:return "Invalid Baccata phase."
 var time=s.get("elapsed")
 if not (time is float or time is int) or not is_finite(time) or time<0 or time>=5 or (s.phase!=2 and time!=0):return "Invalid Baccata departure clock."
 return ""
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l8_baccata.gd").new();n.host=map;n.name="L8Baccata";map.add_child(n);return n
func state()->Dictionary:return host.quest_state.get(KEY,initial())
func _ready():
 var media:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(MEDIA+"trap.json"))
 for row in media.frames:frames.append(ImageTexture.create_from_image(Image.load_from_file(MEDIA+row.file)))
 material=StandardMaterial3D.new();material.albedo_texture=frames[0];material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR;material.billboard_mode=BaseMaterial3D.BILLBOARD_FIXED_Y;material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
 # Inversion is a logged presentation adapter, not the original trap animation.
 material.uv1_scale=Vector3(1,-1,1);material.uv1_offset=Vector3(0,1,0)
 trapped=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(134,100);quad.center_offset=Vector3(0,50,0);trapped.mesh=quad;trapped.material_override=material;trapped.position=Vector3(4549,100,-1006);add_child(trapped)
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas);hint=Label.new();hint.position=Vector2(24,455);canvas.add_child(hint)
 restore(true)
func restore(force:bool=false):
 var phase:int=state().phase
 var enabled:bool=host.quest_state.get("l8_shore",{}).get("arrived",false)
 trapped.visible=enabled and phase==0
 if not force and presented==phase:return
 presented=phase
 # Remove the two coincident static fallback images. One trap owner renders here.
 for id in [100,101]:
  if host.prop_placements.has(id):
   var row:Array=host.prop_placements[id];var pose:=Transform3D(Basis(),row[2]);pose.basis=Basis.from_scale(Vector3.ZERO);row[0].set_instance_transform(row[1],pose)
 var pop=host.act2_creatures
 pop.state.actors["116"].present=enabled and phase in [1,2]
 pop.sync_quests();pop.present()
func active()->bool:return not get_tree().paused and not host.flying and host.get("starting_magic") != null and host.starting_magic.world_active()
func reachable()->bool:
 if not host.quest_state.get("l8_shore",{}).get("arrived",false):return false
 var aim:Vector3=AIM if state().phase==0 else host.act2_creatures.bodies["116"].global_position+Vector3.UP*50
 var delta:Vector3=aim-host.camera.global_position
 if delta.length()>180 or delta.length()<0.01 or (-host.camera.global_basis.z).dot(delta.normalized())<0.8:return false
 var ray:=PhysicsRayQueryParameters3D.create(host.camera.global_position,aim,1,[host.player.get_rid()])
 return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
func interact(item:String="")->Dictionary:
 if not active() or not reachable() or host.player_form!=0:return {"ok":false,"reason":"Approach Baccata in human form."}
 var s:=state().duplicate(true)
 if s.phase==0:
  var label:String=Catalog.entry(item).get("label","")
  if item not in host.carried_collected or not ("Sword" in label or "Longsword" in label or "Dagger" in label or "blade" in label):return {"ok":false,"reason":"Use a carried blade to cut him down."}
  s.phase=1;host.quest_state[KEY]=s;restore()
  return {"ok":true,"reason":"You cut Baccata free. Speak with him before continuing."}
 if s.phase==1:
  s.phase=2;host.quest_state[KEY]=s;restore()
  return {"ok":true,"reason":"Baccata speaks with you, then sets off through the jungle."}
 return {"ok":false,"reason":"Baccata is leaving."}
func _physics_process(delta):
 restore()
 if not active():return
 clock+=delta;material.albedo_texture=frames[int(clock*15)%frames.size()]
 if state().phase!=2:return
 var s:=state().duplicate(true);s.elapsed+=delta
 var pop=host.act2_creatures;var body:CharacterBody3D=pop.bodies["116"]
 body.velocity=Vector3(0,-20,20);body.move_and_slide()
 pop.state.actors["116"].position=pop.Live.saved_position(body.position);pop.sync_quests()
 if s.elapsed>=5:s.phase=3;s.elapsed=0.0
 host.quest_state[KEY]=s;restore()
func _process(_delta):
 hint.text=""
 if active() and reachable() and state().phase<2:hint.text="E — Cut Baccata down" if state().phase==0 else "E — Speak with Baccata"
func _unhandled_input(event:InputEvent):
 if event is not InputEventKey or not event.pressed or event.echo or event.keycode!=KEY_E:return
 if not active() or Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED or is_instance_valid(host.inventory) or not reachable():return
 if host.has_method("actor_input_locked") and host.actor_input_locked():return
 var r:=interact(host.equipped_item);host.save_feedback(r.reason);get_viewport().set_input_as_handled()
