extends SceneTree
## Actual game-written saves, fresh real loaders, actual loaded inventory/owner
## queries. Prerequisites/selectors are component aids, never earned routes.
const G03=preload("res://tests/helpers/item_grant_g03_reference.gd")
const Fixtures=preload("res://tests/helpers/item_grant_host_save_fixtures.gd")
const LEGACY:="res://tests/fixtures/saves_d5da60a/areas/"
const WRITER_OVERRIDES:="res://tests/fixtures/item_grant_writer_overrides_9d1061c/manifest.json"
const OUTPUT:="res://tests/fixtures/item_grant_host_saves_20c7797/"
var output_root:=OUTPUT
var generate:=false
func _initialize():run.call_deferred()
func freeze(node:Node):
 node.process_mode=Node.PROCESS_MODE_DISABLED
 for child in node.get_children():freeze(child)
func boot(row:Dictionary,area:String)->Node3D:
 paused=false
 var scene:Node3D=load(row.scene).instantiate();scene.process_mode=Node.PROCESS_MODE_DISABLED
 root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if (scene.get("walkthrough_ready") if area=="L1_DC" else scene.get("ready_for_review")) and scene.get("starting_magic")!=null:break
 assert(scene.get("walkthrough_ready") if area=="L1_DC" else scene.get("ready_for_review"),area+" production host ready")
 if area=="L3_DH":scene.introduction_state="complete"
 freeze(scene);paused=false
 return scene
func close(scene:Node):
 scene.free();current_scene=null;paused=false
 for i in 3:await process_frame
func write_json(path:String,value:Variant):
 var file:=FileAccess.open(path,FileAccess.WRITE);assert(file!=null,path)
 file.store_string(JSON.stringify(value,"  ",true,true)+"\n");file.close()
