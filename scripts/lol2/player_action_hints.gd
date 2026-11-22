extends Node
## Shared presentation/Journal policy. Providers only read existing admission;
## an E echo never casts, grants, opens or changes a quest.
const Journal=preload("res://scripts/lol2/my_journal.gd")
var host:Node3D
var provider:RefCounted
var label:Label
var previous:Dictionary={}
var aimed_key:=""
var suppressed_key:=""
var probe:=0.0
func _ready():
 label=preload("res://scripts/lol2/interaction_hint_label.gd").attach(self,Vector2(24,340))
func active()->bool:
 return is_instance_valid(host) and is_instance_valid(host.get("starting_magic")) and host.starting_magic.world_active() and host.player_form==0
func target()->Dictionary:
 return provider.call("pick",host) if active() else {}
func show(row:Dictionary):
 Journal.discover(host,str(row.journal))
 host.interface_hud.show_lesson(str(row.message))
 previous=row.duplicate()
func _process(delta:float):
 if not is_instance_valid(host):return
 var hud:Variant=host.get("interface_hud")
 if not is_instance_valid(hud):return
 label.visible=hud.visible
 if not previous.is_empty() and bool(provider.call("completed",host,previous)):
  hud.finish_action_lesson(str(previous.message));previous={}
 probe-=delta
 if probe>0:return
 probe=0.1
 var row:Dictionary=target()
 label.text=str(row.get("message",""))
 var key:String=str(row.get("key",""))
 if key!=aimed_key:
  aimed_key=key
  if key!=suppressed_key:suppressed_key=""
  if not row.is_empty() and key!=suppressed_key:show(row)
func _input(event:InputEvent):
 if not event is InputEventKey or not event.pressed or event.echo or event.keycode!=KEY_Q:return
 var row:Dictionary=target()
 if row.is_empty():return
 # A cast/refusal owns the next HUD sentence. The passive prompt may remain,
 # but it must not overwrite mana/cooldown/story feedback on the same aim.
 suppressed_key=str(row.key)
 host.interface_hud.finish_action_lesson(str(row.message))
func _unhandled_input(event:InputEvent):
 if not event is InputEventKey or not event.pressed or event.echo or event.keycode!=KEY_E:return
 var row:Dictionary=target()
 if row.is_empty() or bool(row.get("delegate_e",false)):return
 suppressed_key="";show(row)
 get_viewport().set_input_as_handled()
