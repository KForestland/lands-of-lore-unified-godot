extends SceneTree
## Shared item catalog pilot: identity, slot, scope and capacity against the existing
## per-area predicates (player_equipment, museum_save, jungle_save). Static/headless;
## the 27-item Museum case is an inventory fixture, not an earned-reachability claim.
const Catalog = preload("res://scripts/lol2/item_catalog.gd")
const Equipment = preload("res://scripts/lol2/player_equipment.gd")
const MuseumSave = preload("res://scripts/lol2/museum_save.gd")
const JungleSave = preload("res://scripts/lol2/jungle_save.gd")
const Captain = preload("res://scripts/lol2/cave_captain_items.gd")
## Frozen before-matrix (P04 probe full_before_matrix.log, 2026-10-07): id -> [weapon, armor, offhand, museum, jungle].
const BEFORE := {
	"draracle/prop/1108/sample": [
		0,
		0,
		0,
		1,
		1
	],
	"museum:item11:Fine_Longsword": [
		1,
		0,
		0,
		1,
		1
	],
	"museum:item10:Mail_Shirt": [
		0,
		1,
		0,
		1,
		1
	],
	"museum:item8:Champion_Stone": [
		0,
		0,
		0,
		1,
		1
	],
	"museum:item9:Champion_Stone": [
		0,
		0,
		0,
		1,
		1
	],
	"museum:control181:Tho_Broken": [
		0,
		0,
		0,
		1,
		1
	],
	"jungle:item51:Th_Dagger": [
		1,
		0,
		0,
		0,
		1
	],
	"jungle:weapon_shop:Gargoyle_Bracers": [
		0,
		0,
		1,
		0,
		1
	],
	"hive:runes:Ancients_Stone": [
		0,
		0,
		0,
		0,
		1
	],
	"cave:captain:Short_Sword": [
		1,
		0,
		0,
		1,
		1
	],
	"cave:captain:Burnt_Chain": [
		0,
		1,
		0,
		1,
		1
	],
	"cave:prop144:harvest1:Stalagmite": [
		1,
		0,
		0,
		1,
		1
	],
	"cave:prop145:harvest1:Stalagmite": [
		1,
		0,
		0,
		1,
		1
	],
	"cave:prop146:harvest1:Stalagmite": [
		1,
		0,
		0,
		1,
		1
	],
	"cave:prop147:harvest1:Stalagmite": [
		1,
		0,
		0,
		1,
		1
	],
	"cave:prop148:harvest1:Stalagmite": [
		1,
		0,
		0,
		1,
		1
	],
	"cave:prop149:harvest1:Stalagmite": [
		1,
		0,
		0,
		1,
		1
	],
	"cave:prop641:harvest1:Stalagmite": [
		1,
		0,
		0,
		1,
		1
	],
	"cave:prop791:harvest1:Cave_Aloe": [
		0,
		0,
		0,
		1,
		1
	],
	"cave:prop791:harvest2:Cave_Aloe": [
		0,
		0,
		0,
		1,
		1
	],
	"cave:prop791:harvest3:Cave_Aloe": [
		0,
		0,
		0,
		1,
		1
	],
	"cave:prop792:harvest1:Cave_Aloe": [
		0,
		0,
		0,
		1,
		1
	],
	"cave:prop792:harvest2:Cave_Aloe": [
		0,
		0,
		0,
		1,
		1
	],
	"cave:prop792:harvest3:Cave_Aloe": [
		0,
		0,
		0,
		1,
		1
	],
	"cave:prop793:harvest1:Cave_Aloe": [
		0,
		0,
		0,
		1,
		1
	],
	"cave:prop793:harvest2:Cave_Aloe": [
		0,
		0,
		0,
		1,
		1
	],
	"cave:prop793:harvest3:Cave_Aloe": [
		0,
		0,
		0,
		1,
		1
	],
	"jungle:weapon_shop:Short_Sword": [
		1,
		0,
		0,
		0,
		1
	],
	"jungle:weapon_shop:Long_Arm": [
		1,
		0,
		0,
		0,
		1
	],
	"jungle:weapon_shop:Firestorm": [
		1,
		0,
		0,
		0,
		1
	],
	"monastery:item94:Iron_Flute": [
		0,
		0,
		0,
		0,
		1
	],
	"monastery:item83:Power_Orb": [
		0,
		0,
		0,
		0,
		1
	],
	"hive:item0:Wax": [
		0,
		0,
		0,
		0,
		1
	],
	"jungle:magic_shop:War_cluster": [
		0,
		0,
		0,
		0,
		1
	],
	"jungle:magic_shop:Mana_foil": [
		0,
		0,
		0,
		0,
		1
	],
	"jungle:magic_shop:SS5": [
		0,
		0,
		0,
		0,
		1
	],
	"jungle:magic_shop:Fire_crystals_1": [
		0,
		0,
		0,
		0,
		1
	],
	"jungle:magic_shop:Fire_crystals_2": [
		0,
		0,
		0,
		0,
		1
	],
	"jungle:magic_shop:Fire_crystals_3": [
		0,
		0,
		0,
		0,
		1
	],
	"jungle:magic_shop:Dag_Light": [
		1,
		0,
		0,
		0,
		1
	],
	"jungle:magic_shop:Tho_fixed": [
		1,
		0,
		0,
		0,
		1
	],
	"jungle:item0:Snare": [
		0,
		0,
		0,
		0,
		1
	],
	"jungle:item50:Wax": [
		0,
		0,
		0,
		0,
		1
	],
	"jungle:item52:Ironwod_sap": [
		0,
		0,
		0,
		0,
		1
	],
	"jungle:item53:Ironwod_sap": [
		0,
		0,
		0,
		0,
		1
	],
	"jungle:item54:Vels_fruit": [
		0,
		0,
		0,
		0,
		1
	],
	"jungle:item55:Vels_fruit": [
		0,
		0,
		0,
		0,
		1
	],
	"jungle:item56:Vels_fruit": [
		0,
		0,
		0,
		0,
		1
	],
	"jungle:item57:Vels_fruit": [
		0,
		0,
		0,
		0,
		1
	],
	"jungle:item63:Cave_aloe": [
		0,
		0,
		0,
		0,
		1
	],
	"jungle:item64:Cave_aloe": [
		0,
		0,
		0,
		0,
		1
	],
	"jungle:item65:Cave_aloe": [
		0,
		0,
		0,
		0,
		1
	],
	"jungle:item66:Cave_aloe": [
		0,
		0,
		0,
		0,
		1
	],
	"jungle:item67:Cave_aloe": [
		0,
		0,
		0,
		0,
		1
	],
	"hive:Wax_runes:0": [
		0,
		0,
		0,
		0,
		1
	],
	"hive:Wax_runes:1": [
		0,
		0,
		0,
		0,
		1
	],
	"hive:Wax_runes:2": [
		0,
		0,
		0,
		0,
		1
	],
	"hive:Wax_runes:3": [
		0,
		0,
		0,
		0,
		1
	],
	"hive:Wax_runes:4": [
		0,
		0,
		0,
		0,
		1
	],
	"hive:Wax_runes:5": [
		0,
		0,
		0,
		0,
		1
	],
	"hive:Wax_runes:6": [
		0,
		0,
		0,
		0,
		1
	],
	"hive:Wax_runes:7": [
		0,
		0,
		0,
		0,
		1
	],
	"hive:Wax_runes:8": [
		0,
		0,
		0,
		0,
		1
	],
	"hive:Wax_runes:9": [
		0,
		0,
		0,
		0,
		1
	],
	"hive:Wax_runes:10": [
		0,
		0,
		0,
		0,
		1
	],
	"hive:Wax_runes:11": [
		0,
		0,
		0,
		0,
		1
	],
	"hive:Wax_runes:12": [
		0,
		0,
		0,
		0,
		1
	],
	"hive:Wax_runes:13": [
		0,
		0,
		0,
		0,
		1
	],
	"hive:Wax_runes:14": [
		0,
		0,
		0,
		0,
		1
	],
	"hive:Wax_runes:15": [
		0,
		0,
		0,
		0,
		1
	],
	"hive:Wax_runes:16": [
		0,
		0,
		0,
		0,
		1
	],
	"hive:Wax_runes:17": [
		0,
		0,
		0,
		0,
		1
	],
	"hive:Wax_runes:18": [
		0,
		0,
		0,
		0,
		1
	],
	"hive:Wax_runes:19": [
		0,
		0,
		0,
		0,
		1
	],
	"hive:Wax_runes:20": [
		0,
		0,
		0,
		0,
		1
	],
	"hive:Wax_runes:21": [
		0,
		0,
		0,
		0,
		1
	],
	"hive:Wax_runes:22": [
		0,
		0,
		0,
		0,
		1
	]
}
var failed := false

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok and not failed:
		failed = true
		printerr("FAIL: "+message)
		quit(1)
	return ok
