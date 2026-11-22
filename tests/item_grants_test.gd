extends SceneTree
## Bare-host contract fixtures only. No scene, input, physics or earned route.
const Grants=preload("res://scripts/lol2/item_grants.gd")
const Catalog=preload("res://scripts/lol2/item_catalog.gd")
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
const Journal=preload("res://scripts/lol2/my_journal.gd")
const CAVE:="cave:guard38:Short_Sword"
const MUSEUM:="museum:prop280:Prism"
const JUNGLE:="jungle:kelsrick:Fine_Longsword"
const ACT2:="act2:L10_DC:item44"
const ACT2_B:="act2:L10_DC:item48"
class Effects:
	extends RefCounted
	var saved:Dictionary={}
	func state()->Dictionary:return saved
class Hud:
	extends RefCounted
	var refreshes:=0
	func refresh_equipment():refreshes+=1
class Host:
	extends Node
	var saved_quests:Dictionary={}
	var sync_packets:Array=[]
	var quest_state:Dictionary:
		get:
			for frame in get_stack():
				if str(frame.source).ends_with("/act2_items_catalog.gd") and frame.function=="sync":
					sync_packets.append(saved_quests.get("act2_items",Items.initial()).duplicate(true));break
			return saved_quests
		set(value):saved_quests=value
	var messages:Array=[]
	var item_effects=Effects.new()
	var interface_hud=Hud.new()
	func save_feedback(text:String):messages.append(text)
class Ordinary:
	extends Host
	var carried_collected:Array=[]
class Museum:
	extends Ordinary
	static func validate_cave_transfer(_packet:Variant,_required:bool=false)->String:return ""
class NoQuests:
	extends Node
	var carried_collected:Array=[]
class Hive:
	extends Host
	var carried_inventory:Dictionary={"collected":[],"equipped_item":"unchanged"}
class Cave:
	extends Host
	var owners:Array=[CAVE]
	func carried_items()->Array:return owners
var failures:=0
var hosts:Array=[]
func _initialize():run.call_deferred()
func check(ok:bool,why:String):
	if not ok:failures+=1;printerr("FAIL item grants: ",why)
func ordinary()->Ordinary:
	var host:=Ordinary.new();hosts.append(host);return host
func snapshot(host:Host)->Dictionary:
	return {"pack":Grants.pack(host).duplicate(true),"quests":host.quest_state.duplicate(true),
		"messages":host.messages.duplicate(),"effects":host.item_effects.saved.duplicate(true),"hud":host.interface_hud.refreshes}
func error_unchanged(host:Host,action:Callable,reason:String):
	var before:=snapshot(host)
	# Expected programmer-error paths must emit push_error in production. Suppress
	# their console printing only during these calls; no game/input bypass.
	var printing:=Engine.print_error_messages;Engine.print_error_messages=false
	var result:Variant=action.call()
	Engine.print_error_messages=printing
	check(result is Dictionary,"programmer-error path returned a result: "+reason)
	if result is Dictionary:check(not result.ok and result.get("internal_reason")==reason and result.reason=="That item action could not be completed.","expected refusal: "+reason)
	check(snapshot(host)==before,"refusal changes nothing: "+reason)
