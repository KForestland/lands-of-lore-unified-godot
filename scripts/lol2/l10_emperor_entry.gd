extends "res://scripts/lol2/l10_oil.gd"
## Book-led Holy Switch66. Source11480 supplies the exact raised surface list/words.
const Ankh=preload("res://scripts/lol2/l10_ankh_state.gd")
const SLAB_AIM:=Vector3(3207,45,-2321)
const RAISED:=[1864,1873,1867,1868,1871,1872,1874,1881,1869]
const CLIPPED:=[272, 274, 360, 786, 791, 792, 956, 957, 960, 961, 1863, 1870, 1877, 1878, 1879, 1880, 2179, 2180, 2181, 2183, 2184, 2187, 2188, 2189, 2190, 2192, 2193, 2194, 2195, 2196, 2197, 2198, 2199, 2200, 2201, 2202, 2204, 2205, 2206, 2207, 2208, 2209, 2210, 2211, 2212, 2213, 2214, 2215, 2216, 2219, 2220, 2226, 2227, 2228, 2230, 2232, 2235, 2236, 2237, 2238, 2239, 2240, 2241, 2242, 2243, 2244, 2245, 2246, 2247, 2248, 2249, 2250, 2251, 2252, 2253, 2254, 2255, 2256, 2257, 2258, 2259, 2260, 2263, 2264, 2265, 2266, 2267, 2268, 2269, 2270, 2271, 2272, 2273, 2274, 2275, 2276, 2277, 2278, 2279, 2280, 2284, 2294]
const LOWER_CEILINGS:=[1666, 1669, 1670, 1671, 1672, 1673, 1674, 1675, 1676, 1677, 1678, 1679, 1693, 2700, 2701, 2702, 2703, 2720, 2721, 2722, 2725, 2726, 2729, 2730, 2731, 2825, 2826, 2842, 2843, 2844, 2845, 2846]
const ROOM_FLOORS:=[3789, 3790, 3791, 3792, 3793, 3794, 3795, 3796, 3797, 3798, 3799, 3800, 3801, 3802, 3803, 3804, 3805, 3806, 3807, 3808, 3809, 3810, 3811, 3812, 3813, 3814, 3815, 3816, 3817, 3818, 3819, 3820, 3821, 3822, 3823, 3824, 3825, 3826, 3827, 3828, 3829, 3830, 3831, 3832, 3833, 3834, 3835, 3836, 3837, 3838, 3839, 3840, 3841, 3842, 3843, 3844, 3845, 3846, 3847, 3848, 3849, 3850, 3854, 3855, 3856, 3857, 3858, 3859, 3860, 3861, 3862, 3863, 3864, 3865, 3866, 3867, 3868, 3870, 3871, 3872, 3873, 3874, 3876, 3877, 3878, 3879, 3880, 3881, 3882, 3884, 3885, 3886, 3887, 3888, 3889, 3890, 3891, 3892, 3893, 3894, 3895, 3896, 3897, 3898, 3899]
var stair_holes: Array=[]
var original_static_edges: Array=[]
var original_dynamic_edges: Array=[]
var slab: Node3D
static func entry_owns(face: Dictionary)->bool:
 var region:=int(face.get("region",-1)) if face.get("region")!=null else -1
 return (face.kind=="floor" and (region in RAISED or region in CLIPPED)) or (face.kind=="ceiling" and (region==3937 or region in LOWER_CEILINGS)) or (face.get("placement_kind")=="static_assembly" and int(face.get("source_index",-1))==66)
static func attach_entry(map: Node3D)->Node3D:
 var node=load("res://scripts/lol2/l10_emperor_entry.gd").new();node.host=map;node.name="L10EmperorEntry";map.add_child(node);return node
func opened()->bool:return Ankh.committed(host.quest_state.get("l10_ankh",Ankh.initial()),Ankh.SLAB)
func _ready():
 intact=Node3D.new();intact.name="ClosedEntrance";add_child(intact)
 collapsed=Node3D.new();collapsed.name="RaisedEntrance";add_child(collapsed)
 var pack: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file))
 for face in pack.faces:
  if (face.kind=="ceiling" and int(face.get("region",-1))==3922) or (face.kind=="floor" and int(face.get("region",-1)) in ROOM_FLOORS):stair_holes.append(polygon(face))
 var before: Array=[];var after: Array=[]
 for face in pack.faces:
  if not entry_owns(face) or face.get("placement_kind")=="static_assembly":continue
  before.append(face)
  if int(face.region) in CLIPPED or int(face.region) in LOWER_CEILINGS:
   var parts: Array=[face]
   for hole in stair_holes:
    var next: Array=[]
    for part in parts:next.append_array(clip_floor(part,hole))
    parts=next
   after.append_array(parts);continue
  var lifted: Dictionary=face.duplicate(true)
  for p in lifted.points:p[1]+=90 if face.kind=="ceiling" else 100
  after.append(lifted)
 build(intact,before,pack);build(collapsed,after,pack)
 slab=preload("res://scripts/lol2/static_assemblies.gd").new();add_child(slab)
 # Isolate the original switch's two source modes; no second owner for other assemblies.
 var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/static_assemblies/L10_DC/assemblies.json"))
 slab.host=host;slab.data=data
 var faces: Array=[]
 for f in data.faces:
  if int(f.assembly)==66 and f.initial:faces.append(f)
 slab._build_assembly(66,faces)
 var blockers=host.get_node("RegionBlockers")
 original_static_edges=blockers.static_edges.duplicate(true);original_dynamic_edges=blockers.dynamic_edges.duplicate(true)
 restore()
