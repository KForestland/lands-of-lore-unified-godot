extends SceneTree
## Defensive component contract, not a walk. Actual hosts/packs for all15 levels;
## temporary invalid placeholder fixtures are restored before unpausing each host.
const Areas=preload("res://scripts/lol2/game_areas.gd")
const Belt=preload("res://scripts/lol2/item_belt_state.gd")
const Targets=preload("res://scripts/lol2/item_belt_targets.gd")
const BAD=[null,"","missing:item:unknown",42,false,{}]
func check(ok:bool,message:String)->bool:
 if ok:return true
 push_error(message);quit(1);return false
func _initialize():run.call_deferred()
func check_pack(owned:Array,area:String)->bool:
 var mixed:Array=owned.duplicate(true);mixed.append_array(BAD)
 const KNOWN="museum:item14:Healing_Scroll"
 mixed.append(KNOWN)
 var before:Array=mixed.duplicate(true)
 var value:Dictionary=Belt.initial()
 if not check(Belt.put(value,KNOWN,mixed,0),area+" valid carried reference still admitted"):return false
 for invalid in BAD:
  var saved:Dictionary=value.duplicate(true)
  if not check(Belt.identity(invalid)==-1 and Belt.label(invalid).is_empty() and not Belt.valid_id(invalid) and not Belt.automatic(invalid),area+" invalid public identity/presentation/classification rejected"):return false
  if not check(not Belt.put(value,invalid,mixed,1) and not Belt.pickup(value,invalid,mixed) and value==saved,area+" invalid assignment/pickup leave five refs unchanged"):return false
  if not check(not Belt.same_identity(invalid,invalid) and not Belt.same_identity(KNOWN,invalid),area+" placeholders never stack or match each other"):return false
  if not check(not Targets.accepts({"ids":[invalid],"definitions":[-1]},invalid),area+" invalid item never accepted even by malformed descriptor"):return false
 for slot in 5:
  var expected:String=KNOWN if slot==0 else ""
  if not check((Belt.same_identity(Belt.resolve(value,slot,mixed),KNOWN) if slot==0 else Belt.resolve(value,slot,mixed).is_empty()),area+" resolution skips malformed placeholders and empty refs"):return false
 if not check(Belt.roll(value,mixed,1) and Belt.roll(value,mixed,-1) and value.active==0,area+" both roll directions skip invalid owned entries"):return false
 if not check(Belt.same_identity(Targets.pick({"definitions":[148]},mixed),KNOWN) and mixed==before and Belt.validate(Belt.canonical(value)).is_empty(),area+" smart selection/valid packet preserve raw carried list"):return false
 return true
func run():
 if not check(Areas.ROWS.size()==15,"All15 gameplay levels in host catalog"):return
 for area:String in Areas.ROWS:
  var scene:Node=load(Areas.ROWS[area].scene).instantiate()
  root.add_child(scene);current_scene=scene
  var control:Node
  var ready:=false
  for tick in 3000:
   await process_frame
   control=scene.get("item_effects")
   if scene.get("ready_for_review") is bool and not scene.ready_for_review:continue
   if scene.get("walkthrough_ready") is bool and not scene.walkthrough_ready:continue
   if scene.is_node_ready() and is_instance_valid(control) and control.is_node_ready():ready=true;break
  if not check(ready and is_instance_valid(control),area+" actual item controller ready"):return
  var owned:Array=control.carried()
  if not check_pack(owned,area):return
  paused=true
  # Cave derives its pack: the mixed-copy contract above exercises that shape.
  # Every writable host, particularly Museum, supplies its ACTUAL raw list here.
  var writable:bool=not scene.has_method("carried_items")
  var prior:Array=owned.duplicate(true)
  if writable:owned.append_array(BAD)
  var before:Array=owned.duplicate(true)
  var effects:Dictionary=control.state()
  var prior_belt:Variant=effects.get("belt")
  effects.erase("belt")
  var value:Dictionary=control.belt_state()
  for invalid in BAD:
   if not check(not control.put_on_belt(invalid),area+" controller manual assignment refuses invalid input"):return
  control.advance_belt(0.0)
  if not check(not control.use_belt_target() and not control.use_belt_self(),area+" paused E/F cannot use malformed pack"):return
  for key in [KEY_E,KEY_F,KEY_BRACKETLEFT,KEY_BRACKETRIGHT]:
   var event:=InputEventKey.new();event.keycode=key;event.pressed=true;control._input(event)
  # Includes the actual belt view's count/filter/update on paused UI frames.
  for frame in 3:await process_frame
  if not check(owned==before and Belt.validate(value).is_empty(),area+" all controller/HUD entry points preserve actual mixed pack"):return
  if writable:owned.assign(prior)
  if prior_belt==null:effects.erase("belt")
  else:effects.belt=prior_belt
  scene.queue_free();current_scene=null
  for frame in 3:await process_frame
  paused=false
  print("BELT_INVALID_IDS_GREEN ",area," actual_pack=",prior.size()," writable=",writable)
 print("PASS all15 actual carried-list hosts inclMuseum: null/empty/unknown/non-string fixtures, cold initialization/advance/manual assignment/roll/resolve/labels/smart selection/E/F/HUD, no pack normalization or consumption; explicit restored placeholder fixtures")
 quit()