func museum_state(ids: Array, weapon: String = "", armor: String = "") -> Dictionary:
	var state: Dictionary = {"format":MuseumSave.FORMAT,"version":1,"player":{"position":[0,0,0],"yaw":0,"pitch":0},
		"checkpoint":{"version":1,"introduction_complete":true,"collected":ids,"equipped_item":weapon,"equipped_armor":armor,
		"sword":{"started":MuseumSave.SWORD in ids,"collected":MuseumSave.SWORD in ids,"elapsed":7.625 if MuseumSave.SWORD in ids else 0},"gate":{"target_open":false,"progress":0}}}
	state.checkpoint.museum_prism = "museum:prop280:Prism" in ids
	var blood_ids=preload("res://scripts/lol2/dragon_blood_state.gd").ITEMS
	if ids.any(func(id):return id in blood_ids):
		var population=preload("res://scripts/lol2/museum_skeleton_population_state.gd")
		state.checkpoint.skeletons=population.initial()
		population.damage(state.checkpoint.skeletons,population.source(),"20",1000)
		state.checkpoint.museum_blood_loot={"elapsed":5.0,"taken":blood_ids.map(func(id):return id in ids)}
	return state
## Owner states that agree with carrying a single conserved Museum item.
func with_owner_state(state: Dictionary, id: String) -> Dictionary:
	if id == "museum:control87:Sk_key": state.checkpoint.museum_key_locks = {"version":1,"loaded":[],"panel_state":0}
	if id == "museum:movable55:SS1": state.checkpoint.museum_key_locks = {"version":1,"loaded":[87],"panel_state":1}
	if id == "museum:prop153:Long_arm": state.checkpoint.museum_long_arm = {"version":1,"stage":2,"elapsed":0,"walkway":true,"pending":false}
	return state