func restore():
 var value:=opened()
 if presented==value:return
 presented=value;intact.visible=not value;collapsed.visible=value
 intact.get_node("Collision").collision_layer=0 if value else 1
 collapsed.get_node("Collision").collision_layer=1 if value else 0
 slab.set_mode(66,1 if value else 0)
 var blockers=host.get_node("RegionBlockers")
 blockers.static_edges=clip_edges(original_static_edges) if value else original_static_edges.duplicate(true)
 blockers.dynamic_edges=clip_edges(original_dynamic_edges) if value else original_dynamic_edges.duplicate(true)
 blockers.rebuild_static(blockers.clearance)
func reachable()->bool:
 var delta: Vector3=SLAB_AIM-host.camera.global_position
 if delta.length()>140 or delta.length()<0.01 or (-host.camera.global_basis.z).dot(delta.normalized())<0.8:return false
 var ray:=PhysicsRayQueryParameters3D.create(host.camera.global_position,SLAB_AIM,1,[host.player.get_rid()])
 return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
func offer(item: String)->Dictionary:
 if get_tree().paused or host.flying or not host.starting_magic.world_active() or host.player_form!=0 or not reachable():return Ankh.Kit.refuse("Approach and face the slab as Human.")
 var result:=Ankh.act(host.quest_state.get("l10_ankh",Ankh.initial()),host.carried_collected,Ankh.SLAB,item)
 if not result.ok:return result
 host.carried_collected=result.inventory;host.quest_state.l10_ankh=result.state
 preload("res://scripts/lol2/act2_items_catalog.gd").sync(host);restore()
 return {"ok":true,"reason":"The Emperor's tomb opens. Take the ankh back from the slab."}
func _process(_delta):restore()
func _unhandled_input(event: InputEvent):
 if event is not InputEventKey or not event.pressed or event.echo or event.keycode!=KEY_E:return
 if Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED or is_instance_valid(host.inventory) or not reachable():return
 if host.has_method("actor_input_locked") and host.actor_input_locked():return
 var result:=offer(Ankh.ANKH);host.save_feedback(result.reason);get_viewport().set_input_as_handled()

func clip_floor(face: Dictionary,hole: PackedVector2Array)->Array:
 var out: Array=[]
 for part in Geometry2D.clip_polygons(polygon(face),hole):
  if part.size()<3:continue
  var row: Dictionary=face.duplicate(true);row.points=[];row.uv=[]
  var base: Dictionary=face.get("uv_basis",face)
  row["uv_basis"]=base.duplicate(true)
  var origin:=Vector2(base.points[0][0],base.points[0][2])
  var u:=Vector2(base.points[1][0],base.points[1][2])-origin
  var v:=Vector2(base.points[3][0],base.points[3][2])-origin
  var det:=u.cross(v)
  for point in part:
   var offset: Vector2=point-origin
   var a: float=offset.cross(v)/det if absf(det)>0.0001 else 0
   var b: float=u.cross(offset)/det if absf(det)>0.0001 else 0
   row.points.append([point.x,float(base.points[0][1])+a*(float(base.points[1][1])-float(base.points[0][1]))+b*(float(base.points[3][1])-float(base.points[0][1])),point.y])
   var uv:=Vector2(base.uv[0][0],base.uv[0][1])+a*(Vector2(base.uv[1][0],base.uv[1][1])-Vector2(base.uv[0][0],base.uv[0][1]))+b*(Vector2(base.uv[3][0],base.uv[3][1])-Vector2(base.uv[0][0],base.uv[0][1]))
   row.uv.append([uv.x,uv.y])
  out.append(row)
 return out

func clip_edges(edges: Array)->Array:
 var out: Array=[]
 for edge in edges:
  if float(edge.ceiling)>=0:out.append(edge.duplicate(true));continue
  var parts: Array=[PackedVector2Array([Vector2(edge.a[0],edge.a[1]),Vector2(edge.b[0],edge.b[1])])]
  for hole in stair_holes:
   var next: Array=[]
   for part in parts:next.append_array(Geometry2D.clip_polyline_with_polygon(part,hole))
   parts=next
  for part in parts:
   for i in range(part.size()-1):
    var row: Dictionary=edge.duplicate(true);row.a=[part[i].x,part[i].y];row.b=[part[i+1].x,part[i+1].y];out.append(row)
 return out
