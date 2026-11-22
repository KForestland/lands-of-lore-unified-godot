extends SceneTree
## Independent existing-owner motion bounds, not a player route.
const World=preload("res://scripts/lol2/act2_world_checkpoint.gd")
const Native=preload("res://scripts/lol2/native_script_host.gd")
func _initialize():
 var vm:=Native.new();assert(vm.load_area("res://scripts/lol2/native_scripts/L10_DC.json").is_empty())
 var limits:=World.mover_limits("L10_DC")
 for id in [70,71,72,73,74]:
  var limit:Dictionary=limits[str(id)]
  var axis:Vector3=Vector3.UP*(limit.bounds.size.y+8.0) if id==74 else Vector3.RIGHT*(-1.0 if id in [70,73] else 1.0)*absf(float(vm.attributes["movable:%d"%id].angle_word))
  for fraction in [0.0,0.25,0.75,1.0]:
   var pose:=Transform3D(Basis(),limit.origin+axis*fraction)
   assert(World.mover_error(World.encode(pose),limit).is_empty(),"Existing owner path admitted at source extent: "+str(id)+" / "+str(fraction))
  for displacement in [axis*1.1,axis*0.5+Vector3.FORWARD*30]:
   assert(not World.mover_error(World.encode(Transform3D(Basis(),limit.origin+displacement)),limit).is_empty(),"Off-path/out-of-source pose refused: "+str(id))
  assert(not World.mover_error(World.encode(Transform3D(Basis(),limit.origin-axis*0.5)),limit).is_empty(),"One-way owner panel cannot be loaded on wrong side")
 print("PASS five existing L10 owner mover paths, endpoints/midpoints, source extents and off-axis/wrong-side refusals")
 quit()
