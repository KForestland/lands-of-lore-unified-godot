extends SceneTree
const Current=preload("res://scripts/lol2/hive_decoded_locks.gd")
var failed:=false
class Assemblies extends RefCounted:
 var data:Dictionary={}
class Magic extends RefCounted:
 func health():return 30
 func world_active():return true
class Host extends Node3D:
 var static_assemblies=Assemblies.new()
 var materials:Dictionary={}
 var carried_quest_checkpoint:Dictionary={}
 var player:CharacterBody3D
 var camera:Camera3D
 var starting_magic=Magic.new()
 var runes:Node
 var lines:Array=[]
 var item_effects:Node
 func actor_input_locked():return false
 func save_feedback(line:String):lines.append(line)
func check(ok:bool,message:String):
 print("R139_SETUP ","GREEN " if ok else "RED ",message)
 if not ok:failed=true;push_warning(message)
func _initialize():run.call_deferred()
func run():
 var before:bool="--r139-before" in OS.get_cmdline_user_args()
 var script:Variant=load("res://tmp/r139_baseline.gd") if before else Current
 var host:=Host.new();root.add_child(host)
 host.player=CharacterBody3D.new();host.add_child(host.player);host.camera=Camera3D.new();host.player.add_child(host.camera)
 var shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.height=64;capsule.radius=12;shape.shape=capsule;host.player.add_child(shape)
 var source:Dictionary=script.data()
 host.materials[source.floor.material]=StandardMaterial3D.new()
 host.static_assemblies.data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/static_assemblies/L5_HC/assemblies.json"))
 var owner:Node=script.new();host.add_child(owner)
 owner.set_process(false);owner.set_physics_process(false)
 check(owner.setup(host).is_empty(),"Pinned native/geometry and map-space lock bounds admitted")
 owner.set_process(false);owner.set_physics_process(false)
 for id in [114,115,116]:
  var box:BoxShape3D=owner.bodies[id].get_child(0).shape
  check(box.size.x>=2 and box.size.y>=2 and box.size.z>=2,"Each lock has finite ray thickness "+str(id))
 host.player.position=Vector3(-3607,-979,-7002);host.player.velocity=Vector3(0,-40,0)
 owner.completed=true;owner.rise=7;owner.present()
 var slab:ConvexPolygonShape3D=owner.floor_body.get_child(1).shape
 var bottom:=INF
 for point in slab.points:bottom=minf(bottom,point.y+owner.floor_body.position.y)
 check(bottom<=-1011,"Mid-rise prism fills to original floor; no small-form pocket")
 check(absf(host.player.position.y-(-972))<0.01 and host.player.velocity.y>=0,"Body inside region760 projected up at the saved mid-rise height")
 # Setup guard is deliberately last: the old component really indexes an
 # empty points array and errors here. It is a RED, not an expected exception.
 owner.free()
 host.static_assemblies.data={"faces":[]}
 owner=script.new();host.add_child(owner);owner.set_process(false);owner.set_physics_process(false)
 var error:String=owner.setup(host)
 check(not error.is_empty() and "geometry" in error,"Missing initial control geometry refuses setup, not the whole Hive")
 if not failed:print("PASS R139 finite source bounds, missing-geometry guard, filled prism and occupied mid-rise projection")
 quit(1 if failed else 0)
