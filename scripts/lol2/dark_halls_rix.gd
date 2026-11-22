extends Node
const Grants=preload("res://scripts/lol2/item_grants.gd")
## RIX (L7 actor57) on the Dark Halls creature owner. His death runs the source death group 14414 (soul -1,
## GV_RIX_DEAD = 1; the cellar room already hides him by GV_RIX_DEAD); E on his body then gives the event4/
## predicate216 grant "14-Plasma staff" (group 14496). Old two-field saves remain valid; the
## rescue/talk bridge follows the owner-approved optional Prism5/Mists1 binding.
const Native=preload("res://scripts/lol2/dark_halls_rix_native.gd")
const Journal=preload("res://scripts/lol2/my_journal.gd")
const SpellRules=preload("res://scripts/lol2/dark_halls_rix_spell_rules.gd")
var last_spell_refusal:=""
const LESSON:="Weaken Rix to half health, then use Mists 1 (4, Q), Prism 5 (5, Shift+Q), or a stored Mists/Prism item (F on the belt) to free him."
const JOURNAL_HINTS:=[{"when":"dark_halls_rix_rescue","hint":LESSON}]
var hint:Label
var hint_clock:=0.0
const SOURCE := "res://scripts/lol2/dark_halls_loot_source.json"
const ID := "57"
const REACH := 110.0
var host: Node3D
var rix: Dictionary = {}

func setup(walkthrough: Node3D) -> void:
	name = "DarkHallsRix"
	host = walkthrough
	rix = JSON.parse_string(FileAccess.get_file_as_string(SOURCE)).rix
	hint=preload("res://scripts/lol2/interaction_hint_label.gd").attach(self,Vector2(24,455))

func state() -> Dictionary:
	var quests: Dictionary = host.quest_state
	if not quests.get("dark_halls_rix") is Dictionary: quests.dark_halls_rix = {"dead": false, "staff": false}
	return quests.dark_halls_rix

static func validate(value: Variant) -> String:
	if not value is Dictionary or not value.get("dead") is bool or not value.get("staff") is bool:return "Invalid Rix state."
	for key in value:
		if key not in ["dead","staff","rescued","native","talked"]:return "Invalid Rix field."
	for key in ["rescued","talked"]:
		if value.has(key) and not value[key] is bool:return "Invalid Rix state."
	if value.staff and not value.dead:return "Rix staff taken before his death."
	if value.get("rescued",false) and (value.dead or value.staff):return "Rescued Rix cannot be dead or give his staff."
	if value.has("native"):
		var error:String=Native.VM.snapshot_error(value.native)
		if not error.is_empty():return error
		if not value.get("rescued",false) or int(value.native.state.get("actor:57",{}).get("byte_0x25",-1))!=100:return "Rix rescue and native state disagree."
		if value.get("talked",false) and int(value.native.state.get("rix:talk",{}).get("release_receipt",0))!=1:return "Rix talk lacks its native receipt."
	elif value.get("rescued",false) or value.get("talked",false):return "Rix rescue lacks its native receipt."
	return ""

## Queries never create or edit quest state. Old two-field packets stay valid.
func saved() -> Dictionary:
	if not is_instance_valid(host):return {"dead":false,"staff":false}
	var quests:Variant=host.get("quest_state")
	var row:Variant=quests.get("dark_halls_rix") if quests is Dictionary else null
	return row if row is Dictionary else {"dead":false,"staff":false}

func actor_record()->Dictionary:
	if not is_instance_valid(host):return {}
	var pop:Variant=host.get("creatures")
	if not is_instance_valid(pop):return {}
	var packet:Variant=pop.get("state")
	var actors:Variant=packet.get("actors") if packet is Dictionary else null
	var row:Variant=actors.get(ID) if actors is Dictionary else null
	return row if row is Dictionary else {}

func living() -> bool:
	return int(actor_record().get("health",0))>0 and not saved().dead

func aimed_living() -> bool:
	if not living():return false
	var bodies:Variant=host.creatures.get("bodies")
	var body:Variant=bodies.get(ID) if bodies is Dictionary else null
	if not is_instance_valid(body) or not body is Node3D:return false
	if host.camera.global_position.distance_to(body.global_position+Vector3(0,20,0))>REACH:return false
	var hit:Dictionary=preload("res://scripts/lol2/player_combat.gd").aim_ray(host,REACH,259)
	return not hit.is_empty() and hit.collider==body

## Spell selection uses the first-hit ray to Rix, independently of E reach.
## No new arbitrary spell distance is imposed: trace through the actual target.
func aimed_spell()->bool:
	if not living():return false
	var body:Node3D=host.creatures.bodies.get(ID)
	if not is_instance_valid(body):return false
	var length:float=host.camera.global_position.distance_to(body.global_position)+64.0
	var hit:Dictionary=preload("res://scripts/lol2/player_combat.gd").aim_ray(host,length,259)
	return not hit.is_empty() and hit.collider==body