func scope_and_stores():
	var cave:=Cave.new();hosts.append(cave)
	var museum:=Museum.new();hosts.append(museum)
	var jungle:=ordinary()
	var hive:=Hive.new();hosts.append(hive)
	for pair in [[cave,"cave",CAVE],[museum,"museum",MUSEUM],[jungle,"jungle",JUNGLE],[hive,"jungle",Catalog.Wax.ITEM]]:
		check(Grants.scope(pair[0])==pair[1] and Grants.known(pair[0],pair[2]),"host-to-scope admission "+str(pair[1]))
	check(not Grants.known(cave,MUSEUM) and not Grants.known(museum,JUNGLE),"earlier scopes refuse later Act1 ids")
	check(Grants.known(jungle,ACT2) and not Grants.known(jungle,"not-an-item"),"Act2 row admission and unknown refusal")
	for host in [museum,jungle,hive]:
		var alias:Array=Grants.pack(host);alias.append(CAVE)
		check(CAVE in Grants.pack(host),"stored pack accessor returns live array")
	check(Grants.grant(museum,MUSEUM,{"cap":false}).ok and MUSEUM in museum.carried_collected,"Museum grant writes its live store")
	check(Grants.grant(hive,Catalog.Wax.ITEM,{"cap":false}).ok and Catalog.Wax.ITEM in hive.carried_inventory.collected,"Hive grant writes its dictionary list")
	var derived:Array=Grants.pack(cave);derived.clear()
	check(cave.owners==[CAVE],"Cave accessor returns read-only-derived copy")
	error_unchanged(cave,func():return Grants.grant(cave,CAVE,{"cap":false}),"host has no writable pack (Cave is derived)")
	error_unchanged(cave,func():return Grants.commit(cave,[]),"host has no writable pack (Cave is derived)")
func grant_rules():
	var host:=ordinary()
	error_unchanged(host,func():return Grants.grant(host,"not-an-item"),"unknown item")
	error_unchanged(host,func():return Grants.grant(host,CAVE),"capacity check needs full_text")
	error_unchanged(host,func():return Grants.grant(host,CAVE,{"cap":false,"history":"typo"}),"unknown history policy")
	error_unchanged(host,func():return Grants.grant(host,CAVE,{"cap":false,"duplicate":"typo"}),"unknown duplicate policy")
	error_unchanged(host,func():return Grants.grant(host,CAVE,{"cap":false,"history":"act2"}),"unknown Act2 history item")
	error_unchanged(host,func():return Grants.grant(host,CAVE,{"cap":false,"note":"not-a-note"}),"unknown journal note")
	check(Grants.grant(host,CAVE,{"cap":true,"full_text":"This owner's exact full text."}).ok,"known id appended")
	check(host.carried_collected==[CAVE] and host.quest_state.is_empty() and host.messages.is_empty(),"history/text defaults are silent")
	var before:=snapshot(host)
	check(not Grants.grant(host,CAVE).ok and snapshot(host)==before,"duplicate default refuses before capacity and atomically")
	var skipped:Dictionary=Grants.grant(host,CAVE,{"duplicate":"skip","cap":false,"text":"Still owned.","hud":true})
	check(skipped.ok and not skipped.get("added",true) and host.carried_collected==before.pack and host.messages==["Still owned."] and host.interface_hud.refreshes==1,"skip only skips append; effects run and addedfalse")
	check(Grants.grant(host,CAVE,{"duplicate":"allow","cap":false}).ok and host.carried_collected==[CAVE,CAVE],"allow preserves unconditional append sites")
	var full:=ordinary();full.carried_collected=Catalog.ids("jungle").slice(0,64)
	check(full.carried_collected.size()==64 and ACT2 not in full.carried_collected and not Grants.room(full) and Grants.room(full,0),"capacity boundary uses combined pack count")
	before=snapshot(full)
	var result:Dictionary=Grants.grant(full,ACT2,{"full_text":"Exact original refusal."})
	check(not result.ok and result.reason=="Exact original refusal." and snapshot(full)==before,"full cap retains caller wording, no mutation")
	check(Grants.grant(full,ACT2,{"cap":false}).ok and full.carried_collected.size()==65,"capfalse preserves unchecked grant")
