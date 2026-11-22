extends SceneTree
## Policy/model and atomic transaction contract; synthetic packets, no earned claim.
const Guard=preload("res://scripts/lol2/quest_resource_protection.gd")
const Grants=preload("res://scripts/lol2/item_grants.gd")
const Controller=preload("res://scripts/lol2/player_item_controller.gd")
const ALOE="act2:L14_HT:item68"
const PAINT="act2:L14_HT:item72"
const LEAF="act2:L10_DC:silverleaf159"
class Host extends Node:
 var carried_collected:Array=[]
 var quest_state:Dictionary={}
 var carried_inventory:Variant=null
 var item_effects:Node=null
 var starting_magic:Node=null
 var curse:Node=null
 var player_form:=0
 var inventory:Node=null
 var message:=""
 func save_feedback(text:String):message=text
 func area_snapshot()->Dictionary:return {}
class Magic extends Node:
 var hp:=30
 func health()->int:return hp
 func magic_state()->Dictionary:return {"player":{"mana":100,"maximum":100}}
func _initialize():run.call_deferred()
func run():
 var output:Array=[]
 assert(OS.execute("python3",[ProjectSettings.globalize_path("res://tools/build_quest_resource_policy.py"),"--check"],output,true)==0,str(output))
 var q:Dictionary={"l8_larkhon":{"slots":{"mix:serum":{"committed":true}}}}
 assert(Guard.refusal([ALOE,PAINT],[PAINT],q,q).contains("aloe"))
 assert(Guard.refusal([ALOE,PAINT],[ALOE],q,q).contains("Poison Paint"))
 var extra:="jungle:aloe0"
 assert(Guard.refusal([ALOE,extra],[ALOE],q,q).is_empty(),"Exact reserved Aloe must not reserve another definition109 identity")
 assert(Guard.refusal([LEAF],[],q,q).contains("glass pyramid"))
 assert(Guard.refusal([LEAF,"act2:L10_DC:silverleaf160"],[LEAF],q,q).is_empty(),"True Silverleaf spares remain usable")
 var after:Dictionary=q.duplicate(true);after.l16_greenhouse={"silverleaf":LEAF}
 assert(Guard.refusal([LEAF],[],q,after).is_empty(),"Goal consumption releases its own reserve")
 var fake:Dictionary=q.duplicate(true);fake.unrelated_story={"done":true}
 assert(not Guard.refusal([LEAF],[],q,fake).is_empty(),"An unrelated state change is no bypass")
 var stone:="act2:L13_RC:dreamstone"
 var slot:Dictionary={"committed":true,"occupied":stone,"receipts":["citadel:exit_lock104"]}
 after=q.duplicate(true);after.l13_exit_lock={"slots":{"citadel:exit_lock104":slot}}
 assert(Guard.refusal([stone],[],q,after).is_empty(),"Retrievable supply counts outside the live pack")
 after=q.duplicate(true);after.l14_chamber_voices={"offered":true}
 assert(Guard.refusal([stone],[],q,after).is_empty(),"Final chalice use is allowed")
 var bow:="act2:L12_CM:blue_bow";var horn:="act2:L19_BC:horn"
 assert(not Guard.refusal([bow,horn],[horn],q,q).is_empty(),"Future exact bow step precedes the finale OR")
 after=q.duplicate(true);after.l20_armory={"fire":true}
 assert(Guard.refusal([bow,horn],[horn],after,after).is_empty())
 assert(not Guard.refusal([horn],[],after,after).is_empty(),"Only one ending alternative remains reserved")
 var leaf_row:Dictionary=Guard.data().obligations.filter(func(row):return row.name=="City pyramid")[0]
 var early:Dictionary={"l10_silverleaf":{"grown":true},"l10_silverleaf_harvest":{"picked":["159"]}}
 assert(Guard.needed(leaf_row,early,[LEAF])==4)
 after=early.duplicate(true);after.l8_tribe={"slots":{"tribe:initiation":{"committed":true,"occupied":LEAF}}}
 assert(Guard.needed(leaf_row,after,[])==3)
 assert(Guard.refusal([LEAF],[],early,after).is_empty(),"First mandatory leaf offer remains possible with qualified future harvest")
 early.l10_silverleaf_harvest.picked=[]
 for target in Guard.data().leaf_chain.trees:early.l10_silverleaf_harvest.picked.append(str(int(target)))
 after=early.duplicate(true);after.l8_tribe={"slots":{"tribe:initiation":{"committed":true,"occupied":LEAF}}}
 assert(not Guard.refusal([LEAF],[],early,after).is_empty(),"A mandatory offer is no blanket bypass when all twelve sources are exhausted")
 var serum:="act2:L8_SJ:shaman_amaranth"
 assert(Guard.needed(leaf_row,early,[LEAF,serum])==3,"Before initiation, owned Serum still needs initiation, mix and City leaves")
 assert(Guard.needed(leaf_row,q,[LEAF])==1)
 var five:Array=[]
 for target in range(159,164):five.append("act2:L10_DC:silverleaf"+str(target))
 assert(Guard.refusal(five,five.slice(0,4),early,early).is_empty(),"A true spare above remaining route demand is usable")
 assert(not Guard.refusal(five.slice(0,4),five.slice(0,3),early,early).is_empty(),"Earlier route demands cannot be spent down to the City-only minimum")
 var host:=Host.new();root.add_child(host);host.carried_collected=[LEAF]
 assert(not Grants._options_error(host,[],{"owner_update":{}},false).is_empty(),"Malformed checkpoint descriptor is refused before publication")
 var saved:Dictionary=host.quest_state.duplicate(true)
 assert(not Grants.transition(host,[],fake).ok and host.carried_collected==[LEAF] and host.quest_state==saved,"Denial is atomic, including proposed quest flags")
 assert(Grants.transition(host,[],{"l16_greenhouse":{"silverleaf":LEAF}}).ok)
 assert(host.carried_collected==[] and host.quest_state.l16_greenhouse.silverleaf==LEAF)
 var magic:=Magic.new();host.add_child(magic);host.starting_magic=magic
 var controller:=Controller.new();controller.host=host
 assert(controller.no_effect_reason(ALOE)=="You are not hurt.")
 assert(controller.no_effect_reason(LEAF)=="Your mana is already full.")
 magic.hp=24;host.carried_collected=[ALOE]
 assert(not controller.use(ALOE,true) and ALOE in host.carried_collected and controller.item_refusal.contains("Temple priest"),"Wounded self-use also protects the exact last-needed copy before any healing effect")
 magic.hp=30
 for id in controller.Catalog.consumables():
  if controller.Catalog.use_kind(id) in ["ironwood_sap","amaranth_serum","vels_fruit","inert_food","mandrake","dampen_charm"]:
   assert(not controller.no_effect_reason(id).is_empty(),"Known no-op must refuse before its effects: "+str(id))
 controller.free()
 # Every compiled conjunctive recipe checks all accepted identities and every
 # committed slot, rather than merely its total pickup history.
 for row in Guard.data().obligations:
  assert(int(row.need)>0 and not row.model_frontier.is_empty())
 print("PASS source-derived reserves; exact IDs, spare copies, release, recoverable slots, future bow + ending alternatives; atomic denial and goal commit")
 quit()
