extends "res://tests/area_owners/scene_snapshot.gd"
## Preserve every agreed baseline child, in its original order. These are the
## explicit later owner registrations, not a regenerated scene snapshot.
## Generic: area_owners/<area>.gd; selectors: generic_object_world/prop_selector_view;
## thin guard: act2_map._ready; owner replacements: the three named area owners.
const INSERTIONS := {
 "L8_SJ":[["L8Journey",[["GenericObjects","generic_object_world.gd"]]],["L8Dawn",[["L8FloodedShaft","l8_flooded_shaft.gd"]]]],
 "L9_DR":[["L9MagicBridge",[["GenericObjects","generic_object_world.gd"]]]],
 "L10_DC":[["Act2Progression",[["ThinRegionBlocks","thin_region_blocks.gd"]]]],
 "L12_CM":[["L12Glacier",[["GenericObjects","generic_object_world.gd"]]],["StartingMagic",[["L12TigerPlatform","l12_tiger_platform.gd"],["L12RiverBank","l12_river_bank.gd"]]]],
 "L13_RC":[["StaticAssemblies_L13_RC",[["L13PinkWedgeRelease","l13_pink_wedge_release.gd"]]]],
 "L14_HT":[["L14TempleDoors",[["GenericObjects","generic_object_world.gd"]]],["StartingMagic",[["L14AloeBed","l14_aloe_bed.gd"]]]],
 "L16_CA":[["L16FountainFreeze",[["GenericObjects","generic_object_world.gd"]]]],
 "L17_HC":[["L17CavernRun",[["GenericObjects","generic_object_world.gd"]]]],
 "L19_BC":[["L19DrainPath",[["L19LabLedge","l19_lab_ledge.gd"]]]],
 "L20_BB":[["L20MotherCurse",[["GenericObjects","generic_object_world.gd"],["PropSelector144","prop_selector_view.gd"],["PropSelector145","prop_selector_view.gd"],["PropSelector146","prop_selector_view.gd"],["PropSelector153","prop_selector_view.gd"],["PropSelector154","prop_selector_view.gd"],["PropSelector155","prop_selector_view.gd"]]]]
}
func kind()->String:return "order_with_explicit_later_registrations"
func verify_scene(scene:Node,area:String)->void:
 var expected:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURES+area+".json"))
 var wanted:Array=expected.children.duplicate(true)
 for insertion:Array in INSERTIONS.get(area,[]):
  var matches:Array=[]
  for i in wanted.size():
   if wanted[i].name==insertion[0]:matches.append(i)
  check(matches.size()==1,area+" unique baseline insertion anchor "+insertion[0])
  if matches.size()!=1:return
  var index:int=matches[0]
  for row:Array in insertion[1]:
   var child:Dictionary={"name":row[0],"script":"res://scripts/lol2/"+row[1]}
   check(not expected.children.has(child),area+" later child is absent from the original baseline: "+row[0])
   wanted.insert(index,child);index+=1
 check(snapshot(scene).children==wanted,area+" complete original child order plus exact typed additions")
