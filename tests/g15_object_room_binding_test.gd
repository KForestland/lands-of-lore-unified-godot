extends SceneTree
const Rooms=preload("res://scripts/lol2/object_room_visibility.gd")
class Host extends Node3D:
 var region_cluster:Dictionary={42:7}
 var cluster_meshes:Dictionary={7:[]}
 var region_visibility:Node
func _initialize():
 var host:=Host.new();var parent:=Node3D.new();host.add_child(parent)
 var raw:=PackedByteArray();raw.resize(12);raw.encode_u16(10,42)
 var original:=parent.transform
 assert(Rooms.placement_region(raw)==42 and Rooms.placement_region(PackedByteArray())==-1)
 var bound:=Rooms.bind(host,parent,raw)
 assert(bound and parent.get_meta("object_room_region")==42 and parent.get_meta("object_room")==7)
 bound=Rooms.bind(host,parent,raw)
 assert(bound and host.cluster_meshes[7]==[parent] and parent.transform==original,"Registration is idempotent and draw-only")
 var exterior:=PackedVector2Array([Vector2(-2,-2),Vector2(2,-2),Vector2(2,2),Vector2(-2,2)])
 host.set_meta("object_room_geometry",[
  {"room":8,"polygon":exterior,"box":Rect2(-2,-2,4,4),"floor":0.0,"ceiling":30.0},
  {"room":9,"polygon":exterior,"box":Rect2(-2,-2,4,4),"floor":25.0,"ceiling":100.0},
  {"room":10,"polygon":exterior,"box":Rect2(-2,-2,4,4),"floor":0.0,"ceiling":30.0}])
 host.set_meta("object_room_potential",JSON.parse_string('{"7":[8,9]}'))
 var faces:Array=[[[ -1,10,0],[1,10,0],[1,20,0],[-1,20,0]]]
 assert(Rooms.rooms_for_faces(host,7,faces)==[7,8],"Exposed faces join the exterior room; stacked room above their height stays out")
 var border:=PackedVector2Array([Vector2(-1,-3),Vector2(1,-3),Vector2(1,-3),Vector2(-1,-3)])
 assert(Rooms.footprints_meet(border,exterior),"Existing one-unit portal border tolerance covers a front on the room boundary")
 var quad:Array=[[-2,-2],[2,-2],[2,2],[-2,2]]
 var stacked:Array=[[quad,0,0,[]],[quad,90,130,[]]]
 assert(Rooms.Visibility.floor_region(stacked,Vector3(0,0,0),{0:80,1:160})==0,"An overhead floor is not the feet room even when closer to the camera")
 assert(Rooms.Visibility.floor_region(stacked,Vector3(0,90,0),{0:80,1:160})==1,"An upper-storey body keeps the upper room")
 assert(Rooms.Visibility.floor_region(stacked,Vector3(0,-10,0),{0:80,1:160})==-1,"No invented room when the body is below both floors")
 assert(Rooms.Visibility.floor_region([[quad,-150,-150,[]]],Vector3(0,-75,0),{0:-75})==-1,"Standing on a ceiling is not inside the air below it")
 host.free()
 print("PASS native placement room binding, truncated-input sentinel, idempotent registration and unchanged transform")
 quit()
