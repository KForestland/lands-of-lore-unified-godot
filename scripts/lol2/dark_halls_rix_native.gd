extends RefCounted
## Actor57 world bridge. Original groups/fanfix run in the shared VM.
## Named modern replacements: the approved spell/half-health admission;
## immediate kind6 completion; plain talk status for the unhosted presentation.
## Only the known Rix soul-add command and talk-release receipt are adapted
## locally. Neither registers a game-wide opcode nor invents dialogue/loot.
const VM=preload("res://scripts/lol2/native_script_host.gd")
const AREA:="res://scripts/lol2/native_scripts/L7_DH.json"
const ACTOR:="actor:57"
static func _soul(vm:Object,command:Dictionary)->String:
 if str(command.get("raw_hex",""))!="ce0000000002":return "Only Rix's published soul +2 command is admitted."
 vm.stage_write("rix:reward","soul_delta",2)
 return ""
static func _two(vm:Object,command:Dictionary)->String:
 if str(command.get("raw_hex",""))=="020100002500":
  # The release presentation is not decoded. Keep an explicit receipt;
  # the owner shows status, without fabricated words or an invented movie.
  vm.stage_write("rix:talk","release_receipt",1);return ""
 return str(vm.call("_op_two",vm,command))
static func build(saved:Dictionary)->Dictionary:
 var vm:=VM.new()
 var error:String=vm.load_area(AREA)
 if not error.is_empty():return {"error":error}
 vm.register_opcode(206,_soul);vm.register_opcode(2,_two)
 vm.set_global(0x223D4,0) # Shared VM opcode2 player-counter gate, not a Rix story flag.
 if not saved.is_empty():
  error=vm.restore(saved)
  if not error.is_empty():return {"error":error}
 return {"error":"","vm":vm}
static func ran(rows:Array,group:int)->bool:
 return rows.any(func(row):return int(row.get("group",-1))==group and row.get("status")=="ran")
static func rescue(saved:Dictionary,health:int)->Dictionary:
 if health<=0 or health>100:return {"ok":false,"reason":"Rix must be alive and weakened first."}
 var loaded:=build(saved)
 if not loaded.error.is_empty():return {"ok":false,"reason":loaded.error}
 var vm:RefCounted=loaded.vm
 var hit:={"word0":0x20,"word2":0,"dword_1e":0,"dword_26":health,"global_23331":0,"context":ACTOR}
 if int(vm.field(ACTOR,"byte_0x25"))==0:
  if not ran(vm.fire_event(ACTOR,9,hit),14102):return {"ok":false,"reason":"Rix's first hit did not admit."}
 hit.word0=0x40
 var rescue_rows:Array=vm.fire_event(ACTOR,9,hit)
 if not ran(rescue_rows,14234):return {"ok":false,"reason":"Rix rescue did not admit: "+JSON.stringify(rescue_rows)}
 # Lead-approved immediate completion; no native animation duration claim.
 var completion:Array=vm.fire_event(ACTOR,6,{"caller_byte":0,"caller_byte_2":0,"context":ACTOR})
 if not ran(completion,14330) or int(vm.field(ACTOR,"byte_0x25"))!=100 or int(vm.field("rix:reward","soul_delta"))!=2:
  return {"ok":false,"reason":"Rix completion did not admit: "+JSON.stringify(completion)}
 return {"ok":true,"native":vm.snapshot(),"soul_delta":2}
static func talk(saved:Dictionary)->Dictionary:
 var loaded:=build(saved)
 if not loaded.error.is_empty():return {"ok":false,"reason":loaded.error}
 var vm:RefCounted=loaded.vm
 if int(vm.field(ACTOR,"byte_0x25"))!=100:return {"ok":false,"reason":"Rix is not free."}
 if int(vm.field("rix:talk","release_receipt",0))==1:return {"ok":true,"native":vm.snapshot()}
 if not ran(vm.fire_event(ACTOR,5,{"caller_byte":0,"caller_byte_2":0,"context":ACTOR}),14388):
  return {"ok":false,"reason":"Rix's talk did not admit."}
 if int(vm.field(ACTOR,"byte_0x25"))!=100 or int(vm.field("rix:talk","release_receipt",0))!=1:
  return {"ok":false,"reason":"Rix talk did not retain its rescue/release receipt."}
 return {"ok":true,"native":vm.snapshot()}