func run():
 generate=OS.get_environment("LOL2_WRITE_ITEM_BASELINES")=="1"
 if OS.get_environment("LOL2_OBSERVE_ITEM_BASE")=="1":
  generate=true;output_root="user://tests/item_grant_base_observation/" # Never overwrites repository goldens.
 if generate:DirAccess.make_dir_recursive_absolute(output_root)
 var inputs:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(LEGACY+"manifest.json"))
 var expected:Dictionary={} if generate else JSON.parse_string(FileAccess.get_file_as_string(output_root+"manifest.json"))
 var overrides:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(WRITER_OVERRIDES)).areas
 if not generate:
  for area in overrides:
   assert(str(preload("res://scripts/lol2/geometry_move.gd").spec(area).outputs.pack)==str(overrides[area].diff[0].after),area+" base writer override matches published movement pack stamp")
   expected.post_grants[area].sha256=overrides[area].sha256
 var legacy_loaded:Dictionary={};var posts:Dictionary={}
 for area in inputs.areas:
  var row:Dictionary=inputs.areas[area]
  assert(FileAccess.get_sha256(LEGACY+area+".json")==row.sha256,"Untouched original golden "+area)
  var scene:Node3D=await boot(row,area)
  var error:String=scene._quickload_unrecorded(LEGACY+area+".json")
  assert(error.is_empty(),area+" original loader: "+error)
  freeze(scene)
  legacy_loaded[area]=Fixtures.record(scene,area)
  var names:Array=Fixtures.grant(scene,area,self)
  if names.is_empty():await close(scene);continue
  var path:String=output_root+area+"_after_grants.json" if generate else "user://tests/item_grant_host_save.json"
  if not generate:DirAccess.make_dir_recursive_absolute(path.get_base_dir())
  error=scene._quicksave_unrecorded(path)
  assert(error.is_empty(),area+" actual post-grant writer: "+error)
  var raw:=FileAccess.get_file_as_bytes(path)
  var pin:=FileAccess.get_sha256(path)
  if not generate:
   assert(expected.post_grants.has(area),area+" pinned post-grant host")
   var reference:String=str(overrides[area].path) if overrides.has(area) else output_root+area+"_after_grants.json"
   assert(FileAccess.get_sha256(reference)==expected.post_grants[area].sha256,area+" independently pinned writer reference")
   var g03_pin:String=G03.raw_pin(area)
   if g03_pin.is_empty():
    assert(raw==FileAccess.get_file_as_bytes(reference),area+" writer bytes after same original grant calls")
    assert(pin==expected.post_grants[area].sha256,area+" post-grant byte pin")
   else:
    assert(pin==g03_pin,area+" independently observed pre-items G03 writer byte pin")
    assert(G03.project("post_raw",area,JSON.parse_string(raw.get_string_from_utf8()))==JSON.parse_string(FileAccess.get_file_as_string(reference)),area+" all original save fields remain identical beside exact G03 additions")
    expected.post_grants[area].sha256=g03_pin
  await close(scene)
  scene=await boot(row,area)
  error=scene._quickload_unrecorded(path)
  assert(error.is_empty(),area+" fresh production loader accepts post-grant save: "+error)
  freeze(scene)
  var loaded:Dictionary=Fixtures.record(scene,area)
  var record_path:String=output_root+area+"_loaded.json"
  if generate:write_json(record_path,loaded)
  else:
   assert(FileAccess.get_sha256(record_path)==expected.post_grants[area].loaded_sha256,area+" frozen loaded-state pin")
   assert(G03.project("post_loaded",area,loaded)==JSON.parse_string(FileAccess.get_file_as_string(record_path)),area+" actual loaded pack/history/owners identical beside independently pinned G03 world fields")
  posts[area]={"sha256":pin,"loaded_sha256":FileAccess.get_sha256(record_path),"sites":names}
  print("HOST SAVE ",area," sites=",names," bytes=",raw.size()," loaded_pack=",loaded.actual_loaded_pack)
  if not generate and overrides.has(area):
   await close(scene);scene=await boot(row,area)
   error=scene._quickload_unrecorded(OUTPUT+area+"_after_grants.json")
   assert(error.is_empty(),area+" immutable pre-stamp writer input loads");freeze(scene)
   assert(Fixtures.record(scene,area)==loaded,area+" original and current stamped packets retain identical item/owner state")
   print("OLD POST-GRANT ",area," immutable pre-stamp input matches current loaded contract")
  await close(scene)
 assert(legacy_loaded.size()==15,"All fifteen original host/area fixtures have loaded-state records")
 # The build base also has fifteen normalized round-trips, Cave v1, and
 # five earlier Plan1 witnesses. Capture each through a fresh real loader.
 var variants:Dictionary={};var paths:Dictionary={}
 for area in inputs.areas:paths[area+"_roundtrip"]={"area":area,"path":LEGACY+area+"_roundtrip.json"}
 paths.L1_DC_v1={"area":"L1_DC","path":LEGACY+"L1_DC_v1.json"}
 for pair in [["cave","L1_DC"],["museum","L3_DH"],["jungle","L4_HJ"],["hive","L5_HC"],["act2","L10_DC"]]:
  paths["plan1_"+pair[0]]={"area":pair[1],"path":"res://tests/fixtures/saves_d5da60a/"+pair[0]+".json"}
 for name in paths:
  var input:Dictionary=paths[name];var scene:Node3D=await boot(inputs.areas[input.area],input.area)
  var error:String=scene._quickload_unrecorded(input.path)
  assert(error.is_empty(),name+" existing variant loader: "+error);freeze(scene)
  var loaded:Dictionary=Fixtures.record(scene,input.area,true)
  if name=="L1_DC_v1":assert(loaded.save_version==2,"Existing Cave v1 reader migrates to v2")
  variants[name]={"source":input.path,"sha256":FileAccess.get_sha256(input.path),"loaded":loaded}
  print("OLD VARIANT ",name," loaded_pack=",loaded.actual_loaded_pack)
  await close(scene)
 assert(variants.size()==21,"All additional existing golden variants have fresh-loaded records")
 var variants_path:=output_root+"legacy_variants.json"
 if generate:write_json(variants_path,variants)
 else:
  assert(FileAccess.get_sha256(variants_path)==expected.legacy_variants_sha256,"Frozen additional golden loaded-state pin")
  assert(G03.records("legacy_variants",variants)==JSON.parse_string(FileAccess.get_file_as_string(variants_path)),"All thirty-six existing golden packets retain their actual fresh-loaded state beside independently pinned G03 world fields")
 assert(posts.has("L1_DC") and posts.has("L3_DH") and posts.has("L4_HJ") and posts.has("L5_HC") and posts.has("L19_BC"),"Every pack store/host family has an actual post-grant save")
 for name in Fixtures.Sites.SITE_NAMES:
  var present:=false
  for row in posts.values():present=present or name in row.sites
  assert(present,"Every named section4 grant site has an actual host-written save and fresh loaded record: "+name)
 var legacy_path:=output_root+"legacy_loaded.json"
 if generate:write_json(legacy_path,legacy_loaded)
 else:
  assert(FileAccess.get_sha256(legacy_path)==expected.legacy_loaded_sha256,"Frozen fifteen-host loaded-record pin")
  assert(G03.records("legacy_loaded",legacy_loaded)==JSON.parse_string(FileAccess.get_file_as_string(legacy_path)),"Actual old-save pack/history/owners unchanged; exact independent G03 fields qualified separately")
 var manifest:Dictionary=Fixtures.Sites.canonical({"version":1,"base":"20c7797","scope":"Component prerequisites and original production grants/writers; actual fresh loaders; not earned saves. Thirty-six existing golden packets have loaded records; post-grant saves for the listed stores/areas only.","legacy_loaded_sha256":FileAccess.get_sha256(legacy_path),"legacy_variants_sha256":FileAccess.get_sha256(variants_path),"post_grants":posts})
 if generate:write_json(output_root+"manifest.json",manifest)
 else:assert(manifest==expected,"No host or saved-state baseline may disappear")
 print("PASS actual post-grant host saves for all13named sites; fresh loaded records for all36existing golden packets, including Cavev1; unchanged original goldens plus independently pinned pre-items G03 additions")
 quit()
