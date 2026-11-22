extends SceneTree
## Isolated physical occluder and health recorder. Native damage7 is a mock,
## not a proposed balance value; the real slot input separately proves26.
class Aura extends RefCounted:
 func targets()->Dictionary:return {}
class Magic extends Node:
 var aura:=Aura.new()
 var hp:=30
 var shield:=false
 func health()->int:return hp
 func set_health(value:int):hp=value
 func protected()->bool:return shield
 func world_active()->bool:return false
class Host extends Node3D:
 var player:CharacterBody3D
 var camera:Camera3D
 var starting_magic:Node
 var carried_collected:Array=[]
class Controller extends Node:
 var host:Node3D
 var saved:={"dragon_blood":[],"spent":[]}
 func state()->Dictionary:return saved
class Crates extends Node:
 var host:Node3D
 var blocker:StaticBody3D
 func exposed_targets()->Dictionary:return {1:{"point":blocker.global_position,"body":blocker}}
 func blood_targets(_point:Vector3,_radius:float)->Dictionary:return exposed_targets()
 func blood_player_damage(_ids:Array)->int:return 7
 func apply_player_blast(amount:int):
  if not host.starting_magic.protected():host.starting_magic.set_health(maxi(0,host.starting_magic.health()-amount))
 func receive_dragon_blood(_id:int,damage_player:bool=true)->bool:
  if damage_player:host.starting_magic.set_health(host.starting_magic.health()-7)
  blocker.collision_layer=0;return true
func _initialize():run.call_deferred()
func run():
 var host:=Host.new();root.add_child(host);current_scene=host
 host.player=CharacterBody3D.new();host.player.collision_layer=2;host.add_child(host.player);host.player.position=Vector3(0,32,-80)
 var pshape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=5;capsule.height=32;pshape.shape=capsule;host.player.add_child(pshape)
 host.camera=Camera3D.new();host.player.add_child(host.camera);host.camera.position.y=5
 host.starting_magic=Magic.new();host.add_child(host.starting_magic)
 var blocker:=StaticBody3D.new();blocker.collision_layer=1;host.add_child(blocker);blocker.position=Vector3(0,32,-40)
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(20,60,20);shape.shape=box;blocker.add_child(shape)
 var crates:=Crates.new();crates.name="DarkHallsCrates";crates.host=host;crates.blocker=blocker;host.add_child(crates)
 var controller:=Controller.new();controller.host=host;host.add_child(controller)
 var blood=load("res://scripts/lol2/player_dragon_blood.gd").new();host.add_child(blood);blood.setup(controller)
 await physics_frame;await physics_frame
 assert(not blood.clear_to(Vector3(0,32,0),host.camera.global_position,host.player),"Fixture crate shelters player before removal")
 blood.explode(Vector3(0,32,0))
 assert(host.starting_magic.health()==23,"One precomputed native crate blast, no post-removal Blood hit or double damage")
 host.starting_magic.hp=30;host.starting_magic.shield=true;blocker.collision_layer=1
 await physics_frame;await physics_frame
 blood.explode(Vector3(0,32,0))
 assert(host.starting_magic.health()==30,"Protected player takes no crate blast through the shared health path")
 var real:Node=load("res://scripts/lol2/dark_halls_crates.gd").new();real.host=host
 real.apply_player_blast(7)
 assert(host.starting_magic.health()==30,"Actual crate health path also honours protection")
 host.starting_magic.shield=false;real.apply_player_blast(7)
 assert(host.starting_magic.health()==23,"Actual crate health path applies one ordinary hit")
 real.centers[1]=Vector3.ZERO;real.blast={"radius":200}
 assert(real._exposed_advice(1)=="Too close - step further back.","Native-radius warning has no cast invitation")
 host.player.position=Vector3(0,32,-200) # Supplied unit boundary, not a world walk.
 assert(not "Blood" in real._exposed_advice(1),"No unavailable vial advice at a safe stand")
 host.carried_collected=["museum:item2:Dragon_Blood"]
 assert("Blood" in real._exposed_advice(1),"Carried vial names the alternative outside the native blast")
 real.free()
 print("PASS R141 protected/common-health path and carried-vial advice; physical shelter removed during callback: player receives one native mock7 hit, not Blood20 plus7; synthetic world/health aid, actual slot proves native26 separately")
 quit()
