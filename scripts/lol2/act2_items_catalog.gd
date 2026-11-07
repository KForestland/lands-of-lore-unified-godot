extends RefCounted
## Placement identities preserve duplicate definitions. Source-only table, no item handlers.
const TOWER_BLANK := "act2:L9_DR:tower_blank"
## Lead04:52Z book-led pickup; no original L9 placement exists in the decoded census.
static func tower_blank() -> Dictionary:
	return {"id":TOWER_BLANK,"definition":98,"name":"96-E Globe","label":"Empty Glass Globe","icon":"res://assets/lol2/generated/items/icons/098.png","handler":0,"identity":4086156423,"position":[-3610,150,-850],"grade":"modern Tower pickup adapter; Prima100"}
static var _source: Dictionary = {}
static var _items: Dictionary = {}
static func source() -> Dictionary:
	if _source.is_empty():
		_source = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/act2_items_source.json"))
		for area in _source.areas:
			for row in _source.areas[area].items: _items[str(row.id)] = row
		_items[TOWER_BLANK] = tower_blank()
		for item in basin_items():_items[item.id]=item
	return _source
static func base_id(id: String) -> String:
	return id.get_slice(":charged:",0)
static func legacy_equipment(id:Variant)->bool:return id in ["act2:L12_CM:blue_bow","act2:L12_CM:item5","act2:L13_RC:dark_sword","act2:L13_RC:enchanted_thohan","act2:L19_BC:horn"] # horn: held to start the finale (2026-11-07)
static func dark_bow() -> Dictionary:
	source()
	var found: Array = []
	for excluded in _source.areas.L16_CA.excluded:
		if int(excluded.row) == 24: found.append(excluded)
	if found.is_empty(): return {}
	var bow: Dictionary = found[0].duplicate(true)
	bow.erase("reason")
	bow.id = "act2:L16_CA:item24"
	bow.definition = 35
	bow.name = "36-Darkbow"
	bow.label = "Dark Bow"
	bow.icon = "res://assets/lol2/generated/items/icons/035.png"
	bow.handler = 0
	bow.grade = "dormant L16 row 24 identity 3582735614; shown after prop 392 burns; the blue bow id stays"
	return bow
