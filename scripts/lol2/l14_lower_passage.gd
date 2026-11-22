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
## Grok r19o3 owner-save walk 2026-11-16: under the sunken ritual floor the way back up was not named. Only the Lizard fits
## the seam, and only from well back (real input on r19o4, Lizard facing the floor: lands from a zone ~50 across x 40-60 along
## (x 2290-2340, z -3140..-3190); backing up from (2299,-3233) lands 3/3 from 60 units, 0/3 from 40). Text only (row 0287 note).
const UP_HUMAN:="G — Change to Lizard: only the Lizard can jump back up to the ritual floor"
const UP_LIZARD:="Too close and you hit the lip: back well away from the ledge, then run and jump up to the ritual floor · G — Return to Human"
func below_seam()->bool:
 var p:Vector3=host.player.position
 return p.y< -30.0 and Vector2(p.x,p.z).distance_to(Vector2(POINT.x,POINT.z))<260.0
func line()->String:
 if not reachable():return ""
 if host.player_form==0:return UP_HUMAN if below_seam() else "G — Change to Lizard for the low passage"
 if host.player_form==2:return UP_LIZARD if below_seam() else "G — Return to Human"
 return ""
func _process(_delta):hint.text=line()
func _unhandled_key_input(event:InputEvent):
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_G and choose_form():get_viewport().set_input_as_handled()
