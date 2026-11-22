extends Node
## Act 3 journal notes for six hosted gaps (grok AA04). Text only. Quest state is never changed.
## Main-road directions read saved owner stages; only Journal discovery is written.
const MyJournal = preload("res://scripts/lol2/my_journal.gd")
const ORIGINAL_HINTS := [
	{"when": "l16_south_fountain", "flag": "l16_dry_fountain", "hint": "The dry fountain is at the south end of the avenue. The ball over it is what I break.", "enhanced_guard": "HINTBOOK (grok AA04). Not shown."},
	{"when": "l17_cavern_exit", "flag": "l17_cavern_run", "hint": "The caverns can be a straight run for the exit. The map shows the heading.", "enhanced_guard": "HINTBOOK (grok AA04). Not shown."},
	{"when": "l19_horn_keep", "flag": "l19_belial_horn", "hint": "Baccata gives me Belial's horn, and then he is gone. I keep the horn.", "enhanced_guard": "HINTBOOK (grok AA04). Not shown."},
	{"when": "l19_sewer_cross", "flag": "l19_sewer_forms", "hint": "As a man I break the bars. As the Lizard I take the gutter. Three switches across the guck raise it.", "enhanced_guard": "HINTBOOK (grok AA04). Not shown."},
	{"when": "l19_ghostly_heads", "flag": "l19_ghostly_heads", "hint": "Four ghostly heads take a level-one mist of doom each. The demon's body goes on the white circle, and I stay out of the fountain.", "enhanced_guard": "HINTBOOK (grok AA04). Not shown."},
	{"when": "l19_curse_mother", "flag": "l19_dawn_curse", "hint": "The curse spell goes in at ancient-magic level five. A purple glob should enter the mother.", "enhanced_guard": "HINTBOOK (grok AA04). Not shown."},
]
const JOURNAL_HINTS := ORIGINAL_HINTS + ROAD.L17_HC + ROAD.L19_BC + ROAD.L20_BB
const ROAD := {
 "L17_HC": [
  {"when":"l17_road_arrival","place":"red_strands","hint":"Hidden Caverns: follow the passages to the red strands in the west wall. Cut them with a weapon; that way leads to Belial's Laboratory."},
  {"when":"l17_road_exit","place":"laboratory_exit","hint":"The red strands are cut. Continue through the west-wall passage to Belial's Laboratory."}],
 "L19_BC": [
  {"when":"l19_road_arrival","place":"baccata_horn","hint":"Belial's Laboratory: Baccata and Belial's Horn are by the pipe south of the arrival. Look down from the rim and take the Horn."},
  {"when":"l19_road_bars","place":"bars_gutter","hint":"You carry Belial's Horn. Go back along the corridor to the barred door. Strike the bars as the Human; the Lizard can take the gutter beyond."},
  {"when":"l19_road_switches","place":"guck_switches","hint":"Beyond the gutter, change back to the Human. Shoot the three switches over the guck with the Blue Bow or the Dark Bow to raise the channel."},
  {"when":"l19_road_golden","place":"golden_door","hint":"The channel is raised. Open its door and follow the passage through the rapids toward the Golden Door; E opens the door."},
  {"when":"l19_road_heads","place":"ghostly_heads","hint":"Beyond the Golden Door, find the summoning room. Cast Mists 1 at each of its four ghostly heads (4, then Q)."},
  {"when":"l19_road_circle","place":"white_circle","hint":"All four heads are marked. Put the demon's body on the white circle beside the red fountain; stay out of the fountain."},
  {"when":"l19_road_dawn","place":"dawn_lift","hint":"Leave the summoning room for the lift to Dawn. Ride up and speak with her until she explains the curse and offers the Ruby of Truth."},
  {"when":"l19_road_birth","place":"birthing_exit","hint":"Dawn has offered the Ruby of Truth. Follow the passage beyond her to the Birthing Chamber; the mother beast is next."}],
 "L20_BB": [
  {"when":"l20_road_dawn","place":"laboratory_return","hint":"Before confronting the mother, return to Dawn in Belial's Laboratory and hear what she says about the curse."},
  {"when":"l20_road_arrival","place":"mother_beast","hint":"Birthing Chamber: approach the mother beast. Expel the curse into her with Curse 5 (3, then Shift+Q), as Dawn explained."},
  {"when":"l20_road_demons","place":"mother_beast","hint":"The curse has entered the mother. Press E for the demons' fall; then take the way toward the five pillars."},
  {"when":"l20_road_pillars","place":"pillar_path","hint":"Next, the five pillars. Shoot all five with your bow to open the crossing."},
  {"when":"l20_road_scotia","place":"scotia","hint":"The pillar crossing is open. Reach Scotia's chamber and cast Prism 5 (5, then Shift+Q); the moving carrier opens the way on."},
  {"when":"l20_road_armory","place":"armory","hint":"Continue to the Armory. Break the brick at the westernmost block with your weapon."},
  {"when":"l20_road_ball","place":"armory_ball","hint":"The brick is broken. Break the white ball with Summon 3 (6, then Ctrl+Q)."},
  {"when":"l20_road_fire","place":"armory_fire","hint":"Now shoot the fireball with the Blue Bow or the Dark Bow. Brick, white ball and fireball must all be broken to stop the pillars."},
  {"when":"l20_road_draracle","place":"false_draracle","hint":"The pillars are stopped. Continue to the false Draracle and defeat him; the three Crystal Keys open the way to Belial."},
  {"when":"l20_road_key0","place":"crystal_key0","hint":"Take the first Crystal Key, then the second and third in order, to open Belial's room."},
  {"when":"l20_road_key1","place":"crystal_key1","hint":"The first Crystal Key is taken. Find the second Crystal Key next."},
  {"when":"l20_road_key2","place":"crystal_key2","hint":"The second Crystal Key is taken. Find the third Crystal Key to open Belial's room."},
  {"when":"l20_road_belial","place":"belial","hint":"The three Crystal Keys open Belial's room. Confront him with Belial's Horn, the Blue Bow or the Dark Sword."},
  {"when":"l20_road_finished","place":"","hint":"Belial is defeated. The journey is finished."}]
}
const FOUNTAIN_AT := Vector3(440, 85, 10438)
const FOUNTAIN_RADIUS := 800.0
const CAVERN_AT := Vector3(-5436, 32, 5802)
const CAVERN_RADIUS := 160.0
const HORN_AT := Vector3(120, 0, 525)
const HORN_RADIUS := 160.0
const SEWER_AT := Vector3(-323, 30, -2124)
const SEWER_RADIUS := 200.0
const HEADS_AT := [Vector3(1451, -130, -1131), Vector3(1018, -130, -1128), Vector3(1028, -110, -1892), Vector3(1451, -110, -1891)]
const HEADS_RADIUS := 160.0
const DAWN_AT := Vector3(2802, -1000, -882)
const MOTHER_AT := Vector3(-1160, -20, -4258)
const CURSE_RADIUS := 160.0
var host: Node3D

