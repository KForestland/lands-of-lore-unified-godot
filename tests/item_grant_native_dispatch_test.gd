extends SceneTree
## Isolated synthetic command/table vectors through the real VM + progression.fire.
## These prove dispatch contracts; they are not player-input or earned evidence.
const Native=preload("res://scripts/lol2/native_script_host.gd")
const Progression=preload("res://scripts/lol2/act2_progression.gd")
const Tables=preload("res://scripts/lol2/item_grant_tables.gd")
const Definitions=preload("res://scripts/lol2/item_definitions.gd")
const Grants=preload("res://scripts/lol2/item_grants.gd")
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
const Catalog=preload("res://scripts/lol2/item_catalog.gd")
const Journal=preload("res://scripts/lol2/my_journal.gd")
class Effects extends RefCounted:
 var saved:Dictionary={"journal":[]}
 func state()->Dictionary:return saved
class Map extends Node3D:
 var area_id:="L8_SJ"
 var carried_collected:Array=[]
 var carried_inventory:Variant=null
 var quest_state:Dictionary={}
 var item_effects:Effects=Effects.new()
 var interface_hud:Variant=null
 var player:Variant=null
 var messages:Array=[]
 func save_feedback(text:String):messages.append(text)
var failed:=false
var hosts:Array=[]
var sources:Array=[]
func check(ok:bool,message:String):
 if not ok:failed=true;push_error(message)
func _initialize():run.call_deferred()
func command(group:int,definition:int)->Dictionary:
 var bytes:=PackedByteArray();bytes.resize(12);bytes[0]=3;bytes[1]=1
 bytes.encode_u32(4,int(Definitions.row(definition).identity));bytes[8]=1
 return {"opcode":3,"kind":1,"target":0,"file_offset":group*10+6,"raw_hex":bytes.hex_encode()}
func event(group:int,kind:int=4)->Dictionary:
 var bytes:=PackedByteArray();bytes.resize(10);bytes[0]=10;bytes[1]=kind;bytes.encode_u16(2,group)
 if kind==6:bytes[4]=0x14
 return {"kind":kind,"stream":1,"group":group,"file_offset":group*10+8,"raw_hex":bytes.hex_encode(),"predicate":null}
func fixture()->Dictionary:
 var data:Dictionary={"format":Native.FORMAT,"area":"L8_SJ","source":{},"predicate_table":{"entries":[]},"groups":[],"objects":[]}
 var rows:Dictionary={}
 var definitions:Array=[75,110,22,119]
 var actions:Array=["grant","log","owner","grant"]
 for index in 4:
  var group:int=(index+1)*100;var cmd:=command(group,definitions[index])
  data.groups.append({"stream":1,"group":group,"file_offset":group*10,"commands":[cmd]})
  data.objects.append({"ref":"prop:"+str(index+1),"placement_hex":"00".repeat(64),"events":[event(group)]})
  rows[str(cmd.file_offset)]={"action":actions[index],"definition":definitions[index],"identity":int(Definitions.row(definitions[index]).identity),"target":0,"arg":1,"stream":1,"group":group,"callers":[{"object":"prop:"+str(index+1),"event":4}],"same_definition":[],"blocked_by":[],"full_text":"There is no room.","text":"A scroll is yours.","note":"hive_flute_at_pit"}
 rows["4006"].same_definition=["act2:L8_SJ:shaman_amaranth"];rows["4006"].blocked_by=["act2:L8_SJ:shaman_amaranth"]
 # Nested enqueue: an outer prop fires kind6 on prop2. Provenance must be inner.
 data.groups.append({"stream":1,"group":500,"file_offset":5000,"commands":[{"opcode":9,"kind":3,"target":2,"file_offset":5006,"raw_hex":"090302001500"}]})
 data.objects.append({"ref":"prop:5","placement_hex":"00".repeat(64),"events":[event(500)]})
 data.objects[1].events.append(event(200,6))
 rows["2006"].callers.append({"object":"prop:2","event":6})
 Tables._cache["L8_SJ"]={"version":1,"area":"L8_SJ","commands":rows}
 return data
func host(data:Dictionary)->Node:
 var map:=Map.new();hosts.append(map)
 var prog:=Progression.new();map.add_child(prog);prog.host=map;prog.area_id=map.area_id;prog.native=Native.new()
 check(prog.native.load_area_data(data)=="","fixture VM loads")
 prog.native.set_adapter_enabled("opcode3_item_grant",true);prog.native.set_global(0x223D4,0)
 prog.native.bind_target("0x03:2","prop:2")
 prog.connect_item_sources();prog.native.item_source.connect(func(source:Dictionary):sources.append(source.duplicate(true)))
 return prog
func requests(prog:Node)->int:
 return prog.native_log.filter(func(row):return row.get("type","")=="item").size()
