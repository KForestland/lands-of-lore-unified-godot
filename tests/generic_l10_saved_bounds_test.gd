extends "res://tests/generic_prop_input_test.gd"
## Codec component: an older larger table is represented by over-current-bound
## numeric fields. Real F5/F9 verifies the canonical clamped save; not an earned walk.
const World=preload("res://scripts/lol2/generic_object_world.gd")
const Catalog=preload("res://scripts/lol2/generic_object_catalog.gd")
func run():
 folder="user://tests/generic_l10_saved_bounds";DirAccess.make_dir_recursive_absolute(folder)
 if not await boot("res://scenes/lol2/maps/L10_DC.tscn","res://assets/lol2/generated/playtest_starts/c15_l10_dc.json","6f9d174047977927af32457ccbb2e9df1ef332974e02b7adcf915854d25ea49f","lol2-restoration-map-L10_DC"):return
 var saved:Dictionary=AreaSave.snapshot_host(scene)
 var world:Node=scene.get_node("GenericObjects")
 var placement:PackedByteArray=str(Catalog.movables("L10_DC")[86].placement_hex).hex_decode()
 var limit:int=Rules.distance_word(int(placement[0x22]),int(placement[0x24]))
 var motion:Dictionary=Rules.initial(placement)
 motion[Rules.POSITION]=(limit+10)*Rules.FIXED;motion[Rules.TRAVEL]=limit+10
 var packet:Dictionary={"version":1,"areas":{"L10_DC":{"movables":{"86":motion},"breakables":{"5":{"life":9999,"selector":3}}}}}
 saved.quests.generic_objects=packet.duplicate(true)
 var before_warnings:int=World.warned_clamps.size()
 if not check(scene.apply_save(saved).is_empty(),"An old larger-table area packet applies instead of wedging all saves"):return
 if not check(state(86)[Rules.POSITION]==limit*Rules.FIXED and state(86)[Rules.TRAVEL]==limit,"Native position and travel clamp"):return
 if not check(scene.progression.native.field("control:5",scene.progression.NativeHost.FIELD_BYTE26,0)==80 and world.cover_modes[5]==0,"Native life and selector clamp"):return
 if not check(World.warned_clamps.size()>=before_warnings+2,"Restore reports both clamps as warnings"):return
 if not check(packet.areas.L10_DC.movables["86"][Rules.TRAVEL]==limit+10,"Input remains unchanged"):return
 if not await pose(Vector3(-542,32.05,-856),Vector3(-542,42,-1056)):return
 await key(KEY_F5)
 var status:Dictionary=Slots.read_document(Slots.slot_path(1))
 print("BOUNDS F5 error=",status.error," HUD=",scene.interface_hud.hint.text," paused=",paused," saving=",scene.interface_hud.saves_enabled)
 var written:Dictionary=slot_packet()
 if not check(not written.is_empty() and int(written.quests.generic_objects.areas.L10_DC.movables["86"][Rules.POSITION])==limit*Rules.FIXED and int(written.quests.generic_objects.areas.L10_DC.breakables["5"].life)==80,"RealF5 writes the bounded canonical packet"):return
 var warnings_after_save:int=World.warned_clamps.size()
 if not await load_slot():return
 if not check(World.warned_clamps.size()==warnings_after_save,"Canonical F5 reload needs no new bound-clamp warnings"):return
 if not check(state(86)[Rules.POSITION]==limit*Rules.FIXED and scene.progression.native.field("control:5",scene.progression.NativeHost.FIELD_BYTE26,0)==80,"Fresh F9 retains clamped bounds"):return
 print("PASS larger-table saved motion/life/selector clamp with warnings, unchanged input and realF5/F9")
 quit()
