extends SceneTree
const Guard=preload("res://scripts/lol2/quest_resource_protection.gd")
class PriestCase extends "res://scripts/lol2/l10_priest.gd":
 func _ready()->void:pass
 func _process(_delta:float)->void:pass
 func available()->bool:return true
 func reachable()->bool:return true
class Tombs extends Node:
 func opened(_id:String)->bool:return true
class Host extends Node3D:
 var carried_collected:Array=[]
 var carried_inventory:Variant=null
 var quest_state:Dictionary={}
 var player_form:=0
 func area_snapshot()->Dictionary:return {}
class ChargeHost extends Host:
 var starting_magic:Node
 var hand_item:=""
class MagicSpy extends Node:
 var casts:=0
 func use_stored_charge_from_interface(_school:String,_charge:int)->bool:casts+=1;return true
class NoPackHost extends Node:
 var quest_state:Dictionary={}
 var message:=""
 func area_snapshot()->Dictionary:return {}
 func save_feedback(text:String)->void:message=text
class ControllerCase extends "res://scripts/lol2/player_item_controller.gd":
 var owned:Array=[]
 var saved:Dictionary=preload("res://scripts/lol2/player_item_state.gd").initial()
 func carried()->Array:return owned
 func state()->Dictionary:return saved
 func can_consume(_id:String)->bool:return true
var failures:=0
func check(ok:bool,message:String)->void:
 if not ok:failures+=1;printerr("FAIL R131: ",message)