static func row(id: Variant) -> Dictionary:
	if not id is String: return {}
	source()
	if id.begins_with("act2:L14_HT:hopper_corpse") and id.trim_prefix("act2:L14_HT:hopper_corpse") in ["91","92","93","94","95"]:
		return {"id":id,"definition":-1,"name":"Hopper corpse","label":"Hopper corpse","icon":"res://assets/lol2/generated/l14_hopper_platform/corpse.png","handler":0,"identity":0,"grade":"modern unique defeated-actor carry adapter; original corpse frame4/palette"}
	if _items.has(id): return _items[id]
	if id=="act2:L14_HT:item65":return temple_machine_statue()
	if id in ["act2:L14_HT:trial_idol371","act2:L14_HT:trial_idol372","act2:L14_HT:trial_idol384"]:
		var idol:Dictionary=_items["act2:L14_HT:item5"].duplicate(true)
		idol.id=id;idol.position=[7620,310,-2095] if id.ends_with("371") else [-38,210,3209] if id.ends_with("372") else [-1701,220,-3170];idol.grade="source props371/372/384 groups15150/15210/15378 identity1200015E; modern persistent trial reward instance"
		return idol
	if id=="act2:L14_HT:post_shard":
		var post:Dictionary=_items["act2:L14_HT:item67"].duplicate(true)
		post.id=id;post.position=[3043,30,-5684];post.grade="original control71/group16904 identity; modern persistent pickup instance"
		return post
	if id.begins_with("act2:L16_CA:pad_lichen"):
		var pad:String=id.trim_prefix("act2:L16_CA:pad_lichen")
		if pad==str(int(pad)) and int(pad)>=0 and int(pad)<=8:return {"id":id,"definition":122,"name":"120-Black lichn","label":"Black Lichen","icon":"res://assets/lol2/generated/items/icons/122.png","handler":41,"identity":3394104268,"grade":"HINTBOOK 4788-4814 nine clumps on prop 210; adapter, not the 14 greenhouse planters"}
		return {}
	if id.begins_with("act2:L16_CA:lichen"):
		var record:String=id.trim_prefix("act2:L16_CA:lichen")
		if record==str(int(record)) and int(record) in [518,521,522,527,528,533,534,539,540,545,546,551,552,557]:return {"id":id,"definition":122,"name":"120-Black lichn","label":"Black Lichen","icon":"res://assets/lol2/generated/items/icons/122.png","handler":41,"identity":3394104268,"grade":"original L16 lichen opcode 3 identity CA4DEBCC; modern persistent per-placement pickup (STORY-068)"}
		return {}
	if id.begins_with("act2:L10_DC:silverleaf"):
		var suffix:String=id.trim_prefix("act2:L10_DC:silverleaf")
		if suffix==str(int(suffix)) and int(suffix)>=159 and int(suffix)<=170:return {"id":id,"definition":117,"name":"115-Silverleaf","label":"Silverleaf","icon":"res://assets/lol2/generated/items/icons/117.png","handler":39,"identity":238320129,"grade":"original tree grant; modern persistent harvest identity"}
		return {}
	if id=="act2:L16_CA:item24": return dark_bow()
	if id=="act2:L19_BC:horn": return {"id":id,"definition":22,"name":"23-Hrn Belial","label":"Hrn Belial","icon":"res://assets/lol2/generated/items/icons/022.png","handler":0,"identity":213789840,"grade":"opcode 3 identity 0x0CBE2C90 on prop 222; no placed L19 item; adapter grant"}
	if id=="act2:L12_CM:blue_bow":return {"id":id,"definition":35,"name":"36-Darkbow","label":"Blue Bow","icon":"res://assets/lol2/generated/items/icons/035.png","handler":58,"identity":3582735614,"grade":"book-led frozen blue bow adapter; native artifact is separately item36 Shard31"}
	if id=="act2:L12_CM:item5":return {"id":id,"definition":54,"name":"55-Obs chain","label":"Obsidian Chain Mail","icon":"res://assets/lol2/generated/items/icons/054.png","handler":0,"identity":1902058752,"grade":"original dormant item5; prop136 Spark reveal adapter"}
	if id=="act2:L13_RC:dark_sword":return {"id":id,"definition":21,"name":"22-Darkstorm","label":"Dark Sword","icon":"res://assets/lol2/generated/items/icons/021.png","handler":57,"identity":1694375167,"grade":"source175 award; modern altar identity"}
	if id=="act2:L13_RC:enchanted_thohan":return {"id":id,"definition":71,"name":"69-Tho enchant","label":"Enchanted Thohan’s Sword","icon":"res://assets/lol2/generated/items/icons/071.png","handler":60,"identity":4173120154,"grade":"source174 award; modern altar identity"}
	if id=="act2:L13_RC:dreamstone":return {"id":id,"definition":136,"name":"134-Dreamstone","label":"Dreamstone","icon":"res://assets/lol2/generated/items/icons/136.png","handler":0,"identity":3458248419,"grade":"source326 award; modern altar identity"}
	if id=="act2:L13_RC:dawn_bestial_disk":return {"id":id,"definition":80,"name":"78-Bestial disk","label":"Bestial Disk","icon":"res://assets/lol2/generated/items/icons/080.png","handler":30,"identity":2145901433,"grade":"original DSLAVE gift name; modern persistent receipt"}
	if id=="act2:L12_CM:kenneth_picture":return {"id":id,"definition":81,"name":"79-Portrait Ken","label":"Kenneth’s Picture","icon":"res://assets/lol2/generated/items/icons/081.png","handler":0,"identity":2358430593,"grade":"original prop4 grant; modern persistent identity"}
	if id=="act2:L12_CM:kenneth_charm":return {"id":id,"definition":90,"name":"88-Keneths chrm","label":"Kenneth’s Charm","icon":"res://assets/lol2/generated/items/icons/090.png","handler":0,"identity":4054701196,"grade":"original item definition; book-led picture impact adapter"}
	if id=="act2:L8_SJ:larkhon_vapors":return {"id":id,"definition":128,"name":"126-Larkhon vap","label":"Larkhon Vapors","icon":"res://assets/lol2/generated/items/icons/128.png","handler":95,"identity":1489524481,"grade":"original actor115 offer identity; modern book recipe"}
	if id=="act2:L8_SJ:shaman_amaranth":return {"id":id,"definition":119,"name":"117-Amaranth sr","label":"Amaranth Serum","icon":"res://assets/lol2/generated/items/icons/119.png","handler":98,"identity":77237872,"grade":"original SHAMAN gift definition; modern persistent exchange"}
	if id=="act2:L8_SJ:dawn_control_token":return {"id":id,"definition":76,"name":"74-Control tokn","label":"Control Token","icon":"res://assets/lol2/generated/items/icons/076.png","handler":28,"identity":3421151171,"grade":"original prop102 reward4340; modern shore exchange"}
	if id=="act2:L10_DC:priest_urn":return {"id":id,"definition":78,"name":"76-Caretk urn","label":"Caretaker Urn","icon":"res://assets/lol2/generated/items/icons/078.png","handler":0,"identity":3488201858,"grade":"source gift identity; modern admission/persistence"}
	if id=="act2:L10_DC:priest_ankh":return {"id":id,"definition":97,"name":"95-D Ankh","label":"Ankh","icon":"res://assets/lol2/generated/items/icons/097.png","handler":0,"identity":3885062029,"grade":"source priest gift identity; modern transaction"}
	if id=="act2:L10_DC:emperor_remains":return {"id":id,"definition":77,"name":"75-Emp remains","label":"Emperor Remains","icon":"res://assets/lol2/generated/items/icons/077.png","handler":0,"identity":3299785126,"grade":"source item definition; book-led Emperor reward adapter"}
	if id.count(":charged:")!=1: return {}
	var original: Dictionary = _items.get(base_id(id),{})
	var color: String = id.get_slice(":charged:",1)
	var definitions := {"yellow":99,"white":100,"blue":101}
	if int(original.get("definition",-1))!=98 or not definitions.has(color): return {}
	var transformed := original.duplicate(true)
	transformed.id = id
	transformed.definition = definitions[color]
	transformed.label = color.capitalize()+" Glass Globe"
	transformed.name = {"yellow":"97-Y globe","white":"98-W globe","blue":"99-B globe"}[color]
	transformed.icon = "res://assets/lol2/generated/items/icons/%03d.png" % int(definitions[color])
	return transformed