static func attach(map: Node3D) -> Node:
	var node: Node = load("res://scripts/lol2/act3_journal_hints.gd").new()
	var area := str(map.get("area_id"))
	if area != "L16_CA" and area != "L17_HC" and area != "L19_BC" and area != "L20_BB":
		node.free()
		return null
	node.host = map
	node.name = "Act3JournalHints"
	map.add_child(node)
	return node

static func flat_to(pos: Vector3, at: Vector3) -> float:
	return Vector2(pos.x - at.x, pos.z - at.z).length()

static func _ints(raw: Variant) -> int:
	if not raw is Array:
		return 0
	var count := 0
	for item in raw:
		if item is int or item is float:
			var _id := int(item)
			count += 1
	return count

func _open(key: String, field: String) -> bool:
	var quests: Variant = host.get("quest_state")
	if not quests is Dictionary or not quests.has(key):
		return true
	var row: Variant = quests[key]
	if not row is Dictionary:
		return true
	return not bool(row.get(field, false))

func check() -> void:
	if not is_instance_valid(host) or host.get("player") == null:
		return
	var pos: Vector3 = host.player.global_position
	if host.get_node_or_null("L16DryFountain") != null and _open("l16_dry_fountain", "broken") and flat_to(pos, FOUNTAIN_AT) <= FOUNTAIN_RADIUS:
		MyJournal.discover(host, "l16_south_fountain")
	if host.get_node_or_null("L17CavernRun") != null and _exit_open() and flat_to(pos, CAVERN_AT) <= CAVERN_RADIUS:
		MyJournal.discover(host, "l17_cavern_exit")
	if host.get_node_or_null("L19BelialHorn") != null and _open("l19_belial_horn", "taken") and flat_to(pos, HORN_AT) <= HORN_RADIUS:
		MyJournal.discover(host, "l19_horn_keep")
	if host.get_node_or_null("L19SewerForms") != null and _switches() < 3 and flat_to(pos, SEWER_AT) <= SEWER_RADIUS:
		MyJournal.discover(host, "l19_sewer_cross")
	if host.get_node_or_null("L19GhostlyHeads") != null and _shots() < 4 and _nearest_head(pos) <= HEADS_RADIUS:
		MyJournal.discover(host, "l19_ghostly_heads")
	if _curse_open() and _near_curse(pos):
		MyJournal.discover(host, "l19_curse_mother")