func _initialize()->void:run.call_deferred()
func run()->void:
 var row:Dictionary=Guard.data().obligations.filter(func(r):return r.name=="City pyramid")[0]
 var serum:="act2:L8_SJ:shaman_amaranth"
 var leaf:="act2:L10_DC:silverleaf159"
 check(Guard.needed(row,{},[serum,leaf])==3,"Owned Serum before initiation still needs initiation + mix + pyramid leaves")
 check(not Guard.past_larkhon({},"L13_RC"),"Area number alone cannot prove the Larkhon mix happened")
 check(not Guard.past_larkhon({},"L20_BB"),"Even a late/debug load cannot silently invent a completed story step")
 check(not Guard.matches(row,null) and not Guard.matches(row,7) and not Guard.matches(row,"unknown"),"Malformed/unknown pack entries are safe nonmatches")
 var initiated:Dictionary={"l8_tribe":{"slots":{"tribe:initiation":{"committed":true}}}}
 check(Guard.needed(row,initiated,[serum,leaf])==2,"After initiation, Serum removes just the actual shaman trade demand")
 check(not Guard.refusal([serum,leaf], [serum], initiated,initiated).contains("shaman"),"Refusal names only outstanding steps")
 for value in [null,[],{}, {"version":1,"obligations":[]}]:check(Guard.parse_policy(value).is_empty(),"Invalid/missing policy rejected without typed-null crash")
 check(not Guard.parse_policy(Guard.data()).is_empty(),"Compiled real policy passes runtime shape admission")
 for obligation in Guard.data().obligations:
  var completed:Dictionary={}
  for condition in obligation.done:
   var branch:Dictionary=completed
   var path:Array=condition.path
   for i in range(path.size()-1):
    if not branch.has(path[i]):branch[path[i]]={}
    branch=branch[path[i]]
   if condition.get("all_committed",false):
    var slots:Dictionary={}
    for target in condition.targets:slots[target]={"committed":true,"occupied":""}
    branch[path[-1]]=slots
   else:branch[path[-1]]="finished" if path[-1]=="output" or path[-1]=="silverleaf" else true
  check(Guard.needed(obligation,completed,[])==0,"Completion releases "+str(obligation.name))
 # The actual owners, not synthetic flat imitations, qualify these containers.
 var Slots=load("res://scripts/lol2/l13_exit_lock_state.gd")
 var stone:="act2:L13_RC:dreamstone"
 var inserted:Dictionary=Slots.insert(Slots.initial(),[stone],stone)
 check(inserted.ok and Guard.refusal([stone],inserted.inventory,{}, {Slots.KEY:inserted.state}).is_empty(),"Actual State.insert last Dreamstone counts as recoverable")
 var guard_script:GDScript=load("res://scripts/lol2/quest_resource_protection.gd")
 var bundled:Variant=guard_script.get_script_constant_map().get("Bundled")
 check(bundled is GDScript and bundled.resource_path=="res://scripts/lol2/quest_resource_policy_data.gd","Runtime policy is a real resolved script preload, not a dynamic JSON path")
 # R131b malformed policy is cached once and holds loss, never grants.
 var valid_policy:Dictionary=Guard.data().duplicate(true)
 for field in ["truthy","all_committed","at_least"]:
  var malformed:Dictionary=valid_policy.duplicate(true)
  malformed.obligations[0].done[0][field]="bad"
  check(Guard.parse_policy(malformed).is_empty(),"Malformed condition rejected: "+field)
 for field in ["slots","recoverable"]:
  var malformed:Dictionary=valid_policy.duplicate(true)
  malformed.obligations[0][field]=[{"area":12,"path":true}]
  check(Guard.parse_policy(malformed).is_empty(),"Malformed source rejected: "+field)
 Guard.policy={};Guard.policy_loaded=true;Guard.policy_warning=true
 check(Guard.data().is_empty() and Guard.data().is_empty(),"Invalid result stays cached instead of reparsing bundled rules")
 check(Guard.refusal([], [stone], {},{}).is_empty(),"Missing policy never blocks pickups or rewards")
 check(Guard.refusal([stone], [stone], {},{}).is_empty(),"Missing policy permits unchanged ownership")
 check(not Guard.refusal([stone], [], {},{}).is_empty(),"Missing policy holds a real removal")
 var gains:=Host.new();root.add_child(gains)
 var Grants=load("res://scripts/lol2/item_grants.gd")
 check(Grants.check_commit(gains,[stone]).ok and gains.carried_collected.is_empty(),"Shared admission is pure and permits gains with missing rules")
 check(Grants.commit(gains,[stone]).ok and gains.carried_collected==[stone],"Actual gain commit stays possible with missing policy")
 check(not Grants.commit(gains,[]).ok and gains.carried_collected==[stone],"Actual loss is denied atomically with missing policy")
 # Missing-policy denial happens before the real stored-charge callback.
 var charge_host:=ChargeHost.new();root.add_child(charge_host)
 var spy:=MagicSpy.new();charge_host.add_child(spy);charge_host.starting_magic=spy
 var controller:=ControllerCase.new();controller.host=charge_host
 var charged:="act2:L10_DC:item44:charged:yellow"
 controller.owned=[charged];charge_host.carried_collected=[charged]
 var Stored=load("res://scripts/lol2/player_stored_globes.gd")
 check(Stored.ready(controller,charged),"Actual stored-globe readiness passes before fault injection")
 check(not Stored.cast(controller,charged) and spy.casts==0 and charge_host.carried_collected==[charged] and not controller.item_refusal.is_empty(),"Refused actual stored-globe admission neither casts nor replaces ownership and displays its refusal")
 controller.free();charge_host.free()
 gains.free();Guard.policy=valid_policy
 # Malformed host fault at commit, after ordinary consume preflight: the
 # central internal error is returned AND shown exactly as a plain sentence.
 var no_pack:=NoPackHost.new();root.add_child(no_pack)
 controller=ControllerCase.new();controller.host=no_pack;controller.owned=["museum:item999:Throwing_dagger"]
 var previous_printing:=Engine.print_error_messages;Engine.print_error_messages=false
 var consumed:bool=controller.consume_item(controller.owned[0])
 Engine.print_error_messages=previous_printing
 check(not consumed and no_pack.message=="That item action could not be completed." and controller.owned.size()==1,"consume_item commit error is visible and conserves ownership")
 controller.free();no_pack.free()
 var Den=load("res://scripts/lol2/thieves_den_state.gd")
 var pending:Dictionary=Den.initial();pending.room="TINT"
 check(Den.offer(pending,"act2:L12_CM:blue_bow",true),"Pure Den offer can construct the source input plan")
 check(not Den.validate(pending).is_empty(),"A pre-take cursor cannot be saved; valid Den saves hold only after take has already run")
 var earlier:Dictionary=initiated.duplicate(true)
 var backtracked:Dictionary={}
 check(not Guard.refusal([leaf],[leaf],earlier,backtracked).is_empty(),"Increasing demand cannot silently worsen an already-short pack")
 # Fault injection at the FINAL publication: the two pure Ankh plans
 # succeed, but malformed history refuses the final shared commit. No first
 # live transition is allowed to leak through that refusal.
 var host:=Host.new();root.add_child(host)
 var tombs:=Tombs.new();tombs.name="L10Tombs";host.add_child(tombs)
 var priest:=PriestCase.new();priest.host=host;host.add_child(priest)
 var Ankh=load("res://scripts/lol2/l10_ankh_state.gd")
 host.carried_collected=[priest.BRACERS,Ankh.FULL]
 host.quest_state={priest.KEY:{"version":1,"urn_given":true},Ankh.KEY:Ankh.initial(),"act2_items":{"collected":"injected invalid history"}}
 var old_pack:Array=host.carried_collected.duplicate()
 var old_state:Dictionary=host.quest_state.duplicate(true)
 var printing:=Engine.print_error_messages;Engine.print_error_messages=false
 var refused:Dictionary=priest.exchange_ashes(Ankh.FULL)
 Engine.print_error_messages=printing
 check(not refused.ok and refused.get("internal_reason")=="invalid Act2 history packet" and refused.reason=="That item action could not be completed.","Final admission failure stays an internal detail with a plain player line")
 check(host.carried_collected==old_pack and host.quest_state==old_state,"Priest final failure publishes neither half-trade nor pack/history change")
 host.free()
 print("PASS R131 reserves, every completion predicate, actual recoverable State.insert, safe policy admission" if not failures else "R131 unit failures: "+str(failures))
 quit(1 if failures else 0)
