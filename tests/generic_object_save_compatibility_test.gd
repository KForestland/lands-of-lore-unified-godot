extends SceneTree
const World=preload("res://scripts/lol2/generic_object_world.gd")
const Rules=preload("res://scripts/lol2/generic_object_rules.gd")
const Catalog=preload("res://scripts/lol2/generic_object_catalog.gd")
var failures:=0
func check(ok:bool,message:String):
 if not ok:failures+=1;push_error(message)
func _initialize():run.call_deferred()
func run():
 var packet:Dictionary={"version":1,"areas":{"L10_DC":{"movables":{},"breakables":{}}}}
 check(World.validate(packet).is_empty(),"A smaller old census loads; newly registered rows use source defaults")
 packet.areas.L10_DC.movables["999999"]={"future":"opaque"}
 packet.areas.L10_DC.breakables["999999"]={"future":"opaque"}
 packet.areas.L9_DR={"future":"opaque"}
 check(World.validate(packet).is_empty(),"Unknown ids and another area's future packet do not wedge whole-game loading")
 packet.areas.L10_DC.movables["86"]=Rules.initial(str(Catalog.movables("L10_DC")[86].placement_hex).hex_decode())
 check(World.validate(packet).is_empty(),"Known smaller census row validates")
 var placement:PackedByteArray=str(Catalog.movables("L10_DC")[86].placement_hex).hex_decode()
 var limit:int=Rules.distance_word(int(placement[0x22]),int(placement[0x24]))
 var oversize:Dictionary=packet.areas.L10_DC.movables["86"].duplicate(true)
 oversize[Rules.POSITION]=(limit+10)*Rules.FIXED;oversize[Rules.TRAVEL]=limit+10
 packet.areas.L10_DC.movables["86"]=oversize
 check(World.validate(packet).is_empty(),"Old larger span does not wedge a whole-game save")
 var bounded:Dictionary=Rules.clamp_saved_motion(oversize,placement)
 check(bounded[Rules.POSITION]==limit*Rules.FIXED and bounded[Rules.TRAVEL]==limit,"Both saved motion bounds clamp")
 check(oversize[Rules.TRAVEL]==limit+10,"Compatibility validation never mutates the input packet")
 packet.areas.L10_DC.breakables["5"]={"life":9999,"selector":3}
 check(World.validate(packet).is_empty(),"Old higher life/selector bounds remain loadable")
 check(World.clamp_saved_cover(packet.areas.L10_DC.breakables["5"],Catalog.breakables("L10_DC")[5])=={"life":80,"selector":0},"Cover bounds clamp to the current table")
 packet.areas.L10_DC.breakables.erase("5")
 packet.areas.L10_DC.movables["86"][Rules.POSITION]=-1
 check(not World.validate(packet).is_empty(),"A malformed known row still refuses atomically")
 packet.areas.L10_DC.movables.erase("86")
 packet.areas.L10_DC.breakables["241"]={"life":-1,"selector":0}
 check(not World.validate(packet).is_empty(),"Malformed known cover still refuses")
 var pack:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/static_assemblies/L10_DC/assemblies.json"))
 var collision:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/static_collision_L10_DC.json"))
 var rows:Dictionary=Catalog.breakables("L10_DC")
 check(World.data_error(rows,pack,collision,true).is_empty(),"Complete staged cover data is eligible for ownership")
 check(World.data_error(rows,pack,collision,false).contains("native script"),"Missing native export explicitly refuses ownership")
 check(World.data_error(rows,null,collision,true).contains("manifest"),"Missing media manifest explicitly refuses ownership")
 check(World.data_error(rows,pack,null,true).contains("collision"),"Missing collision data explicitly refuses ownership")
 var broken_pack:Dictionary=pack.duplicate(true)
 for face in broken_pack.faces:
  if int(face.assembly)==241:face.material="missing_generic_cover_fixture.png"
 check(World.data_error(rows,broken_pack,collision,true).contains("cover material"),"Missing cover art explicitly refuses ownership, leaving original static frames")
 if failures==0:print("PASS B generic save compatibility: additions, omissions and unknown areas accepted; known malformed rows refused")
 quit(0 if failures==0 else 1)
