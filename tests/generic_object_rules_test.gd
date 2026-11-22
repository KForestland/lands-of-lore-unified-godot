extends SceneTree
const Rules=preload("res://scripts/lol2/generic_object_rules.gd")
const Native=preload("res://scripts/lol2/native_script_host.gd")
var failures:=0
func check(ok:bool,message:String):
 if not ok:failures+=1;push_error(message)
func _initialize():run.call_deferred()
func run():
 var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/generic_objects_l10.json"))
 check(FileAccess.get_sha256("res://scripts/lol2/native_scripts/L10_DC.json")==source.native_sha256,"Census is pinned to staged native source")
 var native:=Native.new();check(native.load_area("res://scripts/lol2/native_scripts/L10_DC.json").is_empty(),"Native rows load")
 var movable_count:=0;var break_count:=0
 for row in source.rows:
  if row.in_162:
   movable_count+=1
   var ref: String="movable:%d"%int(row.index);var p:PackedByteArray=native.placements[ref]
   check((p.decode_u16(8)&0x1000)==0 and (int(p[0x23])&2)!=0 and native.object_records(ref).is_empty(),"Present event-less click row "+ref)
   check([int(p[0x22]),int(p[0x24]),int(p[0x25]),int(p[0x27])]==[int(row.mode),int(row.span),int(row.step),int(row.state)],"Census motion bytes "+ref)
   var initial:=Rules.initial(p)
   check(Rules.motion_error(initial,p).is_empty(),"Initial packet "+ref)
   var opened:=Rules.use(initial,p,256.0)
   check(opened.accepted and int(opened.state[Rules.PHASE])==2,"Inclusive use reach "+ref)
   for denied in [Rules.use(initial,p,256.01),Rules.use(initial,p,50.0,1),Rules.use(initial,p,50.0,0,true)]:
    check(not denied.accepted and denied.state==initial,"Native use refusals preserve state "+ref)
   var ticked:=Rules.tick(opened.state,p,10.0)
   check(int(ticked.state[Rules.POSITION])==Rules.distance_word(int(p[0x22]),int(p[0x24]))*Rules.FIXED and ticked.callers==[15,17] and int(ticked.state[Rules.PHASE])==1,"Opening finish and hooks "+ref)
   var closing:=Rules.use(ticked.state,p,50.0)
   check(closing.accepted and int(closing.state[Rules.PHASE])==3,"Close on reuse "+ref)
   var closed:=Rules.tick(closing.state,p,10.0)
   check(int(closed.state[Rules.POSITION])==0 and int(closed.state[Rules.PHASE])==5 and closed.callers==[16],"Closing finish and hook "+ref)
   check(Rules.use(closed.state,p,50.0).accepted,"Adapter state5 repeats "+ref)
   var stop:=Rules.use(opened.state,p,50.0)
   check(int(stop.state[Rules.PHASE])==1 and stop.callers==[17],"Mid-open stops "+ref)
   stop=Rules.use(closing.state,p,50.0)
   check(int(stop.state[Rules.PHASE])==0 and stop.callers==[17],"Mid-close stops "+ref)
   var held:=Rules.tick(opened.state,p,0.0);check(held.state==opened.state and held.callers.is_empty(),"Pause/zero delta no movement "+ref)
   var origin:=Vector3(3,7,11);var end:=Rules.transform_for(int(row.mode),int(ticked.state[Rules.POSITION]),origin)
   check(not end.is_equal_approx(Transform3D(Basis.IDENTITY,origin)),"Published mode moves or turns "+ref)
   var bad:=initial.duplicate();bad[Rules.POSITION]=-1;check(not Rules.motion_error(bad,p).is_empty(),"Reject invalid persisted position "+ref)
  if row.in_57:break_count+=1
 check(movable_count==56 and break_count==29,"Exactly56movables/29breakables; no absent rows")
 for pair in [[100,81,-1],[100,80,1],[100,70,1],[100,0,1],[80,60,2],[60,40,3],[40,20,0],[20,0,-1]]:
  native.reset_state()
  var runs:=native.fire_event("control:241",9,{"dword_22":pair[0],"dword_26":pair[1],"context":"control:241"})
  var successful:=0
  for event in runs:
   if event.status=="ran":successful+=1
  check(successful==(0 if pair[2]<0 else 1),"Exactly first crossed cover row "+str(pair))
  if pair[2]>=0:check(int(native.field("control:241",Native.FIELD_SELECTOR,0))==pair[2],"Native selector from threshold "+str(pair))
 native.reset_state()
 var missing:=native.fire_event("control:241",9,{"dword_26":70})
 check(not missing.is_empty() and missing[0].status=="unhosted","Mode3 refuses missing old cap")
 check(Rules.crossed_thresholds(44,16,[100,80,60,40,20])==[40,20],"A strong blow crosses every threshold in order")
 check(Rules.crossed_thresholds(100,0,[20,80,40,60,100,80])==[80,60,40,20],"Overkill crosses each band once, descending")
 if failures==0:print("PASS B shared rules:56exact present motion rows, guards/hooks/published transforms,29breakables, native threshold boundaries and first-success ordering")
 quit(0 if failures==0 else 1)