func _exit_open() -> bool:
	var quests: Variant = host.get("quest_state")
	if not quests is Dictionary or not quests.has("l17_cavern_run"):
		return true
	var row: Variant = quests["l17_cavern_run"]
	if not row is Dictionary:
		return true
	return int(row.get("exit_region", -1)) < 0

func _switches() -> int:
	var quests: Variant = host.get("quest_state")
	if not quests is Dictionary:
		return 0
	var row: Variant = quests.get("l19_sewer_forms", {})
	if not row is Dictionary:
		return 0
	return _ints(row.get("switches", []))

func _shots() -> int:
	var quests: Variant = host.get("quest_state")
	if not quests is Dictionary:
		return 0
	var row: Variant = quests.get("l19_ghostly_heads", {})
	if not row is Dictionary:
		return 0
	return _ints(row.get("shot", []))

func _nearest_head(pos: Vector3) -> float:
	var nearest := INF
	for at in HEADS_AT:
		nearest = minf(nearest, flat_to(pos, at))
	return nearest

func _curse_open() -> bool:
	var quests: Variant = host.get("quest_state")
	if not quests is Dictionary or not quests.has("l19_dawn_curse"):
		return true
	var row: Variant = quests["l19_dawn_curse"]
	if not row is Dictionary:
		return true
	return not bool(row.get("curse_said", false))

func _near_curse(pos: Vector3) -> bool:
	if host.get_node_or_null("L19DawnCurse") != null and flat_to(pos, DAWN_AT) <= CURSE_RADIUS:
		return true
	if host.get_node_or_null("L20MotherCurse") != null and flat_to(pos, MOTHER_AT) <= CURSE_RADIUS:
		return true
	return false

func _process(_delta: float) -> void:
	check()
	check_road()

## Presentation projection of the same owner receipts used by the earned chain.
static func road_stage(area:String, quests:Dictionary)->int:
	if area=="L17_HC":return 1 if quests.get("l17_beast_blade",{}).get("cut",false) else 0
	if area=="L19_BC":
		if quests.get("l19_dawn_curse",{}).get("ruby_offered",false):return 7
		var heads:Dictionary=quests.get("l19_ghostly_heads",{})
		if heads.get("dragged",false):return 6
		if heads.get("shot",[]).size()==4:return 5
		if quests.get("l19_drain_path",{}).get("door_clicked",false):return 4
		var sewer:Dictionary=quests.get("l19_sewer_forms",{})
		if sewer.get("switches",[]).size()==3:return 3
		if sewer.get("lizard_at_wall",false):return 2
		return 1 if quests.get("l19_belial_horn",{}).get("taken",false) else 0
	if area=="L20_BB":
		if quests.get("l20_finale",{}).get("game_finished",false):return 13
		var drar:Dictionary=quests.get("l20_faux_draracle",{})
		if drar.get("room",false):return 12
		if drar.get("killed",false):return 9+mini(2,drar.get("keys",[]).size())
		var arm:Dictionary=quests.get("l20_armory",{})
		if arm.get("stopped",false):return 8
		if arm.get("hacked",false):return 7 if arm.get("ball",false) else 6
		var pillars:Dictionary=quests.get("l20_pillars_scotia",{})
		if pillars.get("trinity",false):return 5
		if pillars.get("path_open",false):return 4
		var mother:Dictionary=quests.get("l19_dawn_curse",{})
		if mother.get("demons_killed",false):return 3
		if mother.get("glob_entered",false):return 2
		return 1 if mother.get("curse_said",false) else 0
	return -1

func check_road()->void:
	if not is_instance_valid(host) or not host.get("quest_state") is Dictionary:return
	var area:String=str(host.get("area_id"))
	if not ROAD.has(area) or not is_instance_valid(host.get("player")):return
	var magic:Variant=host.get("starting_magic")
	if is_instance_valid(magic) and not magic.world_active():return
	# Cast/use feedback owns its visible lifetime. Discover also writes a Journal
	# notice, so defer BOTH writes until it ends, then project the current stage.
	# The existing once-only Journal receipt prevents a repeat after load.
	var hud:Variant=host.get("interface_hud")
	if is_instance_valid(hud) and float(hud.get("save_notice_remaining"))>0:return
	var row:Dictionary=ROAD[area][road_stage(area,host.quest_state)]
	if MyJournal.discover(host,row.when):host.save_feedback(row.hint)
