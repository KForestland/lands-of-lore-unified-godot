extends Node3D
const Grants=preload("res://scripts/lol2/item_grants.gd")
const RESTORE_ON := ["load"]
const State=preload("res://scripts/lol2/l13_altar_state.gd")
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
const ALTAR=Vector3(-2343,-1020,-4538)
const STONE=Vector3(-2710,-1020,-4183)
var gate:Node3D
var opened:Variant=null
## Owner F10 2026-11-16T16-25-00 (lead: presentation adapter, DEVIATIONS): the holder prop (record 326, prop_84) draws
## the stone in all its frames; once the stone is taken it draws the derived empty frame (tools/prepare_l13_holder_empty.py)
## in its place, and a save with the stone untaken draws it with the stone again.
const HOLDER:=326
const HOLDER_EMPTY:="res://assets/lol2/generated/l13_altar/holder_empty.png"
var holder_empty:MultiMeshInstance3D
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
func show_holder():
 var placements:Variant=host.get("prop_placements")
 if not placements is Dictionary or not placements.has(HOLDER):return
 var p:Array=placements[HOLDER];var taken:bool=state().stone_taken
 if taken and holder_empty==null and FileAccess.file_exists(HOLDER_EMPTY):
  # Same quad, same (sector-lit) material with the empty frame, same per-instance light as the batched holder.
  var source:MultiMesh=p[0];var quad:QuadMesh=(source.mesh as QuadMesh).duplicate();var material:Material=quad.material.duplicate()
  var empty_texture:=ImageTexture.create_from_image(Image.load_from_file(HOLDER_EMPTY))
  if material is ShaderMaterial:(material as ShaderMaterial).set_shader_parameter("albedo",empty_texture)
  elif material is StandardMaterial3D:(material as StandardMaterial3D).albedo_texture=empty_texture
  quad.material=material
  var one:=MultiMesh.new();one.transform_format=MultiMesh.TRANSFORM_3D;one.use_custom_data=true;one.mesh=quad;one.instance_count=1
  one.set_instance_transform(0,Transform3D(Basis(),Vector3.ZERO));one.set_instance_custom_data(0,source.get_instance_custom_data(p[1]))
  holder_empty=MultiMeshInstance3D.new();holder_empty.name="EmptyDreamstoneHolder";holder_empty.multimesh=one;add_child(holder_empty);holder_empty.global_position=p[2]
 var empty:bool=taken and holder_empty!=null
 (p[0] as MultiMesh).set_instance_transform(p[1],Transform3D(Basis().scaled(Vector3.ZERO) if empty else Basis(),p[2]))
 if holder_empty!=null:holder_empty.visible=empty
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
 var admission:=Grants.transition(host,result.inventory,{State.KEY:result.state},{"history":"act2","history_id":result.state.output})
 if not admission.ok:return admission
 Items.sync(host)
 host.set_equipped_item(result.state.output)
 if is_instance_valid(host.inventory):host.inventory.equipped_item=result.state.output
 return {"ok":true,"reason":"The altar transforms your sword. You take it before the Dreamstone."}
func take_stone()->Dictionary:
 if not active() or not reachable(STONE):return State.Kit.refuse("Approach the Dreamstone pedestal.")
 var result:=State.take_stone(state(),host.carried_collected,boss_dead())
 if not result.ok:return result
 var admission:=Grants.transition(host,result.inventory,{State.KEY:result.state},{"history":"act2","history_id":State.STONE})
 if not admission.ok:return admission
 Items.sync(host)
 return {"ok":true,"reason":"You take the Dreamstone."}
func _process(_delta):
 restore();show_holder()
 hint.text=""
 if not active():return
 if reachable(ALTAR) and not State.enchanted(state()):hint.text="E — Enchant equipped sword"
 elif reachable(STONE) and not state().stone_taken:hint.text="E — Take Dreamstone"
func _unhandled_key_input(event:InputEvent):
 if not active():return
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E:
  if reachable(ALTAR) and not State.enchanted(state()):host.save_feedback(enchant().reason);get_viewport().set_input_as_handled()
  elif reachable(STONE):host.save_feedback(take_stone().reason);get_viewport().set_input_as_handled()