func fire(prog:Node,index:int)->Array:
 return prog.fire("prop:"+str(index),4,{"arg_c":0})
func ran(result:Array)->bool:return result.size()==1 and result[0].status=="ran"
func state(map:Node)->Dictionary:
 return {"pack":map.carried_collected.duplicate(),"quests":map.quest_state.duplicate(true),"messages":map.messages.duplicate(),"effects":map.item_effects.saved.duplicate(true)}
func run():
 var data:=fixture();var prog:=host(data);var map:Node=prog.host;var id:=Tables.id_of("L8_SJ",1006)
 check(ran(fire(prog,1)) and requests(prog)==1,"real fire/VM emits first grant")
 check(map.carried_collected==[id] and map.quest_state.act2_items.carried==[id] and map.quest_state.act2_items.collected==[id],"pack and packet contain new native id once")
 check(map.messages==["A scroll is yours.",Journal.NOTICE] and map.item_effects.saved.journal==["hive_flute_at_pit"],"text and real Journal effects run")
 var before:=state(map)
 check(ran(fire(prog,1)) and requests(prog)==2 and state(map)==before,"second group really runs; receipt prevents duplicate effects")
 map.carried_collected.erase(id);Items.sync(map);before=state(map)
 check(ran(fire(prog,1)) and requests(prog)==3 and state(map)==before,"used native item stays spent on repeated group")
 # JSON round trip of existing packet keys; a fresh host retains the spent receipt.
 var saved:Dictionary=JSON.parse_string(JSON.stringify({"pack":map.carried_collected,"packet":map.quest_state.act2_items}))
 check(Items.validate(saved.packet)=="","native receipt passes existing save validator")
 var loaded:=host(data);loaded.host.carried_collected=saved.pack;loaded.host.quest_state.act2_items=saved.packet
 check(ran(fire(loaded,1)) and loaded.host.carried_collected.is_empty() and loaded.host.quest_state.act2_items.collected==[id],"fresh host with loaded spent receipt never gives item twice")
 for index in [2,3]:
  before=state(map);var count:=requests(prog)
  check(ran(fire(prog,index)) and requests(prog)==count+1 and state(map)==before,"log/owner really runs with no pack/packet/text/Journal effects "+str(index))
 check(Grants.grant(map,"act2:L8_SJ:shaman_amaranth",{"cap":false,"history":"act2_once","sync":true}).ok,"rival setup uses production API")
 before=state(map);var count:=requests(prog)
 check(ran(fire(prog,4)) and requests(prog)==count+1 and state(map)==before,"blocked_by prevents second definition by another id")
 Tables._cache.L8_SJ.commands["4006"].blocked_by=[]
 var clean:=host(data)
 check(ran(fire(clean,4)) and clean.host.carried_collected.is_empty(),"unsafe same-definition policy refused even without collected rival")
 # No gate bypass: all these use actual VM paths.
 var disabled:=host(data);disabled.native.set_adapter_enabled("opcode3_item_grant",false)
 check(not ran(fire(disabled,1)) and requests(disabled)==0 and disabled.host.carried_collected.is_empty(),"disabled adapter never emits or grants")
 var unknown:=host(data);unknown.native.globals.erase(0x223D4)
 check(not ran(fire(unknown,1)) and requests(unknown)==0,"unknown native global never emits")
 var suppressed:=host(data);suppressed.native.set_global(0x223D4,1)
 check(ran(fire(suppressed,1)) and requests(suppressed)==0 and suppressed.host.carried_collected.is_empty(),"nonzero native global runs but suppresses item")
 var full:=host(data);full.host.carried_collected=Catalog.ids("jungle").slice(0,64)
 before=state(full.host)
 check(ran(fire(full,1)) and requests(full)==1 and state(full.host)==before,"capacity refusal leaves packet and effects unchanged")
 sources.clear();count=requests(prog)
 check(ran(fire(prog,5)) and requests(prog)==count+1,"outer native group really enqueues inner item group")
 check(sources.size()==1 and sources[0].object=="prop:2" and int(sources[0].event)==6 and int(sources[0].group)==200,"nested VM object/event overrides outer progression context")
 # Disabling a table grant must not invalidate items already saved.
 Tables._cache.L8_SJ.commands["1006"].action="log"
 check(Items.valid(id) and Items.validate(saved.packet)=="","saved native ids survive policy reverting to log")
 Tables._cache.erase("L8_SJ")
 for map_host in hosts:map_host.free()
 print("PASS native dispatch fixture: actual groups repeated, receipt/spent/load, log/owner/rival, native gates, capacity, nested provenance and retired policy" if not failed else "FAIL native dispatch fixture")
 quit(1 if failed else 0)
