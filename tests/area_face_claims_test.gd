extends "res://tests/area_owners/scene_snapshot.gd"
func kind() -> String: return "faces"

## Only exact source-censused G03 movers leave the static mesh. Original
## goldens remain immutable; collision and every other mesh face stay exact.
func snapshot(scene:Node)->Dictionary:
 var actual:Dictionary=super.snapshot(scene)
 const PATH="res://tests/fixtures/g03_static_face_additions.json"
 assert(FileAccess.get_sha256(PATH)=="1fa8422655f653d3d81ebd8e51dd65712fa60a6856dfe83de7d5d39add0b607d","Independent source-census fixture pin")
 var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PATH))
 var area:String={"res://scenes/lol2/dragon_level.tscn":"L9_DR","res://scenes/lol2/maps/L12_CM.tscn":"L12_CM","res://scenes/lol2/maps/L14_HT.tscn":"L14_HT","res://scenes/lol2/maps/L16_CA.tscn":"L16_CA"}.get(scene.scene_file_path,"")
 if not fixture.rows.has(area):return actual
 var row:Dictionary=fixture.rows[area]
 for file in ["catalog","geometry","original_golden"]:
  assert(FileAccess.get_sha256("res://"+row[file])==row[file+"_sha256"],"Pinned independent G03 face source: "+area+" "+str(file))
 assert(scene.geometry_file=="res://"+row.geometry,"The exact source-indexed geometry is under test")
 var before:int=actual.mesh_excluded.size()
 for index in row.additional_mesh_exclusions:
  assert(actual.mesh_excluded.has(int(index)),"New generic mover face must leave the static mesh")
  actual.mesh_excluded.erase(int(index))
 print("G03 FACES ",area," actual=",before," exact added=",row.additional_mesh_exclusions.size()," original comparison=",actual.mesh_excluded.size(),"; collision untouched")
 if area=="L12_CM":
  # r19o10 (owner F10 2026-11-16T16-30-04, lake switch freeze): an unpulled save cuts the ten lake deck floors from the
  # static mesh while the area loads (L12TigerPlatform.claim_decks), not on the pull. Exactly those ten floor faces leave.
  var floors:Dictionary=preload("res://scripts/lol2/l12_tiger_platform.gd").FLOORS
  var pack:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(scene.geometry_file))
  var decks:=0
  for index in actual.mesh_excluded.duplicate():
   var face:Dictionary=pack.faces[int(index)]
   if str(face.get("kind",""))=="floor" and floors.has(scene.progression._face_region(face)):
    actual.mesh_excluded.erase(index);decks+=1
  assert(decks==floors.size() and scene.progression.floor_decks.size()==floors.size(),"Ten lake deck floors claimed at load (got %d)"%decks)
 return actual