func old_museum(id: String) -> bool:
	var state: Dictionary = with_owner_state(museum_state([id]), id)
	# The single Sk key / SS1 must agree with the key-lock state (museum_key_locks_state.gd conservation).
	return MuseumSave.validate(state) == ""
func old_jungle(id: String) -> bool: return JungleSave.validate_inventory({"collected":[id],"equipped_item":"","equipped_armor":""}) == ""

func run() -> void:
	# Literal ids are pinned to their current owners.
	for pair in [[MuseumSave.SWORD,"weapon"],[MuseumSave.MAIL,"armor"],[MuseumSave.CAVERN,""],[preload("res://scripts/lol2/cave_collectible.gd").ID,""],
			[preload("res://scripts/lol2/hive_ancient_stone.gd").ITEM,""],[preload("res://scripts/lol2/player_defense.gd").BRACERS,"offhand"]] + MuseumSave.STONES.map(func(id): return [id,""]):
		if not check(Catalog.known(pair[0]) and Catalog.slot(pair[0]) == pair[1],"Pinned id/slot differs: "+str(pair[0])):return
	if not check(Catalog.FIXED["hive:runes:Ancients_Stone"].icon == preload("res://scripts/lol2/hive_ancient_stone.gd").ROOT+"stone.png","Ancient Stone icon root moved"):return
	var all := Catalog.ids("jungle")
	var unique: Dictionary = {}
	for id in all: unique[id] = true
	if not check(unique.size() == all.size(),"Catalog enumeration has duplicates"):return
	# Before-matrix: every frozen row is reproduced exactly by the catalog and by the live integration guards.
	for id in BEFORE:
		var row: Array = BEFORE[id]
		var now := [int(Catalog.slot(id)=="weapon"),int(Catalog.slot(id)=="armor"),int(Catalog.slot(id)=="offhand"),int(Catalog.admitted(id,"museum")),int(Catalog.admitted(id,"jungle"))]
		if not check(now == row,"Catalog differs from before-matrix for %s: %s != %s" % [id,now,row]):return
		if not check(id in unique,"Enumeration misses "+id):return
	# Every enumerated id agrees with the live integration guards (equivalence, not only the frozen sample).
	for id in all:
		if not check(Equipment.weapon(id) == (Catalog.slot(id)=="weapon") and Equipment.armor(id) == (Catalog.slot(id)=="armor") and Equipment.offhand(id) == (Catalog.slot(id)=="offhand"),"player_equipment slot differs: "+id):return
		if not check(old_museum(id) == Catalog.admitted(id,"museum"),"museum_save collected admission differs: "+id):return
		if not check(old_jungle(id) == Catalog.admitted(id,"jungle"),"jungle_save collected admission differs: "+id):return
		var old_weapon := MuseumSave.validate(with_owner_state(museum_state([id],id),id)) == ""
		if not check(old_weapon == (Catalog.slot(id)=="weapon" and Catalog.admitted(id,"museum")),"museum_save weapon slot differs: "+id):return
		if Catalog.slot(id) in ["weapon","armor"]:
			var old_label: String = Equipment.label(id) if Catalog.slot(id)=="weapon" else Equipment.armor_label(id)
			if not check(old_label == Catalog.label(id),"Equipment label differs: %s %s/%s" % [id,old_label,Catalog.label(id)]):return
			if Catalog.slot(id)=="weapon" and not check(Equipment.icon(id) == Catalog.icon(id),"Equipment icon differs: "+id):return
		if not check(not Catalog.label(id).is_empty() and (Catalog.icon(id).is_empty() or FileAccess.file_exists(Catalog.icon(id))),"Missing label/icon file: "+id):return
	# Source-backed defense bytes (prepare_cave_captain_items.py armor_scalars).
	var scalars: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/captain-items-source-checks.json")).armor_scalars
	var defense_source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/act-one-item-defenses.json")).items
	for id in Catalog.ids("jungle"):
		if Catalog.slot(id).is_empty(): continue
		if not check(defense_source.has(id),"Missing source defense: "+id):return
		if not check(Catalog.defense(id)==int(defense_source[id].defense),"Source defense differs: "+id):return
		var entries: Array=Catalog.mitigation(id)
		if not check(entries.size()==defense_source[id].descriptors.size(),"Source mitigation count differs: "+id):return
		for i in range(entries.size()):
			for j in range(3):
				if not check(entries[i][j]==defense_source[id].descriptors[i][j],"Source mitigation differs: "+id):return
		entries.append([7,0,4])
		if not check(Catalog.mitigation(id).size()==defense_source[id].descriptors.size(),"Mitigation aliases catalog data"):return
	if not check(Catalog.defense(Captain.ARMOR) == int(scalars.Burnt_Chain) and Catalog.defense(MuseumSave.MAIL) == int(scalars.Mail_Shirt) and Catalog.defense("jungle:weapon_shop:Gargoyle_Bracers") == int(scalars.Gargoyle_Bracers) and Catalog.defense(Captain.SWORD) == 0,"Defense values differ from source checks"):return
	# Cave scope = current cave predicates: stalagmite/captain/guard38/guard39/guard52/guard53/guard54 sword weapons, captain chain armor.
	for id in Catalog.ids("cave"):
		var cave_weapon: bool = Catalog.slot(id)=="weapon"
		if not check(cave_weapon == (preload("res://scripts/lol2/cave_stalagmite.gd").valid_item(id) or id in [Captain.SWORD,"cave:guard38:Short_Sword","cave:guard39:Short_Sword","cave:guard54:prop1013:Short_Sword","cave:guard54:actor54:Short_Sword","cave:guard52:Short_Sword","cave:guard53:Short_Sword"]) and (Catalog.slot(id)=="armor") == (id == Captain.ARMOR),"Cave slot scope differs: "+id):return
	# Capacity: the Museum universe is 28; old cap 22 rejected it (inventory fixture only).
	var museum_ids := Catalog.ids("museum")
	# +2 cave-origin ids: prop1050 Ancients' Stone and control75 Mana foil (cave_stone_manafoil.gd).
	if not check(museum_ids.size() == 43 and Catalog.ids("cave").size() == 29,"Museum/cave universe sizes changed: %d/%d" % [museum_ids.size(),Catalog.ids("cave").size()]):return
	if not check(Catalog.validate_carried(museum_ids,"museum").is_empty() and Catalog.validate_slots(museum_ids,"museum",Captain.SWORD,Captain.ARMOR).is_empty(),"Catalog rejects maximum Museum carry"):return
	var without_captain := museum_ids.filter(func(id): return not Captain.valid(id))
	# Carrying the Sk key and SS1 means no lock holds the key and the SS1 panel is empty.
	var full: Dictionary = museum_state(museum_ids,Captain.SWORD,Captain.ARMOR); full.checkpoint.museum_key_locks = {"version":1,"loaded":[],"panel_state":1}; full.checkpoint.museum_long_arm = {"version":1,"stage":2,"elapsed":0,"walkway":true,"pending":false}
	var partial: Dictionary = museum_state(without_captain); partial.checkpoint.museum_key_locks = {"version":1,"loaded":[],"panel_state":1}; partial.checkpoint.museum_long_arm = {"version":1,"stage":2,"elapsed":0,"walkway":true,"pending":false}
	if not check(MuseumSave.validate(full).is_empty() and MuseumSave.validate(partial).is_empty(),"Museum rejects full inventory with owned captain equipment"):return
	# Negative cases must still fail.
	var bad_lists := [null,"x",[1],["unknown:item"],[MuseumSave.SWORD,MuseumSave.SWORD],["jungle:item51:Th_Dagger"],[Captain.SWORD,"jungle:weapon_shop:Gargoyle_Bracers"]]
	for ids in bad_lists:
		if not check(not Catalog.validate_carried(ids,"museum").is_empty(),"Museum accepted bad list "+str(ids)):return
	var too_many: Array = []
	for index in range(Catalog.MAX_CARRIED+1): too_many.append(MuseumSave.SWORD)
	if not check(not Catalog.validate_carried(too_many,"jungle").is_empty() and not Catalog.validate_carried([],"hive").is_empty(),"Limit or scope not enforced"):return
	if not check(Catalog.validate_carried(["jungle:item51:Th_Dagger"],"jungle").is_empty() and not Catalog.validate_carried([MuseumSave.SWORD],"cave").is_empty(),"Scope order differs"):return
	var owned := [Captain.SWORD,Captain.ARMOR,"jungle:weapon_shop:Gargoyle_Bracers","jungle:item51:Th_Dagger"]
	if not check(Catalog.validate_slots(owned,"jungle",Captain.SWORD,Captain.ARMOR,"jungle:weapon_shop:Gargoyle_Bracers").is_empty(),"Owned jungle equipment rejected"):return
	for case in [[[],"jungle",Captain.SWORD,"",""],[owned,"jungle",Captain.ARMOR,"",""],[owned,"jungle","",Captain.SWORD,""],[owned,"jungle","","","jungle:item51:Th_Dagger"],
			[owned,"museum","jungle:item51:Th_Dagger","",""],[owned,"museum","","","jungle:weapon_shop:Gargoyle_Bracers"],[owned,"jungle",7,"",""],[owned,"jungle","",null,""],[owned,"jungle","unknown:item","",""]]:
		if not check(not Catalog.validate_slots(case[0],case[1],case[2],case[3],case[4]).is_empty(),"Bad equipment accepted: "+str(case.slice(1))):return
	if failed: return
	print("PASS item catalog: %d ids enumerated (cave27/museum35/jungle%d), 77-row before-matrix + live player_equipment/museum_save/jungle_save equivalence, labels/icons, defense8/20/5, Museum 35 accepted with captain equipment (fixture, not earned), negatives." % [all.size(),all.size()])
	quit()
