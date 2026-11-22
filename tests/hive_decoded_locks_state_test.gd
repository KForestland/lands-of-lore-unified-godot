extends SceneTree
const Locks=preload("res://scripts/lol2/hive_decoded_locks.gd")
const Native=preload("res://scripts/lol2/native_script_host.gd")
var failed:=false
func check(ok:bool,message:String):
 if not ok:failed=true;push_error(message)
class Host extends Node3D:
 var lines:Array=[]
 func save_feedback(line:String):lines.append(line)
func run_sequence(sequence:Array)->void:
 var owner:=Locks.new();var host:=Host.new();owner.host=host;owner.native=Locks.fresh_native()
 var expected:=0;var done:=false
 for id in sequence:
  if not done:
   if id==Locks.ORDER[expected]:expected+=1
   else:expected=1 if id==116 else 0
   if expected==4:done=true;expected=0
  owner.press(id)
  check(owner.completed==done and owner.progress==expected,"Exact decoded contiguous order only "+str(sequence))
  var saved:Dictionary=JSON.parse_string(JSON.stringify(owner.checkpoint()))
  check(Locks.validate(saved).is_empty(),"Every press produces valid JSON checkpoint "+str(sequence)+" "+Locks.validate(saved))
  var before:Dictionary=owner.native.snapshot();owner.native=Locks.fresh_native();owner.native.restore(saved.native)
  check(owner.native.snapshot()==before,"JSON VM round trip")
  check(not owner.native.locals.has(8),"Unknown local8 never seeded")
 if done:
  check(owner.native.field("0x22d0c:760",Native.FIELD_FLOOR_TARGET,0)==-996 and owner.native.field("0x22d0c:760",Native.FIELD_FLOOR_RATE,0)==20 and owner.native.locals.get(16,-1)==0,"Exact existing success effects")
 owner.free();host.free()
func _initialize():
 run_sequence([116,116,114,115,115]);run_sequence([114,114,116,115]);run_sequence([116,116,114,116,115]);run_sequence([116,116,116,116,114,115])
 # Every possible six-press prefix, including all wrong orders and retries.
 for word in 729:
  var n:=word;var sequence:Array=[]
  for i in 6:sequence.append(Locks.CONTROLS[n%3]);n/=3
  run_sequence(sequence)
 var saved:Dictionary=Locks.initial();saved.progress=3
 check(not Locks.validate(saved).is_empty(),"Forged prefix cannot admit success")
 saved=Locks.initial();saved.rise=1;check(not Locks.validate(saved).is_empty(),"Unfinished floor cannot move")
 saved=Locks.initial();saved.native.locals["8"]=1;check(not Locks.validate(saved).is_empty(),"No forged unknown local8")
 if not failed:print("PASS exact decoded lock order, all729 six-press sequences, native groups and JSON validation, no local8/rewards")
 quit(1 if failed else 0)