func histories_and_effects():
	var host:=ordinary()
	var opts:Dictionary={"cap":false,"duplicate":"allow","history":"act2"}
	check(Grants.grant(host,ACT2,opts).ok and Grants.grant(host,ACT2,opts).ok,"always history repeated grant actually executes")
	check(host.carried_collected==[ACT2,ACT2] and host.quest_state.act2_items.collected==[ACT2,ACT2],"always preserves duplicate history spelling")
	for first in [false,true]:
		var once:=ordinary();var charged:=ACT2+":charged:yellow"
		var once_opts:Dictionary={"cap":false,"duplicate":"allow","history":"act2_once","sync":true,"sync_first":first}
		check(Grants.grant(once,charged,once_opts).ok and Grants.grant(once,charged,once_opts).ok,"once history repeated grant executes, syncfirst "+str(first))
		check(once.quest_state.act2_items.collected==[ACT2] and once.quest_state.act2_items.carried==[charged,charged],"base id history once, carried rebuilt with charged ids")
		check(not once.sync_packets.is_empty(),"real Items.sync observed by host getter")
		if not once.sync_packets.is_empty():check(once.sync_packets[0].collected==([] if first else [ACT2]),"sync_first controls history visible to actual sync")
	var owned:=ordinary();owned.carried_collected=Catalog.ids("jungle").filter(func(id):return id!=ACT2).slice(0,63)+[ACT2]
	var skip_full:Dictionary=Grants.grant(owned,ACT2,{"duplicate":"skip","history":"act2_once","sync":true,"full_text":"Full.","text":"Already owned.","note":"hive_flute_at_pit","hud":true})
	check(skip_full.ok and not skip_full.get("added",true) and owned.carried_collected.size()==64 and owned.quest_state.get("act2_items",{}).get("collected",[])==[ACT2],"full carried skip runs history/sync without append/cap refusal")
	check(owned.messages==["Already owned.",Journal.NOTICE] and owned.item_effects.saved.get("journal",[])==["hive_flute_at_pit"] and owned.interface_hud.refreshes==1,"skip keeps text Journal HUD")
	var none:=ordinary()
	check(Grants.grant(none,ACT2,{"cap":false,"history":"none","sync":true}).ok and none.quest_state.act2_items.carried==[ACT2] and none.quest_state.act2_items.collected==[],"syncnone works with absent packet")
	error_unchanged(none,func():return Grants.grant(none,CAVE,{"cap":false,"sync_first":true}),"sync_first needs sync")
	var no_quests:=NoQuests.new();hosts.append(no_quests)
	var printing:=Engine.print_error_messages;Engine.print_error_messages=false
	var refused:Variant=Grants.grant(no_quests,CAVE,{"cap":false,"sync":true})
	var missing_history:Variant=Grants.grant(no_quests,ACT2,{"cap":false,"history":"act2"})
	var null_result:Variant=Grants.grant(null,CAVE,{"cap":false})
	Engine.print_error_messages=printing
	check(refused is Dictionary and not refused.ok and refused.get("internal_reason")=="Act2 sync needs quest_state" and refused.reason=="That item action could not be completed." and no_quests.carried_collected.is_empty(),"syncnone missing quests refuses before append")
	check(missing_history is Dictionary and not missing_history.ok and missing_history.get("internal_reason")=="Act2 history needs quest_state" and missing_history.reason=="That item action could not be completed.","history missing quests refuses")
	check(null_result is Dictionary and not null_result.ok,"null host refuses")
	var effects:=ordinary()
	var old_packet:Dictionary=Items.initial();effects.quest_state.act2_items=old_packet
	check(Grants.grant(effects,ACT2,{"cap":false,"history":"act2_once","text":"Taken.","note":"hive_flute_at_pit","hud":true}).ok,"text Journal HUD options")
	check(old_packet==Items.initial() and effects.quest_state.act2_items.collected==[ACT2],"history deep copy retains old alias, missing packet fallback covered")
	check(effects.messages==["Taken.",Journal.NOTICE] and effects.item_effects.saved.journal==["hive_flute_at_pit"] and effects.interface_hud.refreshes==1,"text then Journal then HUD once")
	var malformed:=ordinary();malformed.quest_state.act2_items={"collected":0}
	error_unchanged(malformed,func():return Grants.grant(malformed,ACT2,{"cap":false,"history":"act2"}),"invalid Act2 history packet")
	var no_hud:=ordinary();no_hud.interface_hud=null
	check(Grants.grant(no_hud,CAVE,{"cap":false,"hud":true}).ok and no_hud.carried_collected==[CAVE],"optional missing HUD does not change grant")
