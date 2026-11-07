extends Node3D
const DeadBracers=preload("res://scripts/lol2/dead_bracers_item.gd")
## Prima103/113: bracers permit the priest's errand. Original prop158 gift identity is def78.
const Ankh=preload("res://scripts/lol2/l10_ankh_state.gd")
const KEY:="l10_priest"
const URN:="act2:L10_DC:priest_urn"
const BRACERS:="act2:L9_DR:item55"
const AIM:=Vector3(3396,70,-3010)
const MEDIA:="res://assets/lol2/generated/l10_priest/"
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
var host: Node3D
var ghost: MeshInstance3D
var material: StandardMaterial3D
var frames: Array[Texture2D]=[]
var hint: Label
var elapsed:=0.0
static func initial()->Dictionary:return {"version":1,"urn_given":false}
static func validate(s: Variant,quests: Dictionary)->String:
 if not s is Dictionary or s.size()!=2 or s.get("version")!=1 or not s.get("urn_given") is bool:return "Invalid priest errand state."
 if s.urn_given!=(URN in quests.get("act2_items",{}).get("collected",[])):return "Priest urn and reward history disagree."
 return ""
static func attach(map: Node3D)->Node3D:
 var node=load("res://scripts/lol2/l10_priest.gd").new();node.host=map;node.name="L10Priest";map.add_child(node);return node
func state()->Dictionary:return host.quest_state.get(KEY,initial())
func _ready():
 var media: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(MEDIA+"priest.json"))
 for row in media.frames:frames.append(ImageTexture.create_from_image(Image.load_from_file(MEDIA+row.file)))
 material=StandardMaterial3D.new();material.albedo_texture=frames[0];material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR;material.billboard_mode=BaseMaterial3D.BILLBOARD_FIXED_Y;material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
 ghost=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(120,100);quad.center_offset=Vector3(0,50,0);ghost.mesh=quad;ghost.material_override=material;ghost.position=Vector3(3396,20,-3010);add_child(ghost)
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas);hint=Label.new();hint.position=Vector2(24,480);canvas.add_child(hint)
func reachable()->bool:
 var delta: Vector3=AIM-host.camera.global_position
 if delta.length()>140 or delta.length()<0.01 or (-host.camera.global_basis.z).dot(delta.normalized())<0.8:return false
 var ray:=PhysicsRayQueryParameters3D.create(host.camera.global_position,AIM,1,[host.player.get_rid()])
 return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
func available()->bool:return not get_tree().paused and not host.flying and host.starting_magic.world_active()
func speak()->Dictionary:
 if not available() or not reachable():return {"ok":false,"reason":"Approach and face the priest."}
 if not host.get_node("L10Tombs").opened("154"):return {"ok":false,"reason":"The priest's tomb is sealed."}
 if not DeadBracers.available(host.carried_collected):return {"ok":false,"reason":"You need the Bracers of the Dead to speak with him."}
 if state().urn_given:
  return exchange_ashes(Ankh.FULL)
 var result:=grant(state(),host.carried_collected,host.quest_state.get("act2_items",Items.initial()),64)
 if not result.ok:return result
 host.carried_collected=result.inventory;host.quest_state.act2_items=result.items;host.quest_state[KEY]=result.state;Items.sync(host)
 return {"ok":true,"reason":"Take this urn to the chapel. Burn my body and bring back my ashes."}
static func grant(saved: Dictionary,inventory: Array,items: Dictionary,capacity: int)->Dictionary:
 if not DeadBracers.available(inventory):return {"ok":false,"reason":"You need the Bracers of the Dead to speak with him."}
 if saved.urn_given or URN in items.collected:return {"ok":false,"reason":"Take the urn to the chapel and bring back my ashes."}
 if inventory.size()>=capacity:return {"ok":false,"reason":"Make room for the urn."}
 # Grant and history commit together after guards; no native7748 replay and bracers remain carried.
 var next_items:=items.duplicate(true);next_items.collected.append(URN)
 var carried:=inventory.duplicate();carried.append(URN)
 return {"ok":true,"state":{"version":1,"urn_given":true},"inventory":carried,"items":next_items}
func _process(delta):
 var visible_ghost: bool=host.get_node("L10Tombs").opened("154") and DeadBracers.available(host.carried_collected)
 ghost.visible=visible_ghost;hint.text=""
 if available():elapsed+=delta
 material.albedo_texture=frames[int(elapsed*15)%frames.size()]
 if available() and reachable():hint.text="E — Speak with the priest" if visible_ghost else "A silent presence waits here"
func _unhandled_input(event: InputEvent):
 if event is not InputEventKey or not event.pressed or event.echo or event.keycode!=KEY_E:return
 if not available() or Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED or is_instance_valid(host.inventory) or not reachable():return
 if host.has_method("actor_input_locked") and host.actor_input_locked():return
 var result:=speak();host.save_feedback(result.reason);get_viewport().set_input_as_handled()

func exchange_ashes(item: String)->Dictionary:
 if not available() or host.player_form!=0 or not reachable() or not host.get_node("L10Tombs").opened("154") or not DeadBracers.available(host.carried_collected):return {"ok":false,"reason":"Approach the priest with the Bracers of the Dead."}
 if not state().urn_given:return {"ok":false,"reason":"Accept the priest's errand first."}
 var result:=Ankh.act(host.quest_state.get("l10_ankh",Ankh.initial()),host.carried_collected,Ankh.TRADE,item)
 if not result.ok:return result
 host.carried_collected=result.inventory;host.quest_state.l10_ankh=result.state
 var history: Dictionary=host.quest_state.act2_items.duplicate(true)
 if Ankh.ANKH not in history.collected:history.collected.append(Ankh.ANKH)
 host.quest_state.act2_items=history;Items.sync(host)
 return {"ok":true,"reason":"Take the ankh. Use it on the slab beside my tomb."}
