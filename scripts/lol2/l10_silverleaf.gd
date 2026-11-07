extends Node
## Original tree props159..170; book-led Emperor/no-bracers activation.
const KEY:="l10_silverleaf"
const TREES:=[159,160,161,162,163,164,165,166,167,168,169,170]
var host:Node3D
const Harvest=preload("res://scripts/lol2/l10_silverleaf_harvest.gd")
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
var hint:Label
var presented:=""
static func initial()->Dictionary:return {"version":1,"grown":false}
static func validate(s:Variant,quests:Dictionary)->String:
 if not s is Dictionary or s.size()!=2 or s.get("version")!=1 or not s.get("grown") is bool:return "Invalid Silverleaf growth."
 if s.grown and (not quests.get("l10_emperor",{}).get("remains",false) or not preload("res://scripts/lol2/l8_dawn_state.gd").completed(quests.get("l8_dawn",{}))):return "Silverleaf requires the earned Emperor errand and Dawn exchange."
 return ""
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l10_silverleaf.gd").new();n.host=map;n.name="L10Silverleaf";map.add_child(n);return n
func state()->Dictionary:return host.quest_state.get(KEY,initial())
func _ready():
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas);hint=Label.new();hint.position=Vector2(24,455);canvas.add_child(hint)
 restore(true)
func restore(force:bool=false):
 var value:String=str(state().grown)+JSON.stringify(harvest_state().picked)
 if not force and presented==value:return
 presented=value
 for id in TREES:
  if not host.prop_placements.has(id):continue
  var row:Array=host.prop_placements[id];var pose:=Transform3D(Basis(),row[2])
  if not state().grown or str(id) in harvest_state().picked:pose.basis=Basis.from_scale(Vector3.ZERO)
  row[0].set_instance_transform(row[1],pose)
func revisit()->Dictionary:
 var emperor=host.get_node("L10Emperor")
 if not emperor.active() or not emperor.reachable("remains"):return {"ok":false,"reason":"Return to the Emperor's sarcophagus."}
 if preload("res://scripts/lol2/dead_bracers_item.gd").available(host.carried_collected):return {"ok":false,"reason":"You can still understand the Emperor with the bracers."}
 if not host.quest_state.get("l10_emperor",{}).get("remains",false) or not preload("res://scripts/lol2/l8_dawn_state.gd").completed(host.quest_state.get("l8_dawn",{})):return {"ok":false,"reason":"Complete the Emperor's errand and meet Dawn first."}
 if state().grown:return {"ok":false,"reason":"You cannot understand the Emperor. Silverleaf is already growing on the cemetery trees."}
 host.quest_state[KEY]={"version":1,"grown":true};restore()
 return {"ok":true,"reason":"Without the bracers, you cannot understand the Emperor. Silverleaf begins growing on the cemetery's dead trees."}
func harvest_state()->Dictionary:return host.quest_state.get(Harvest.KEY,Harvest.initial())
func aim(target:String)->Vector3:return host.prop_placements[int(target)][2]+Vector3.UP*42
func reachable(target:String)->bool:
 if not Harvest.valid_target(target) or not host.prop_placements.has(int(target)):return false
 var delta:Vector3=aim(target)-host.camera.global_position
 if delta.length()>150 or delta.length()<0.01 or (-host.camera.global_basis.z).dot(delta.normalized())<0.8:return false
 var ray:=PhysicsRayQueryParameters3D.create(host.camera.global_position,aim(target),1,[host.player.get_rid()])
 return host.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
func target()->String:
 if not state().grown:return ""
 for id in TREES:
  if str(id) not in harvest_state().picked and reachable(str(id)):return str(id)
 return ""
func pick(target_id:String)->Dictionary:
 if not host.get_node("L10Emperor").active() or not state().grown or not reachable(target_id):return {"ok":false,"reason":"Approach a grown Silverleaf tree in human form."}
 var result:=Harvest.pick(harvest_state(),host.carried_collected,host.quest_state.act2_items,target_id)
 if not result.ok:return result
 host.quest_state[Harvest.KEY]=result.state;host.carried_collected=result.inventory;host.quest_state.act2_items=result.items;Items.sync(host);restore()
 return {"ok":true,"reason":result.reason}
func _process(_delta):
 restore();hint.text=""
 if host.get_node("L10Emperor").active() and not target().is_empty():hint.text="E — Pick Silverleaf"
func _unhandled_input(event:InputEvent):
 if event is not InputEventKey or not event.pressed or event.echo or event.keycode!=KEY_E:return
 if Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED or is_instance_valid(host.inventory):return
 if host.has_method("actor_input_locked") and host.actor_input_locked():return
 var id:=target()
 if id.is_empty():return
 var result:=pick(id);host.save_feedback(result.reason);get_viewport().set_input_as_handled()
