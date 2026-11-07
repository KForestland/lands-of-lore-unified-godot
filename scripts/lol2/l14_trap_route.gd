extends Node3D
const KEY="l14_trap_route"
const Kit=preload("res://scripts/lol2/mechanism_transaction.gd")
const DOORS={"81":Vector3(-62,180,-413),"80":Vector3(-51,180,580)}
var host:Node3D
var doors:Dictionary={}
var rock:MeshInstance3D
var hint:Label
static func initial()->Dictionary:return {"version":1,"doors":[],"triggered":false,"elapsed":0.0}
static func validate(s:Variant,quests:Dictionary)->String:
 if not s is Dictionary or s.size()!=4 or s.get("version")!=1 or not s.get("doors") is Array or not s.get("triggered") is bool:return "Invalid Temple trap route."
 if s.doors not in [[],["81"],["81","80"]]:return "Invalid bypass door order."
 if not preload("res://scripts/lol2/walkthrough_save.gd")._number(s.get("elapsed")) or not is_finite(s.elapsed) or s.elapsed<0 or s.elapsed>2:return "Invalid boulder motion."
 if not s.triggered and s.elapsed!=0:return "Boulder lacks trigger."
 if not s.doors.is_empty() and quests.get("l14_flute_slot",{}).get("covered",0)!=2:return "Bypass lacks covered oil."
 return ""
static func owns(f:Dictionary)->bool:return f.get("placement_kind")=="movable" and int(f.get("source_index",-1)) in [80,81]
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l14_trap_route.gd").new();n.host=map;n.name="L14TrapRoute";map.add_child(n);return n
func state()->Dictionary:return host.quest_state.get(KEY,initial())
func _ready():
 var pack:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file))
 for id in DOORS:
  var n:=Node3D.new();n.name="OriginalBypassDoor"+id;add_child(n);doors[id]=n
  var faces:Array=[]
  for f in pack.faces:
   if f.get("placement_kind")=="movable" and int(f.get("source_index",-1))==int(id):faces.append(f)
  assert(not faces.is_empty(),"Missing original bypass door")
  host.get_node("L14Niche").build(n,faces)
 rock=MeshInstance3D.new();rock.name="BoulderTemplate12Adapter";add_child(rock)
 var quad:=QuadMesh.new();quad.size=Vector2(130,80);rock.mesh=quad
 var material:=StandardMaterial3D.new();material.albedo_texture=ImageTexture.create_from_image(Image.load_from_file(host.geometry_file.get_base_dir()+"/"+pack.materials["473"]))
 material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR;material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;rock.material_override=material
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas);hint=Label.new();hint.position=Vector2(24,455);canvas.add_child(hint);restore()
func reachable(id:String)->bool:
 if not DOORS.has(id) or host.player_form!=0 or host.flying or not host.starting_magic.world_active():return false
 var d:Vector3=DOORS[id]-host.camera.global_position
 if d.length()<0.01 or d.length()>130 or (-host.camera.global_basis.z).dot(d.normalized())<0.9:return false
 var ray:=PhysicsRayQueryParameters3D.create(host.camera.global_position,DOORS[id],1,[host.player.get_rid()]);var hit:Dictionary=host.get_world_3d().direct_space_state.intersect_ray(ray)
 return hit.is_empty() or hit.position.distance_to(DOORS[id])<18
func open_door(id:String)->Dictionary:
 if not reachable(id) or host.quest_state.get("l14_flute_slot",{}).get("covered",0)!=2:return Kit.refuse("Approach the bypass door after covering the oil.")
 var s:=state().duplicate(true)
 if id in s.doors:return Kit.refuse("The door is already open.")
 if id=="80" and "81" not in s.doors:return Kit.refuse("Follow the side passage.")
 s.doors.append(id);host.quest_state[KEY]=s;restore();return {"ok":true,"reason":"The side door opens."}
func restore():
 for id in doors:doors[id].position.y=80 if id in state().doors else 0
 rock.visible=state().triggered
 rock.position=Vector3(29,360-180*minf(1,float(state().elapsed)),1136)
func _physics_process(delta):
 if host.starting_magic.world_active():
  var s:=state().duplicate(true);var p:Vector3=host.player.position;var feet:float=p.y-32
  if feet>=130 and feet<=150 and p.x>=-18 and p.x<=76 and p.z>=1038 and p.z<=1235:s.triggered=true
  if s.triggered:s.elapsed=minf(2,s.elapsed+delta)
  if s.triggered and s.elapsed>=0.75 and s.elapsed<=1.5 and absf(p.x-29)<62 and absf(p.z-1136)<55 and feet>=130 and feet<=180:
   host.starting_magic.set_health(0);host.save_feedback("The boulder crushes you. F9 loads your earned save.")
  if s.triggered or not s.doors.is_empty():host.quest_state[KEY]=s
 restore()
func _process(_delta):
 hint.text=""
 for id in DOORS:
  if reachable(id) and id not in state().doors:hint.text="E — Open side door";return
func _unhandled_key_input(event:InputEvent):
 if event is not InputEventKey or not event.pressed or event.echo or event.keycode!=KEY_E:return
 for id in DOORS:
  if reachable(id) and id not in state().doors:host.save_feedback(open_door(id).reason);get_viewport().set_input_as_handled();return
