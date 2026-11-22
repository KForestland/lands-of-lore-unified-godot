extends SceneTree
const Actions=preload("res://scripts/lol2/generic_object_actions.gd")
class Player extends Node3D:
 var grounded:=true
 func is_on_floor()->bool:return grounded
class Host extends Node3D:
 var player:Node3D
class Native extends RefCounted:
 var placements:Dictionary={"control:53":"a5ec51f900007dfc8204db03ca0f7f000000000001000000000000002400030006".hex_decode()}
class Binding extends Node:
 var regions:Array=[]
 var native:RefCounted=Native.new()
func _initialize():
 var host:=Host.new();host.player=Player.new();host.add_child(host.player)
 var binding:=Binding.new();binding.regions.resize(988)
 binding.regions[987]=[[[-4989,1679],[-4900,1679],[-4899,1739],[-4989,1739]],-900,-900,[]]
 var actions:=Actions.new();actions.host=host;actions.binding=binding
 var pads:Array=Actions.ROWS.L13_RC.filter(func(row):return row.ref=="control:53")
 assert(pads.size()==1,"One native teleporter pad row")
 var row:Dictionary=pads[0]
 for point:Vector3 in [Vector3(-4953,-868,1711),Vector3(-4976,-868,1693),Vector3(-4912,-868,1693),Vector3(-4912,-868,1725),Vector3(-4976,-868,1725)]:
  host.player.position=point
  assert(actions.on_pad(row),"Every source-floor corner belongs to the pad, including outside the former32 disk")
 host.player.position=Vector3(-4890,-868,1711)
 assert(not actions.on_pad(row),"Outside source polygon is not pad")
 host.player.position=Vector3(-4953,-1008,1711)
 assert(not actions.on_pad(row),"A room below the pad must not trigger it")
 host.player.position=Vector3(-4953,-868,1711);host.player.grounded=false
 assert(not actions.on_pad(row),"Airborne is not a walk onto the pad")
 actions.free();binding.free();host.free()
 print("PASS source987 entire pad floor, former-circle corners, outside/below/air negatives")
 quit()
