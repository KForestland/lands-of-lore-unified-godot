extends RefCounted
## Shared validated packet and separate collision body. Never edits terrain.
const Rule=preload("res://scripts/lol2/region_edge_rule.gd")
const ROOT:="res://scripts/lol2/height_boundary/"
static func packet_error(packet:Variant,area:String,map_sha:String)->String:
 if not packet is Dictionary or packet.get("area")!=area or not packet.get("block_face_keys") is Array:return "not a packet for "+area
 for key in packet.block_face_keys:
  if not key is String or key.is_empty():return "invalid face key for "+area
 var want:String=str(packet.get("inputs",{}).get("map",{}).get("sha256",""))
 if want.is_empty() or want!=map_sha:return "map sha256 mismatch for "+area+"; not applied"
 if packet.has("collision_faces") and not packet.collision_faces is Array:return "invalid clipped polygons for "+area
 return ""
static func load_packet(area:String,map_path:String)->Dictionary:
 var path:=ROOT+area+".json"
 if not FileAccess.file_exists(path):push_error("Height boundary: "+path+" is missing");return {}
 var packet:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
 var have:=FileAccess.get_sha256(map_path)
 # Same-height overlap moves (geometry_move.gd): a moved pack is checked against the pack it was made from (named walls lie
 # outside the moved regions).
 var move:Dictionary=preload("res://scripts/lol2/geometry_move.gd").spec(area)
 if not move.is_empty() and have==str(move.outputs.pack):have=str(move.inputs.pack)
 var error:=packet_error(packet,area,have)
 if not error.is_empty():push_error("Height boundary: "+path+" "+error);return {}
 # A move that lowers floors (L10 EMP) changes the heights in the keys of the walls on its edges: name them as moved.
 if not move.is_empty() and FileAccess.get_sha256(map_path)==str(move.outputs.pack) and move.get("key_moves") is Dictionary and not (move.key_moves as Dictionary).is_empty():
  var moved_of:Dictionary={}
  for after in move.key_moves:moved_of[str(move.key_moves[after])]=str(after)
  var keys:Array=[]
  for key in packet.block_face_keys:keys.append(moved_of.get(str(key),str(key)))
  packet=(packet as Dictionary).duplicate();packet.block_face_keys=keys
 return packet
static func keys(packet:Dictionary)->Dictionary:
 var selected:Dictionary={}
 for key in packet.get("block_face_keys",[]):selected[str(key)]=true
 return selected
static func selected_faces(data:Dictionary,wanted:Dictionary,polygons:Array,admit:Callable=Callable())->Dictionary:
 var triangles:=PackedVector3Array();var matched:Dictionary={}
 for index in data.faces.size():
  var face:Dictionary=data.faces[index]
  if str(face.get("kind","")) not in ["wall","source_wall"]:continue
  var key:=Rule.face_key(face)
  if not wanted.has(key):continue
  matched[key]=true
  if admit.is_valid() and not admit.call(index,face):continue
  for i in [0,1,2,0,2,3]:triangles.append(Vector3(face.points[i][0],face.points[i][1],face.points[i][2]))
 if matched.size()!=wanted.size():return {"error":"%d packet keys match no face"%(wanted.size()-matched.size()),"faces":PackedVector3Array()}
 for polygon in polygons:
  var points:Array=polygon.get("points",[])
  for i in range(1,points.size()-1):
   for point in [points[0],points[i],points[i+1]]:triangles.append(Vector3(float(point[0]),float(point[1]),float(point[2])))
 return {"error":"","faces":triangles}
static func attach(host:Node3D,data:Dictionary,wanted:Dictionary,polygons:Array=[],admit:Callable=Callable())->StaticBody3D:
 if wanted.is_empty() and polygons.is_empty():return null
 if host.get_node_or_null("HeightBoundaryCollision")!=null:push_error("Height boundary: duplicate body refused");return null
 var selection:=selected_faces(data,wanted,polygons,admit)
 if not selection.error.is_empty():push_error("Height boundary: "+selection.error);return null
 if selection.faces.is_empty():push_error("Height boundary: selection has no admitted triangles");return null
 var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(selection.faces)
 var collider:=CollisionShape3D.new();collider.shape=shape
 var body:=StaticBody3D.new();body.name="HeightBoundaryCollision";body.collision_layer=1;body.collision_mask=1
 body.add_child(collider);host.add_child(body)
 return body