func transactions():
	var host:=ordinary();host.carried_collected=["legacy-existing-unchecked"]
	var result:Array=[CAVE,"legacy-existing-unchecked"]
	check(Grants.commit(host,result).ok and host.carried_collected==result,"commit checks added only, keeps order and existing identities")
	error_unchanged(host,func():return Grants.commit(host,result+["new-unknown"]),"unknown item")
	error_unchanged(host,func():return Grants.commit(host,result,{"cap":true}),"capacity check needs full_text")
	error_unchanged(host,func():return Grants.commit(host,result,{"history_id":"new-unknown"}),"unknown item")
	var full:=ordinary();full.carried_collected=Catalog.ids("jungle").slice(0,64)
	var oversized:Array=full.carried_collected+[ACT2]
	var before:=snapshot(full)
	var refused:Dictionary=Grants.commit(full,oversized,{"cap":true,"full_text":"Transaction full."})
	check(not refused.ok and refused.reason=="Transaction full." and snapshot(full)==before,"commit explicit cap refuses atomically")
	check(Grants.commit(full,oversized).ok and full.carried_collected.size()==65,"commit cap defaultfalse preserves unchecked sites")
	var history:=ordinary()
	check(Grants.commit(history,[ACT2,ACT2_B],{"history":"act2_once","sync":true,"text":"One transaction.","hud":true}).ok,"transaction added histories")
	check(history.quest_state.act2_items.collected==[ACT2,ACT2_B] and history.quest_state.act2_items.carried==[ACT2,ACT2_B],"all added Act2 identities retain order")
	check(history.messages==["One transaction."] and history.interface_hud.refreshes==1,"transaction shared effects happen once")
	check(Grants.commit(history,[],{"history":"act2","history_id":ACT2}).ok and history.quest_state.act2_items.collected==[ACT2,ACT2_B,ACT2],"history_id records reward without added pack entry")
	var hive:=Hive.new();hosts.append(hive)
	var alias:Array=Grants.pack(hive)
	check(Grants.commit(hive,[Catalog.Wax.ITEM]).ok and alias==[] and Grants.pack(hive)==[Catalog.Wax.ITEM] and hive.carried_inventory.equipped_item=="unchanged","Hive transaction replaces array as existing wayC does")
	check(Grants.commit(hive,Grants.pack(hive)).ok and Grants.pack(hive)==[Catalog.Wax.ITEM],"Hive self-commit does not clear the array")
	error_unchanged(hive,func():return Grants.grant(hive,CAVE,{"cap":false,"sync":true}),"Act2 sync needs Jungle-family pack")
func inplace_transactions():
	var hive:=Hive.new();hosts.append(hive)
	var alias:Array=Grants.pack(hive)
	check(Grants.commit(hive,[Catalog.Wax.ITEM],{"preserve_alias":true}).ok,"explicit in-place transaction admits original wax")
	check(alias==[Catalog.Wax.ITEM],"Hive flute original array aliases see the committed items")
	alias.append(CAVE)
	check(Grants.pack(hive)==[Catalog.Wax.ITEM,CAVE],"Hive flute keeps the same live array for existing owners")
	check(Grants.commit(hive,Grants.pack(hive),{"preserve_alias":true}).ok and alias==[Catalog.Wax.ITEM,CAVE],"in-place self-commit never clears its source")
func run():
	scope_and_stores();grant_rules();histories_and_effects();transactions();inplace_transactions()
	check(Engine.print_error_messages,"expected-error printing restored")
	for host in hosts:host.free()
	if failures==0:print("PASS item grants shared contract: live Museum/Jungle/Hive, derived Cave refusals, scope map, atomic refusals, cap defaults, duplicates/history/sync/text/Journal/HUD and transaction aliases")
	quit(0 if failures==0 else 1)