func accepts_player_spell(id:String)->bool:
	# Claim an aimed supported cast even if the phase will refuse it: the
	# shared dispatcher then preserves item/mana and reports the reason.
	return SpellRules.accepts(id) and aimed_spell()

func spell_refusal()->String:return last_spell_refusal
func refuse_spell(line:String)->bool:
	last_spell_refusal=line
	return false

func receive_player_spell(id:String)->bool:
	last_spell_refusal=""
	if not accepts_player_spell(id) or not host.starting_magic.world_active():return refuse_spell("Aim the spell at Rix.")
	if saved().get("rescued",false):return refuse_spell("Rix is already free.")
	if int(actor_record().health)>100:return refuse_spell("Weaken Rix to half health first.")
	var monastery:Variant=host.quest_state.get("monastery")
	if not monastery is Dictionary or not monastery.get("globals") is Dictionary:return refuse_spell("Rix cannot be freed just now.")
	var result:=Native.rescue(saved().get("native",{}),int(actor_record().health))
	if not result.ok:return refuse_spell("Rix cannot be freed just now.")
	var next:Dictionary=saved().duplicate(true)
	next.rescued=true;next.native=result.native
	host.quest_state.dark_halls_rix=next
	preload("res://scripts/lol2/shared_global_defaults.gd").add_soul(monastery.globals,int(result.soul_delta))
	host.save_feedback("The possession is broken. Rix is free.")
	return true

func has_rescue_spell()->bool:
	return SpellRules.available(host.starting_magic.magic_state().get("spellbook",{}),host.carried_collected)

func inspect_or_talk()->bool:
	if not aimed_living():return false
	if saved().get("rescued",false):
		var result:=Native.talk(saved().get("native",{}))
		if not result.ok:
			host.save_feedback("Rix cannot speak just now.")
			return true # His E never passes through him on failure.
		state().native=result.native;state().talked=true
		host.save_feedback("Rix is free.")
	else:
		Journal.discover(host,"dark_halls_rix_rescue")
		var line:=LESSON
		if not has_rescue_spell():line+=" You know neither spell and carry no stored one. Come back later, or leave him."
		host.interface_hud.show_lesson(line)
	return true

## A living NPC selected by the actual first-hit ray owns his explicit E,
## before an unrelated proximity selector behind him. Corpse use stays legacy.
func _input(event:InputEvent)->void:
	if get_tree().paused or (DisplayServer.get_name()!="headless" and Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED):return
	if not is_instance_valid(host) or not is_instance_valid(host.starting_magic) or not host.starting_magic.world_active():return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E and inspect_or_talk():get_viewport().set_input_as_handled()

func _process(delta:float)->void:
	if not is_instance_valid(hint):return
	hint_clock-=delta
	if hint_clock>0:return
	hint_clock=0.1;hint.text=""
	if is_instance_valid(host.starting_magic) and host.starting_magic.world_active() and aimed_living():
		hint.text="E — Talk to Rix" if saved().get("rescued",false) else "E — Inspect Rix"

func population_dead() -> bool:
	var actor:=actor_record()
	return not actor.is_empty() and int(actor.get("health",-1))==0

## Source group 14414: ce00000000ff (soul -1) and c70000003001 (GV_RIX_DEAD = 1), once.
func apply_death() -> bool:
	if saved().get("rescued",false) or bool(state().dead) or not population_dead(): return false
	var monastery: Dictionary = host.quest_state.get("monastery", {})
	if monastery.get("globals") is Dictionary:
		var globals: Dictionary = monastery.globals
		preload("res://scripts/lol2/shared_global_defaults.gd").add_soul(globals, -1)  # SOUL-SYSTEM: clamped 0..10
		globals.GV_RIX_DEAD = 1
	state().dead = true
	if host.has_method("save_feedback"): host.save_feedback("Rix is dead.")
	return true

func take_staff() -> bool:
	if saved().get("rescued",false) or not bool(state().dead) or bool(state().staff) or not host.get("carried_collected") is Array: return false
	var pop = host.get("creatures")
	if pop == null or not pop.bodies.has(ID): return false
	var offset: Vector3 = pop.bodies[ID].global_position + Vector3(0, 20, 0) - host.camera.global_position
	if offset.length() > REACH or (-host.camera.global_basis.z).dot(offset.normalized()) < 0.75: return false
	var id: String = rix.corpse.id
	if not id in host.carried_collected:
		if host.carried_collected.size() >= preload("res://scripts/lol2/item_catalog.gd").MAX_CARRIED:
			if host.has_method("save_feedback"): host.save_feedback("Inventory full.")
			return false
		if not Grants.grant(host,id,{"cap":false,"duplicate":"allow"}).ok: return false
	state().staff = true
	if host.has_method("save_feedback"): host.save_feedback("Plasma staff taken.")
	return true

func _physics_process(_delta: float) -> void:
	if host != null: apply_death()

func _unhandled_input(event: InputEvent) -> void:
	if (Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and DisplayServer.get_name() != "headless") or get_tree().paused: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E and take_staff():
		get_viewport().set_input_as_handled()
