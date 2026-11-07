extends Node3D
const State=preload("res://scripts/lol2/l13_altar_state.gd")
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
const ALTAR=Vector3(-2343,-1020,-4538)
const STONE=Vector3(-2710,-1020,-4183)
var gate:Node3D
var opened:Variant=null
static func owns(f:Dictionary)->bool:return f.get("placement_kind")=="movable" and int(f.get("source_index",-1))>=50 and int(f.get("source_index",-1))<=68
var host:Node3D
var hint:Label
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l13_altar.gd").new();n.host=map;n.name="L13Altar";map.add_child(n);return n
func state()->Dictionary:return host.quest_state.get(State.KEY,State.initial())
func _ready():
 gate=Node3D.new();gate.name="OriginalBossGate";add_child(gate)
 var faces:Array=[]
 for f in JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file)).faces:
  if owns(f):faces.append(f)
 host.get_node("L13Eggs").build(gate,faces)
 restore();_make_hint()
func restore():
 if not is_instance_valid(gate):return
 var dead:=boss_dead()
 if opened==dead:return
 opened=dead;gate.visible=not dead;gate.get_node("Collision").collision_layer=0 if dead else 1
func _make_hint():
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas);hint=Label.new();hint.position=Vector2(24,455);canvas.add_child(hint)
func active()->bool:return host.player_form==0 and host.starting_magic.world_active()
func reachable(point:Vector3)->bool:
 var d:Vector3=point-host.camera.global_position
 return d.length()<170 and d.length()>0.01 and (-host.camera.global_basis.z).dot(d.normalized())>0.85
func boss_dead()->bool:return float(host.act2_creatures.state.actors["40"].health)<=0
func enchant()->Dictionary:
 if not active() or not reachable(ALTAR):return State.Kit.refuse("Approach the sword altar.")
 var result:=State.enchant(state(),host.carried_collected,host.equipped_item,host.equipped_item,boss_dead())
 if not result.ok:return result
 host.quest_state[State.KEY]=result.state;host.carried_collected=result.inventory
 host.quest_state.act2_items.collected.append(result.state.output);Items.sync(host)
 host.set_equipped_item(result.state.output)
 if is_instance_valid(host.inventory):host.inventory.equipped_item=result.state.output
 return {"ok":true,"reason":"The altar transforms your sword. You take it before the Dreamstone."}
func take_stone()->Dictionary:
 if not active() or not reachable(STONE):return State.Kit.refuse("Approach the Dreamstone pedestal.")
 var result:=State.take_stone(state(),host.carried_collected,boss_dead())
 if not result.ok:return result
 host.quest_state[State.KEY]=result.state;host.carried_collected=result.inventory
 host.quest_state.act2_items.collected.append(State.STONE);Items.sync(host)
 return {"ok":true,"reason":"You take the Dreamstone."}
func _process(_delta):
 restore()
 hint.text=""
 if not active():return
 if reachable(ALTAR) and not State.enchanted(state()):hint.text="E — Enchant equipped sword"
 elif reachable(STONE) and not state().stone_taken:hint.text="E — Take Dreamstone"
func _unhandled_key_input(event:InputEvent):
 if not active():return
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E:
  if reachable(ALTAR) and not State.enchanted(state()):host.save_feedback(enchant().reason);get_viewport().set_input_as_handled()
  elif reachable(STONE):host.save_feedback(take_stone().reason);get_viewport().set_input_as_handled()
