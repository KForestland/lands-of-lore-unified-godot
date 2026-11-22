extends SceneTree
const Oil=preload("res://scripts/lol2/l10_oil.gd")
func _initialize():run.call_deferred()
func covers(rows:Array,kind:String,p:Vector2,node:Node)->bool:
 for face in rows:
  if face.kind==kind and Geometry2D.is_point_in_polygon(p,node.polygon(face)):return true
 return false
func run():
 var pack:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/maps/L10_DC/area.json"))
 var oil:=Oil.new();var geometry:Dictionary=oil.collapse_geometry(pack.faces)
 assert(covers(geometry.before,"floor",Vector2(-1435,-3192),oil),"Robot stands on selected original floor1596")
 assert(covers(geometry.after,"floor",Vector2(-1435,-3192),oil),"Unsupported original north rim survives collapse")
 assert(not covers(geometry.after,"floor",Vector2(-1490,-3250),oil),"V4 native landing still has an open hole above it")
 assert(not covers(geometry.after,"ceiling",Vector2(-1490,-3250),oil),"Buried ceiling stays clipped at the actual descent")
 var landings:Array=[];var sample_count:=0
 for face in pack.faces:
  if face.kind=="floor" and Oil.source().lower_ceilings.has(int(face.region)):landings.append(face)
 for face in geometry.before:
  if face.kind!="floor":continue
  var p:PackedVector2Array=oil.polygon(face);var lo:=p[0];var hi:=p[0]
  for v in p:lo=lo.min(v);hi=hi.max(v)
  for x in range(int(lo.x)+3,int(hi.x),8):
   for z in range(int(lo.y)+3,int(hi.y),8):
    var point:=Vector2(x+0.17,z+0.31)
    if not Geometry2D.is_point_in_polygon(point,p):continue
    var supported:=covers(landings,"floor",point,oil)
    if covers(geometry.after,"floor",point,oil)==supported:
     print("BAD CUT region ",face.region," point ",point," native_supported ",supported)
     for row in geometry.after:
      if covers([row],"floor",point,oil):print("RETAINED ",row.region," ",row.points)
    assert(covers(geometry.after,"floor",point,oil)==not supported,"Opening removes only upper floor with a native landing below: "+str(point))
    sample_count+=1
 assert(sample_count>500,"Dense whole-opening census is nonempty")
 for face in geometry.after:
  assert(face.kind in ["floor","ceiling"],"Removed source controls stay removed")
  assert(face.points.size()==face.uv.size(),"Every retained cut keeps UVs")
  assert(Geometry2D.triangulate_polygon(oil.polygon(face)).size()>0,"Retained rim triangulates")
 print("PASS oil opening support census ",sample_count," samples; robot rim retained, native descent open, clipped UV geometry triangulates")
 oil.free();quit()
