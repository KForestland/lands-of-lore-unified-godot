extends Node3D
##0287: reuse the earned Dreamstone form-choice adapter at the lowered ritual floor.
const POINT=Vector3(2300,-30,-3350)
var host:Node3D
var hint:Label
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l14_lower_passage.gd").new();n.host=map;n.name="L14LowerPassage";map.add_child(n);return n
func _ready():
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas);hint=Label.new();hint.position=Vector2(24,435);canvas.add_child(hint)
func reachable()->bool:
 return host.starting_magic.world_active() and "act2:L13_RC:dreamstone" in host.carried_collected and host.quest_state.get("l14_priest_ritual",{}).get("vanished",false) and (host.player.position.distance_to(POINT)<400 or (host.quest_state.get("l14_library",{}).get("exit",false) and host.player.position.distance_to(Vector3(2800,0,-3800))<300) or (host.quest_state.get("l14_library",{}).get("first",false) and host.player.position.distance_to(Vector3(1820,100,-5088))<300) or (host.quest_state.get("l14_bedroom",{}).get("headboard",false) and host.player.position.distance_to(Vector3(2200,100,-5270))<400) or (host.quest_state.get("l14_machines",{}).get("phase") in ["pressing","formed","taken"] and host.player.position.distance_to(Vector3(3460,-55,-3615))<180))
func choose_form()->bool:
 if not reachable() or host.curse.state.phase in [1,3]:return false
 return host.curse.request_timed_form(2,60.0) if host.player_form==0 else host.curse.request_human() if host.player_form==2 else false
func _process(_delta):hint.text=("G — Change to Lizard for the low passage" if host.player_form==0 else "G — Return to Human" if host.player_form==2 else "") if reachable() else ""
func _unhandled_key_input(event:InputEvent):
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_G and choose_form():get_viewport().set_input_as_handled()
