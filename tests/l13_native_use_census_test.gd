extends SceneTree
## Independent source-event census plus real VM vectors; no gameplay/earned claim.
const Native=preload("res://scripts/lol2/native_script_host.gd")
const Actions=preload("res://scripts/lol2/generic_object_actions.gd")
class Binding extends Node:
 var native
 func fire(ref:String,event:int,parameters:Dictionary)->Array:return native.fire_event(ref,event,parameters)
class BridgeCase extends "res://scripts/lol2/l13_bridge.gd":
 func _ready()->void:pass
 func _physics_process(_delta:float)->void:pass
 func restore()->void:pass
class Host extends Node3D:
 var quest_state:Dictionary={}
const DELEGATED={174:"l13_altar.gd",175:"l13_altar.gd",325:"l13_altar.gd",326:"l13_altar.gd",362:"l13_elevator.gd",363:"l13_eggs.gd",420:"l13_egg_door.gd"}
func _initialize()->void:run.call_deferred()
func check(ok:bool,message:String)->bool:
 if not ok:printerr("FAIL L13 native use census: ",message);quit(1)
 return ok
func run()->void:
 var document:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/native_scripts/L13_RC.json"))
 var hosted:Dictionary={}
 for row:Dictionary in Actions.ROWS.L13_RC:
  if int(row.event)==4:hosted[row.ref]=row
 var total:=0;var vectors:=0;var blocked:Array=[];var known_unavailable:=0
 for object:Dictionary in document.objects:
  if object.table!="prop":continue
  var uses:Array=object.events.filter(func(e):return int(e.kind)==4)
  if uses.is_empty():continue
  total+=1
  var id:int=int(object.index)
  if DELEGATED.has(id):
   if not check(FileAccess.file_exists("res://scripts/lol2/"+DELEGATED[id]),"Dedicated puzzle owner exists for "+object.ref):return
   continue
  if not check(hosted.has(object.ref),"Unhosted native use event: "+object.ref):return
  var vm:=Native.new()
  if not check(vm.load_area("res://scripts/lol2/native_scripts/L13_RC.json").is_empty(),"Source export loads"):return
  var before:Dictionary=vm.snapshot()
  var target_binding:=Binding.new();target_binding.native=vm
  var results:Array=Actions.dispatch_native(target_binding,hosted[object.ref]);target_binding.free()
  if hosted[object.ref].has("unavailable"):
   if not check(id==304 and vm.snapshot()==before and results.any(func(result):return result.status=="unhosted" and str(result.reasons).contains("opcode 196 byte 6")),"Known304 refusal must preserve native state atomically"):return
   known_unavailable+=1;continue
  var ran:bool=results.any(func(r):return r.status=="ran")
  print("NATIVE_USE ",object.ref," ",JSON.stringify(results))
  if not check(ran and vm.snapshot()!=before,"Source use must execute and change saved state: "+object.ref):return
  var saved:Dictionary=JSON.parse_string(JSON.stringify(vm.snapshot(),"",true,true))
  var fresh:=Native.new();fresh.load_area("res://scripts/lol2/native_scripts/L13_RC.json")
  if not check(fresh.restore(saved).is_empty() and fresh.snapshot()==vm.snapshot(),"Actual native saved state roundtrip: "+object.ref):return
  for nested:Dictionary in vm.enqueued_results:
   if nested.status=="unhosted":blocked.append({"ref":object.ref,"group":nested.group,"reasons":nested.reasons})
  if id==193:
   if not check(vm.field("prop:306",Native.FIELD_BYTE25,0)==1 and not vm.adapters_enabled.get("opcode14_arm5_noop",false),"193 arms306 and restores the no-op flag immediately"):return
   vm.reset_state();vm.set_adapter_enabled("opcode14_arm5_noop",true)
   var already_enabled:=Binding.new();already_enabled.native=vm
   Actions.dispatch_native(already_enabled,hosted[object.ref]);already_enabled.free()
   if not check(vm.adapters_enabled.get("opcode14_arm5_noop",false),"Scoped adapter preserves an originally enabled flag too"):return
  vectors+=1
 if not check(total==18 and vectors==10 and known_unavailable==1 and hosted.size()==11,"18 source props:7 dedicated +10 native mechanisms +1 honest unavailable304"):return
 print("NESTED_UNHOSTED ",JSON.stringify(blocked))
 if not check(blocked.is_empty(),"Nested callbacks must be qualified, not silently ignored"):return
 var host:=Host.new();root.add_child(host)
 var bridge:=BridgeCase.new();bridge.host=host;host.add_child(bridge)
 bridge.activate_from_switch()
 if not check(bridge.state().started and bridge.state().phase==0,"An unstarted physical bridge wakes through its own owner"):return
 host.quest_state[bridge.KEY].phase=3.5;bridge.activate_from_switch()
 if not check(bridge.state().phase==3.5,"Using an already-running bridge does not restart its wave clock"):return
 host.free()
 print("PASS L13 native-use census18:7delegated+10native working+1honest304; saved state and scoped193->306; bridge starts without resetting a running wave")
 quit()
