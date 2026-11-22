extends RefCounted
## Draw ownership for generic parts. A placement's region may be a cabinet's
## tiny solid interior, not the room from which its exposed front is visible.
## Keep its native room and every room its actual published faces touch, with
## an overlapping vertical air span. No fixed outward probe or centroid guess.
const Visibility=preload("res://scripts/lol2/region_visibility.gd")
const BORDER_TOLERANCE:=1.0 # Existing portal-edge tolerance, one native map unit.
static func enabled(host:Node)->bool:
 var rooms:Variant=host.get("region_cluster")
 return rooms is Dictionary and not rooms.is_empty()
static func placement_region(bytes:PackedByteArray)->int:
 return bytes.decode_u16(10) if bytes.size()>=12 else -1
static func bounds_of(poly:PackedVector2Array)->Rect2:
 var box:=Rect2(poly[0],Vector2.ZERO)
 for point in poly:box=box.expand(point)
 return box
static func footprints_meet(face:PackedVector2Array,room:PackedVector2Array)->bool:
 if face.is_empty() or room.is_empty():return false
 if not bounds_of(face).grow(BORDER_TOLERANCE).intersects(bounds_of(room),true):return false
 for point in face:
  if Geometry2D.is_point_in_polygon(point,room):return true
 var area:=0.0
 for i in face.size():area+=face[i].cross(face[(i+1)%face.size()])
 if absf(area)>0.001:
  for point in room:
   if Geometry2D.is_point_in_polygon(point,face):return true
 for i in face.size():
  var a:=face[i];var b:=face[(i+1)%face.size()]
  for j in room.size():
   var c:=room[j];var d:=room[(j+1)%room.size()]
   if Geometry2D.segment_intersects_segment(a,b,c,d)!=null:return true
   if a.distance_to(Geometry2D.get_closest_point_to_segment(a,c,d))<=BORDER_TOLERANCE:return true
   if b.distance_to(Geometry2D.get_closest_point_to_segment(b,c,d))<=BORDER_TOLERANCE:return true
   if c.distance_to(Geometry2D.get_closest_point_to_segment(c,a,b))<=BORDER_TOLERANCE:return true
   if d.distance_to(Geometry2D.get_closest_point_to_segment(d,a,b))<=BORDER_TOLERANCE:return true
 return false
static func geometry(host:Node3D)->Array:
 if host.has_meta("object_room_geometry"):return host.get_meta("object_room_geometry")
 var result:Array=[]
 var nav:Variant=host.get("portal_nav")
 if not nav is Array or nav.is_empty():return result
 var native:Dictionary=Visibility.load_native(str(host.get("area_id")))
 var ceilings:Array=native.get("region_ceiling",[])
 host.set_meta("object_room_potential",native.get("potential",{}))
 for i in nav.size():
  if nav[i][0].is_empty() or i>=ceilings.size() or not host.region_cluster.has(i):continue
  var poly:=PackedVector2Array()
  for point:Array in nav[i][0]:poly.append(Vector2(point[0],point[1]))
  result.append({"room":int(host.region_cluster[i]),"polygon":poly,"box":bounds_of(poly),"floor":float(nav[i][1]),"ceiling":float(ceilings[i])})
 host.set_meta("object_room_geometry",result)
 return result
static func rooms_for_faces(host:Node3D,primary:int,faces:Array)->Array:
 var result:Array=[primary]
 if faces.is_empty():return result
 var records:Array=[]
 var total:Rect2
 var first:=true
 for points:Array in faces:
  var poly:=PackedVector2Array();var low:=INF;var high:=-INF
  for point:Array in points:
   poly.append(Vector2(point[0],point[2]));low=minf(low,float(point[1]));high=maxf(high,float(point[1]))
  if poly.is_empty():continue
  var box:=bounds_of(poly).grow(BORDER_TOLERANCE)
  total=box if first else total.merge(box);first=false
  records.append({"polygon":poly,"box":box,"low":low,"high":high})
 if records.is_empty():return result
 var regions:Array=geometry(host)
 var potential:Dictionary=host.get_meta("object_room_potential",{})
 var allowed:Dictionary={}
 # JSON numbers are floats; Array.has uses strict numeric types. Match the
 # existing portal loader's canonical integer room sets.
 for adjacent in potential.get(str(primary),[]):allowed[int(adjacent)]=true
 for region:Dictionary in regions:
  if not potential.is_empty() and not allowed.has(int(region.room)):continue
  if int(region.room) in result or not total.intersects(region.box,true):continue
  for face:Dictionary in records:
   if not face.box.intersects(region.box,true):continue
   # A flat horizontal face can lie on a floor; vertical faces need actual
   # air overlap. This keeps unrelated stacked storeys out of the room set.
   if float(face.high)-float(face.low)<0.001:
    if face.low<region.floor-0.01 or face.high>region.ceiling+0.01:continue
   elif minf(face.high,region.ceiling)<=maxf(face.low,region.floor)+0.01:continue
   if footprints_meet(face.polygon,region.polygon):result.append(int(region.room));break
 result.sort()
 return result
static func bind(host:Node3D,parent:Node3D,bytes:PackedByteArray,faces:Array=[])->bool:
 if not enabled(host):return false
 var region:=placement_region(bytes)
 var room:int=int(host.region_cluster.get(region,-1))
 if room<0:
  push_error("Object room missing for native region%d: %s"%[region,parent.name]);parent.visible=false;return false
 var rooms:=rooms_for_faces(host,room,faces)
 parent.set_meta("object_room_region",region);parent.set_meta("object_room",room);parent.set_meta("object_rooms",rooms)
 var nodes:Array=host.cluster_meshes.get(room,[])
 if parent not in nodes:nodes.append(parent)
 host.cluster_meshes[room]=nodes
 var visibility:Variant=host.get("region_visibility")
 if is_instance_valid(visibility) and int(visibility.last_start)>=0:
  var shown:bool=not visibility.enabled
  for reached in visibility.visible_regions:
   if int(visibility.cluster_of.get(reached,-1)) in rooms:shown=true;break
  parent.visible=shown
 return true
