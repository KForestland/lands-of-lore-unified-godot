extends "res://tests/hive_locks_r139_setup_test.gd"
func run():
 check(Current.source_error().is_empty(),"Native and geometry digest pins match staged sources")
 var geo:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/hive_review/hive.json"))
 var floors:Array=geo.faces.filter(func(f):return f.kind=="floor" and f.region==760)
 check(floors.size()==1 and floors[0]==Current.data().floor,"Pinned floor760 is the exact current source quad")
 for key in ["geometry_sha256","native_export_sha256"]:
  var old:String=Current.data()[key];Current.source[key]="changed"
  check(not Current.source_error().is_empty(),"Digest drift rejected for "+key);Current.source[key]=old
 for id in [114,115,116]:
  var placement:Dictionary=Current.data().controls[str(id)]
  var x:float=placement.x;var y:float=placement.height;var z:float=-placement.y
  var pack={"faces":[{"assembly":id,"initial":true,"points":[[x-3,y-3,z],[x+3,y-3,z],[x+3,y+3,z],[x-3,y+3,z]]}]}
  var result:Dictionary=Current.lock_bounds(pack,id)
  check(result.error.is_empty() and result.bounds.size.z==2,"Flat lock plate gets a finite ray box "+str(id))
  for point in pack.faces[0].points:point[0]+=1000
  check(not Current.lock_bounds(pack,id).error.is_empty(),"Assembly-local/wrong-space coordinates refused "+str(id))
 var first:Dictionary=Current.initial();first.native.state.clear()
 check(Current.initial().native.state.size()==3,"Cached initial snapshot is copied, never aliased")
 var host:=Host.new();root.add_child(host)
 host.player=CharacterBody3D.new();host.add_child(host.player);host.camera=Camera3D.new();host.player.add_child(host.camera)
 var data:Dictionary=Current.data();host.materials[data.floor.material]=StandardMaterial3D.new()
 host.static_assemblies.data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/static_assemblies/L5_HC/assemblies.json"))
 var owner:=Current.new();host.add_child(owner);check(owner.setup(host).is_empty(),"Source setup with no ConversationReview is safe")
 owner.set_process(false);owner.set_physics_process(false)
 check(owner.active(),"Missing optional ConversationReview neither crashes nor locks input")
 for id in [116,116,114,115]:owner.press(id)
 var complete:Dictionary=owner.checkpoint()
 var bad:Dictionary=complete.duplicate(true);bad.native.state.erase("0x22d0c:760")
 check(not Current.validate(bad).is_empty(),"Completed floor without its native destination is refused")
 bad=complete.duplicate(true);bad.native.locals.clear();bad.native.locals[16]=0
 check(not Current.validate(bad).is_empty(),"Integer-key tampering is refused; real snapshots use canonical string keys")
 bad=Current.initial();bad.progress=3
 check(not Current.validate(bad).is_empty(),"Forged progress3/top0 rejected")
 for delta in [0.25,0.25,0.25]:owner._physics_process(delta)
 check(owner.rise==15,"Explicit modern20 units/s takes0.75 active seconds for15 units")
 check(Current.validate(JSON.parse_string(JSON.stringify(owner.checkpoint(),"",true,true))).is_empty(),"Actual serializer's complete snapshot keys validate")
 if not failed:print("PASS R139 exact native/geometry/floor pins, drift/flat/missing/wrong-space guards, cached-copy purity, optional conversation, forged keys/prefix/floor refusal and disclosed modern rate")
 quit(1 if failed else 0)
