extends RefCounted
## Read-only trajectory output. No input, state restore, player or clock writes.
var harness:SceneTree
var stream:FileAccess
var samples:=0
var last_host:=0
var last_position:=Vector3.ZERO
var last_resets:=0
func _init(tree:SceneTree,path:String):
 harness=tree
 DirAccess.make_dir_recursive_absolute(path.get_base_dir())
 stream=FileAccess.open(path,FileAccess.WRITE)
 assert(stream!=null,"Walked-ground trace output opens")
 stream.store_line(JSON.stringify({"format":"lol2-walked-ground-v1","scope":"actual physics-frame poses and actual contact-shape bounds; read-only recorder","physics_ticks_per_second":Engine.physics_ticks_per_second,"time_scale":Engine.time_scale}))
 harness.physics_frame.connect(record_now)
func body_bounds(player:Node3D)->Dictionary:
 for child in player.get_children():
  if not child is CollisionShape3D or child.disabled:continue
  var shape:Shape3D=child.shape
  var half_height:float
  if shape is CapsuleShape3D:half_height=shape.height*0.5
  elif shape is BoxShape3D:half_height=shape.size.y*0.5
  elif shape is SphereShape3D:half_height=shape.radius
  else:continue
  var center:Vector3=child.global_position
  var extent:float=half_height*child.global_basis.y.length()
  return {"feet":center.y-extent,"top":center.y+extent,"shape":shape.get_class(),"center":center.y,"half_height":extent}
 return {}
func record_now():
 if stream==null:return
 var scene:Variant=harness.get("scene")
 if not is_instance_valid(scene) or harness.current_scene!=scene or scene.get("ready_for_review")!=true:return
 var player:Variant=scene.get("player")
 if not player is CharacterBody3D or not player.is_inside_tree():return
 var at:Vector3=player.global_position
 var host:int=scene.get_instance_id()
 var resets:int=int(scene.get("resets"))
 var discontinuity:=""
 if host!=last_host:discontinuity="new_area_host_or_loaded_host"
 elif resets!=last_resets:discontinuity="fall_recovery"
 elif at.distance_to(last_position)>90:discontinuity="observed_large_same_host_jump"
 var bounds:=body_bounds(player)
 var actual_area:Variant=scene.get("area_id")
 if not actual_area is String or str(actual_area).is_empty():
  actual_area="L8_SJ" if scene.scene_file_path.ends_with("darker_jungle.tscn") else ("L9_DR" if scene.scene_file_path.ends_with("dragon_level.tscn") else str(harness.get("area")))
 var row:Dictionary={"sample":samples,"physics_frame":Engine.get_physics_frames(),"msec":Time.get_ticks_msec(),"area":str(actual_area),"scene_file":scene.scene_file_path,"host":host,"position":[at.x,at.y,at.z],"on_floor":player.is_on_floor(),"paused":harness.paused,"resets":resets,"body":bounds,"discontinuity":discontinuity}
 stream.store_line(JSON.stringify(row))
 samples+=1;last_host=host;last_position=at;last_resets=resets
 if samples%60==0:stream.flush()
func finish():
 if harness.physics_frame.is_connected(record_now):harness.physics_frame.disconnect(record_now)
 if stream!=null:stream.flush();stream.close();stream=null