static func valid(id: Variant) -> bool: return not row(id).is_empty()
static func definition(id: Variant) -> int: return int(row(id).get("definition", -1))
static func initial() -> Dictionary: return {"version":1,"carried":[],"collected":[]}
static func validate(packet: Variant) -> String:
	if not packet is Dictionary or packet.size()!=3 or packet.get("version")!=1 or not packet.get("carried") is Array or not packet.get("collected") is Array: return "Invalid Act2 item packet."
	if packet.carried.size()>64: return "Act2 inventory exceeds capacity."
	for field in ["carried", "collected"]:
		var seen: Dictionary = {}
		for id in packet[field]:
			if not valid(id) or seen.has(base_id(id)): return "Invalid or duplicate Act2 item identity."
			seen[base_id(id)] = true
			if field=="collected" and base_id(id)!=id: return "Collection history needs original placement identities."
	for id in packet.carried:
		if base_id(id) not in packet.collected: return "Act2 carried item lacks collection history."
	return ""
static func sync(host: Node) -> void:
	var packet: Dictionary = host.quest_state.get("act2_items", initial()).duplicate(true)
	packet.carried = host.carried_collected.filter(func(id): return valid(id) and not legacy_equipment(id))
	if not packet.carried.is_empty() or host.quest_state.has("act2_items"): host.quest_state.act2_items = packet
static func restore(host: Node) -> String:
	var packet: Variant = host.quest_state.get("act2_items", initial())
	var error := validate(packet)
	if not error.is_empty(): return error
	var legacy: Array = host.carried_collected.filter(func(id):return not valid(id) or legacy_equipment(id))
	if legacy.size()+packet.carried.size()>64: return "Inventory exceeds capacity."
	host.carried_collected = legacy + packet.carried.duplicate()
	if is_instance_valid(host.get("act2_items")): host.act2_items.restore()
	return ""

static func basin_items()->Array:
	var rows:Array=[]
	for r in _source.areas.L13_RC.excluded:
		if int(r.row) not in [145,146,147]:continue
		var index:int={145:50,146:32,147:19}[int(r.row)]
		var row:Dictionary=r.duplicate(true);row.erase("reason");row.id="act2:L13_RC:item%d"%int(r.row);row.definition=index;row.name={50:"51-Cowards sh",32:"33-Myriad",19:"20-Bastion"}[index];row.label=row.name;row.icon="res://assets/lol2/generated/items/icons/%03d.png"%index;row.handler=0;row.grade="original dormant basin placement; modern drain admission";rows.append(row)
	return rows

static func temple_machine_statue()->Dictionary:
	source()
	var row:Dictionary=_source.areas.L14_HT.excluded.filter(func(r):return int(r.row)==65)[0].duplicate(true)
	row.erase("reason");row.id="act2:L14_HT:item65";row.definition=103;row.name="101-Statuette";row.label="Statuette";row.icon="res://assets/lol2/generated/items/icons/103.png";row.handler=0;row.grade="original dormant item65; machine3902 receipt adapter"
	return row
