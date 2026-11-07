extends Node3D
## Modern interaction/summary; original Dawn20 remains the sole visible actor.
const State=preload("res://scripts/lol2/l8_dawn_state.gd")
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
const AIM:=Vector3(-4252,65,-1515)
var host:Node3D
var hint:Label
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l8_dawn.gd").new();n.host=map;n.name="L8Dawn";map.add_child(n);return n
func state()->Dictionary:return host.quest_state.get(State.KEY,State.initial())
func _ready():
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas)
 hint=Label.new();hint.position=Vector2(24,455);canvas.add_child(hint)
func reachable()->bool:
 if not host.quest_state.get("l8_shore",{}).get("arrived",false):return false
 if not host.act2_creatures.state.actors["20"].present:return false
 var delta:Vector3=AIM-host.camera.global_position
 if delta.length()>150 or delta.length()<0.01 or (-host.camera.global_basis.z).dot(delta.normalized())<0.8:return false
 var ray:=PhysicsRayQueryParameters3D.create(host.camera.global_position,AIM,1,[host.player.get_rid()])
 return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
func available()->bool:return not get_tree().paused and not host.flying and host.player_form==0 and host.starting_magic.world_active()
func interact(item:String=State.BRACERS)->Dictionary:
 if not available() or not reachable():return {"ok":false,"reason":"Approach Dawn in human form."}
 var result:=State.exchange(state(),host.carried_collected,item)
 if not result.ok:return result
 var history:Dictionary=host.quest_state.act2_items.duplicate(true)
 history.collected.append(State.TOKEN)
 host.carried_collected=result.inventory;host.quest_state.act2_items=history;host.quest_state[State.KEY]=result.state
 if host.equipped_item==State.BRACERS:host.equipped_item=""
 Items.sync(host)
 return {"ok":true,"reason":"Dawn accepts the bracers and explains reflecting magic. She gives you a Control Token, another piece of magic for controlling the curse."}
func _process(_delta):
 hint.text="E — Give Dawn the Bracers of the Dead" if available() and reachable() and not State.completed(state()) else ""
func _unhandled_input(event:InputEvent):
 if event is not InputEventKey or not event.pressed or event.echo or event.keycode!=KEY_E:return
 if not available() or Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED or is_instance_valid(host.inventory) or not reachable():return
 if host.has_method("actor_input_locked") and host.actor_input_locked():return
 var result:=interact();host.save_feedback(result.reason);get_viewport().set_input_as_handled()
