extends SceneTree
## Physical window/box fixture, real F. Proves the fallback rather than the
## old48-forward path. No earned/source-layout claim, no damage/balance value.
const Blood=preload("res://scripts/lol2/player_dragon_blood.gd")
const Crates=preload("res://scripts/lol2/dark_halls_crates.gd")
const ID:="museum:item2:Dragon_Blood"
class Magic extends Node:
 func health()->int:return 30
 func world_active()->bool:return false
class Host extends Node3D:
 var player:CharacterBody3D
 var camera:Camera3D
 var starting_magic:Node
 var player_form:=0
class Controller extends Node:
 var host:Node3D
 var blood:Node
 var pack:Array=[ID]
 var saved:={"spent":[],"dragon_blood":[]}
 var used:=false
 var reason:=""
 func state()->Dictionary:return saved
 func carried()->Array:return pack
 func consume_item(id:String)->bool:
  if id not in pack:return false
  pack.erase(id);saved.spent.append(id);return true
 func refuse_item(text:String)->bool:reason=text;return false
 func _unhandled_input(event:InputEvent):
  if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F:used=blood.place(ID)
func box(parent:Node,at:Vector3,size:Vector3,layer:int)->StaticBody3D:
 var body:=StaticBody3D.new();body.position=at;body.collision_layer=layer;body.collision_mask=0
 var shape:=CollisionShape3D.new();var cube:=BoxShape3D.new();cube.size=size;shape.shape=cube;body.add_child(shape);parent.add_child(body)
 return body
func _initialize():run.call_deferred()
func run():
 assert(DisplayServer.get_name()!="headless" and Engine.time_scale==1 and Engine.physics_ticks_per_second==60)
 var host:=Host.new();host.scene_file_path="res://scenes/lol2/dark_halls.tscn";root.add_child(host);current_scene=host
 host.player=CharacterBody3D.new();host.player.position=Vector3(0,32,0);host.player.collision_layer=2;host.add_child(host.player)
 var collision:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=5;capsule.height=64;collision.shape=capsule;host.player.add_child(collision)
 host.camera=Camera3D.new();host.player.add_child(host.camera);host.camera.position.y=18;host.camera.current=true;host.camera.look_at(Vector3(90,19,0))
 host.starting_magic=Magic.new();host.add_child(host.starting_magic)
 box(host,Vector3(50,-1,0),Vector3(240,2,100),1)
 box(host,Vector3(52,15,0),Vector3(4,30,100),1) # Opaque lip: camera sees above, low bomb cannot.
 var body:=box(host,Vector3(90,10,0),Vector3(20,20,20),258);body.set_meta("dark_halls_crate",973)
 var crates:=Crates.new();crates.name="DarkHallsCrates";crates.host=host;crates.centers[973]=body.position;crates.halves[973]=Vector3(10,10,10);crates.crate_state[973]=1;crates.bodies[973]=body;host.add_child(crates)
 var controller:=Controller.new();controller.host=host;host.add_child(controller)
 controller.blood=Blood.new();host.add_child(controller.blood);controller.blood.setup(controller)
 await physics_frame;await physics_frame
 var legacy:Vector3=host.camera.global_position-host.camera.global_basis.z*48
 legacy.y=10
 assert(crates.blood_targets(legacy,Blood.RADIUS).is_empty(),"Fixture really blocks the old48-forward placement")
 Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
 for down in [true,false]:
  var event:=InputEventKey.new();event.keycode=KEY_F;event.physical_keycode=KEY_F;event.pressed=down
  Input.parse_input_event(event);Input.flush_buffered_events();await process_frame
 assert(controller.used and controller.pack.is_empty() and controller.saved.dragon_blood.size()==1,"ActualF takes the visible fallback: "+controller.reason)
 var p:Array=controller.saved.dragon_blood[0].position;var placed:=Vector3(p[0],p[1],p[2])
 assert(not AABB(body.position-Vector3(10,10,10),Vector3(20,20,20)).has_point(placed),"Vial rests outside the crate collider, including a top-face hit")
 assert(not crates.blood_targets(placed,Blood.RADIUS).is_empty(),"Placed vial really reaches the visible crate")
 print("PASS R141b rendered realF, physical lip blocks legacy48 path; visible top fallback places one vial outside actual collider on ground with clear crate reach; synthetic layout/controller admitted, not an earned/source-slot walk")
 quit()
