extends Node
const BeltState=preload("res://scripts/lol2/item_belt_state.gd")
const BeltTargets=preload("res://scripts/lol2/item_belt_targets.gd")
const StoredGlobes=preload("res://scripts/lol2/player_stored_globes.gd")
const Grants=preload("res://scripts/lol2/item_grants.gd")
const QuestResources=preload("res://scripts/lol2/quest_resource_protection.gd")
const PlayerHealth=preload("res://scripts/lol2/player_health.gd")
## Playable item adapter: human inventory use, saved consumption and world clock.
const State = preload("res://scripts/lol2/player_item_state.gd")
const Effects = preload("res://scripts/lol2/player_item_effects.gd")
const Handlers = preload("res://scripts/lol2/item_handlers.gd")
## The last use's route through item_handlers.gd (plan step 4, family 1: the player consumables). Every use is routed by the
## item's definition handler index first; a definition whose handler is not hosted is refused with the route's hint before any
## family branch runs. Every branch below is hosted (handlers 2, 4, 6, 9, 10, 20, 27, 43, 98, 102), so nothing changed for them.
var last_route: Dictionary = {}
## Family 2 (equip): the off-hand slot change is routed as dispatcher mode 10 (slot in) / 11 (slot out) and recorded; equipping
## never refuses on the route (equip_allowed), because the port applies the definition's defense byte and the passive handlers'
## slot hooks (19 Gargoyle bracers, 23 Stone bracers) are the unhosted part, named by the route.
var last_equip_route: Dictionary = {}
const Catalog = preload("res://scripts/lol2/item_catalog.gd")
const AncientEffect = preload("res://scripts/lol2/ancient_stone_effect.gd")
const Ancient = preload("res://scripts/lol2/hive_ancient_stone.gd")
const AloeEffect = preload("res://scripts/lol2/cave_aloe_effect.gd")
# Explicit modern cadence: 60 fixed updates/sec, 27 native clock units/update.
const ALOE_TICK_UNITS := 27
var host: Node
var thrown_items:Node3D
var dragon_blood: Node3D
func _ready() -> void:
	host=get_parent()
	dragon_blood=preload("res://scripts/lol2/player_dragon_blood.gd").new()
	add_child(dragon_blood);dragon_blood.setup(self)
	thrown_items=preload("res://scripts/lol2/player_thrown_items.gd").new();add_child(thrown_items);thrown_items.setup(self)
func state() -> Dictionary:
	if host.get("carried_inventory")!=null:
		if not host.carried_inventory.has("item_effects"): host.carried_inventory.item_effects=State.initial()
		return host.carried_inventory.item_effects
	return host.item_effect_checkpoint
func carried() -> Array:
	if host.has_method("carried_items"): return host.carried_items()
	return host.carried_inventory.collected if host.get("carried_inventory")!=null else host.carried_collected
func equip_offhand(id: String) -> bool:
	if host.player_form != 0 or (id != "" and (not preload("res://scripts/lol2/player_equipment.gd").offhand(id) or id not in carried())): return false
	var previous: String = str(state().get("offhand", ""))
	last_equip_route = Handlers.route(Catalog.definition(id), 10) if not id.is_empty() else (Handlers.route(Catalog.definition(previous), 11) if not previous.is_empty() else {})
	if id.is_empty(): state().erase("offhand")
	else: state().offhand = id
	return true
func accessories()->Array:
	return state().get("accessories",["",""]).duplicate()
func equip_accessory(id:String,slot:int=-1)->bool:
	if host.player_form!=0 or is_asleep() or (id!="" and (Catalog.slot(id)!="accessory" or id not in carried())):return false
	var worn:Array=accessories()
	var existing:int=worn.find(id) if id!="" else -1
	if slot<0:
		if existing>=0:worn[existing]=""
		else:
			slot=worn.find("")
			if slot<0:
				if host.has_method("save_feedback"):host.save_feedback("Remove an accessory first.")
				return false
			worn[slot]=id
	else:
		if slot>1:return false
		if existing>=0:worn[existing]=""
		worn[slot]=id
	if worn==["",""]:state().erase("accessories")
	else:state().accessories=worn
	if is_instance_valid(host.get("interface_hud")):host.interface_hud.refresh_equipment()
	return true
func prune_accessories(owned:Array)->void:
	if not state().has("accessories"):return
	var worn:Array=accessories()
	for index in worn.size():
		if worn[index] not in owned:worn[index]=""
	if worn==["",""]:state().erase("accessories")
	else:state().accessories=worn
const SERUM_REFUSAL := "The Amaranth Serum does nothing on its own. Keep it to mix with a Silverleaf."
var item_refusal:=""
func refuse_item(text:String)->bool:
	item_refusal=text
	if host.has_method("save_feedback"):host.save_feedback(text)
	return false
func no_effect_reason(id:String)->String:
	var kind:String=Catalog.use_kind(id)
	var magic:Node=host.get("starting_magic")
	if not is_instance_valid(magic) or magic.health()<=0:return ""
	if kind in ["aloe","black_lichen"] and magic.health()>=PlayerHealth.limit_for(host):return "You are not hurt."
	if kind in ["silverleaf","mana_foil"]:
		var saved:Dictionary=magic.magic_state()
		if int(saved.get("player",{}).get("mana",0))>=int(saved.get("player",{}).get("maximum",0)):return "Your mana is already full."
	if kind in ["ironwood_sap","vels_fruit","amaranth_serum","inert_food"]:
		return SERUM_REFUSAL if kind=="amaranth_serum" else "That has no useful effect now. Keep it."
	if kind=="dampen_charm":
		var curse:Variant=host.get("curse")
		if not is_instance_valid(curse) or int(curse.state.get("phase",0))!=1:return "There is no pending curse to dampen."
	if kind in ["poison_paint","death_sac"] and preload("res://scripts/lol2/weapon_poison.gd").host_coats(host)>=9:return "The weapon already has nine poison coats."
	if kind=="ancient" and int(state().get("ancient_charges",0))>AncientEffect.COUNTER_LIMIT:return "You already carry the maximum Ancient Stone charges."
	if kind=="war_cluster" and state().has("war_cluster"):return "A War Cluster is already active."
	if kind=="lamplight_eggs" and float(state().get("low_light",0.0))>0:return "Low-light vision is already active."
	if kind=="mandrake":
		var saved:Dictionary=magic.magic_state()
		if magic.health()>=PlayerHealth.limit_for(host) and int(saved.get("player",{}).get("mana",0))>=int(saved.get("player",{}).get("maximum",0)):return "Your health and mana are already full."
	if kind=="mind_cluster":
		var Atlas=load("res://scripts/lol2/atlas_explored.gd")
		var area:String=Atlas.area_of(host)
		if not area.is_empty() and Atlas.stored(host).get("areas",{}).get(area,{}).get("full",false):return "This area's map is already revealed."
	return ""
func use(id: String, world_request:bool=false) -> bool:
	item_refusal=""
	if not StoredGlobes.spell(id).is_empty():return queue_stored_globe(id,world_request)
	if not Catalog.target_hint(id).is_empty():
		if host.player_form!=0 or id not in carried() or not is_instance_valid(host.inventory) or not host.has_method("hold_in_hand") or is_asleep():return false
		if not is_instance_valid(host.starting_magic) or host.starting_magic.health()<=0:return false
		if host.get("hand_item")!=id and not host.hold_in_hand(id):return false
		last_route={"definition":Catalog.definition(id),"selection_only":true}
		host.save_feedback(Catalog.target_hint(id))
		return true
	if host.player_form!=0 or Catalog.use_kind(id) == "" or id not in carried(): return false
	if not world_request and not is_instance_valid(host.inventory): return false
	var no_effect:=no_effect_reason(id)
	if not no_effect.is_empty():return refuse_item(no_effect)
	var protected:=QuestResources.removing(host,carried(),id)
	if not protected.is_empty():return refuse_item(protected)
	last_route = Handlers.route(Catalog.definition(id), Handlers.mode_for_use_kind(Catalog.use_kind(id)))
	if int(last_route.get("handler", -1)) > 0 and not bool(last_route.get("hosted", false)):
		if host.has_method("save_feedback"): host.save_feedback(str(last_route.get("refusal", "")))
		return false
	var current:=state()
	if Catalog.use_kind(id)=="stored_spell":
		if not world_request:return queue_stored_scroll(id)
		if not pending_scroll.is_empty() or not scroll_consumption_ready(id):return false
		pending_scroll=id;finish_stored_scroll(id);return id not in carried()
	if Catalog.use_kind(id)=="lamplight_eggs":return preload("res://scripts/lol2/player_item_sight.gd").use(self,id)
	if Catalog.use_kind(id)=="dragon_blood":return dragon_blood.place(id)
	if Catalog.use_kind(id) in ["mandrake","gorgonite","inert_food","mind_cluster","war_cluster"]:
		return preload("res://scripts/lol2/player_food_effects.gd").apply(self,id)
	if Catalog.use_kind(id)=="black_lichen":
		if not can_consume(id) or host.starting_magic.health()<=0 or host.starting_magic.health()>=PlayerHealth.limit_for(host):return false
		if not consume_item(id):return false
		host.starting_magic.set_health(mini(PlayerHealth.limit_for(host),host.starting_magic.health()+20))
		return true
	# Poison Paint (definition 125, handler 10 mode 0x0C): one coat on the weapon, refused at nine (weapon_poison.gd).
	if Catalog.use_kind(id) in ["poison_paint","death_sac"]:
		if not is_instance_valid(host.starting_magic) or host.starting_magic.health() <= 0: return false
		if not preload("res://scripts/lol2/weapon_poison.gd").use(host,id): return false
		current.spent.append(id)
		return true
	# Sap (handler98) and Vels fruit (handler20) consume the held item. Fruit also clears player status +1B5 and
	# turns its indicator off; the port has no status model, so that cure has nothing to clear (docs/vels-fruit-use.md).
	if Catalog.use_kind(id) in ["ironwood_sap","vels_fruit","amaranth_serum"]:
		if not is_instance_valid(host.starting_magic) or host.starting_magic.health() <= 0: return false
		# The shaman's unique serum has no effect alone (Brady printed42); consuming it would strand the Larkhon
		# recipe (original softlock, hintbook ch.8 "go back to a saved game"). Refused with a hint (DEVIATIONS 0308).
		if id == preload("res://scripts/lol2/l8_shaman_trade.gd").SERUM:
			if host.has_method("save_feedback"): host.save_feedback(SERUM_REFUSAL)
			return false
		current.spent.append(id)
		carried().erase(id)
		return true
	# Dampen charm (definition72, handler27 0x979A8): consumes the held charm and sets player byte 0x23ABD bit0. No
	# native reader of that bit is established; modern adapter (lead-authorised): a pending curse warning is cancelled.
	if Catalog.use_kind(id) == "dampen_charm":
		if not is_instance_valid(host.starting_magic) or host.starting_magic.health() <= 0: return false
		current.spent.append(id)
		carried().erase(id)
		current.dampened = true
		var curse = host.get("curse")
		if curse != null and int(curse.state.get("phase",0)) == 1:
			curse.state.merge({"phase":0,"target":int(host.player_form),"remaining":0.0,"duration":0.0},true)
		return true
	if Catalog.use_kind(id) == "fire_crystal":
		# Handler2: the charge is spent first, then the fire effect looks for a target; at 0 the crystal burns out.
		var charges := crystal_charges(id)
		if charges <= 0 or not is_instance_valid(host.starting_magic) or host.starting_magic.health() <= 0: return false
		if not current.has("fire_crystals"): current.fire_crystals = {}
		current.fire_crystals[id] = charges - 1
		host.starting_magic.crystal_fire()
		return true
	# Every Ancient Stone (Hive rune room, Cave prop1050) is definition68/handler6 and shares the player counter byte.
	if Catalog.use_kind(id) == "ancient":
		if not is_instance_valid(host.starting_magic) or host.starting_magic.health() <= 0: return false
		var use := AncientEffect.use(1,int(current.get("ancient_charges",0)),0)
		if use.result != 1: return false
		current.ancient_charges = use.counter
		current.spent.append(id)
		carried().erase(id)
		return true
	if Catalog.use_kind(id) == "silverleaf":
		if not is_instance_valid(host.starting_magic) or host.starting_magic.health() <= 0: return false
		var magic: Dictionary = host.starting_magic.magic_state().duplicate(true)
		# Book effect; refuse at full mana rather than spend the quest ingredient.
		if int(magic.player.mana) >= int(magic.player.maximum): return false
		magic.player.mana = mini(int(magic.player.maximum), int(magic.player.mana) + 5)
		current.spent.append(id)
		if not host.has_method("carried_items"): carried().erase(id)
		host.starting_magic.commit(magic)
		return true
	if Catalog.use_kind(id) == "mana_foil":
		if not is_instance_valid(host.starting_magic) or host.starting_magic.health() <= 0: return false
		var magic: Dictionary = host.starting_magic.magic_state().duplicate(true)
		# Native mode1 consumes even at the cap. Shared UI adapter admits a carried item in human form.
		current.spent.append(id)
		if not host.has_method("carried_items"): carried().erase(id)
		magic.player.mana = preload("res://scripts/lol2/mana_foil_effect.gd").apply(int(magic.player.mana),int(magic.player.maximum))
		host.starting_magic.commit(magic)
		return true
	if Catalog.use_kind(id) == "aloe":
		if not is_instance_valid(host.starting_magic) or host.starting_magic.health() <= 0: return false
		if not current.has("aloe"): current.aloe = State.aloe_initial()
		if int(current.aloe.pending) == 0 and not host.starting_magic.protected(): current.aloe.base = host.starting_magic.health() & 0xff
		current.aloe.pending = AloeEffect.use(int(current.aloe.pending)).pending
		current.spent.append(id)
		# Cave retains harvest history; its inventory filters consumed IDs.
		if not host.has_method("carried_items"): carried().erase(id)
		return true
	var result:=Effects.use(current.champion,carried(),id,{"held":true,"gate_223d0":0,"action_flags":0,"caller_bit0":false,"gate_223d4":0})
	if result.has("error") or not result.applied: return false
	if not host.has_method("carried_items"):
		var admission:=Grants.commit(host,result.inventory)
		if not admission.ok:return refuse_item(admission.reason)
	current.champion=result.state
	current.spent.append(id)
	return true
func can_consume(id:String)->bool:
	return carried().count(id)==1 and id not in state().spent and State.validate(state(),carried()).is_empty()
func is_asleep()->bool:
	return float(state().get("mandrake_sleep",0.0))>0.0
func consume_item(id:String)->bool:
	if not can_consume(id):return false
	var protected:=QuestResources.removing(host,carried(),id)
	if not protected.is_empty():return refuse_item(protected)
	if not host.has_method("carried_items"):
		var next:Array=carried().duplicate();next.erase(id)
		var admitted:=Grants.commit(host,next)
		if not admitted.ok:return refuse_item(admitted.reason)
	state().spent.append(id)
	if host.get("carried_collected") is Array:Catalog.Act2Items.sync(host)
	if host.get("hand_item")==id:host.hand_item=""
	return true
## Remaining fire crystal charges (shop crystals start at 4; 0 = burnt out).
func crystal_charges(id: String) -> int:
	return int(state().get("fire_crystals", {}).get(id, int(Catalog.entry(id).get("initial_charges",State.CRYSTAL_SHOP_CHARGES))))
func crystal_burnt(id: String) -> bool:
	return Catalog.use_kind(id) == "fire_crystal" and crystal_charges(id) <= 0
## Lit-sconce kind4 mode3 (held "57b-Fire brnt"): op2 0x18 takes the held crystal, op3 grants "57a-Fire crstl"
## property1. Same carried id adapter: the crystal returns to 1 charge.
func recharge_crystal(id: String) -> bool:
	if not crystal_burnt(id) or id not in carried(): return false
	var current := state()
	if not current.has("fire_crystals"): current.fire_crystals = {}
	current.fire_crystals[id] = State.CRYSTAL_RECHARGE_CHARGES
	return true
func advance(delta: float) -> void:
	if not is_instance_valid(host.starting_magic) or not host.starting_magic.world_active(): return
	dragon_blood.advance(delta)
	if state().has("low_light"):state().low_light=maxf(0.0,float(state().low_light)-delta)
	if state().has("mandrake_sleep"):state().mandrake_sleep=maxf(0.0,float(state().mandrake_sleep)-delta)
	if state().has("war_cluster"):
		var war:Dictionary=state().war_cluster
		war.remaining=maxf(0.0,float(war.remaining)-delta)
		if war.remaining==0.0:
			var borrowed:int=int(war.bonus)
			state().erase("war_cluster")
			PlayerHealth.lose_host(host,borrowed)
	State.advance(state(),delta)
	if not is_finite(delta) or delta <= 0: return
	var current := state()
	if not current.has("aloe"): current.aloe = State.aloe_initial()
	var a: Dictionary = current.aloe
	if int(a.pending) == 0: return
	var total: float = float(a.fraction) + delta * 60.0
	var ticks := int(floorf(total))
	a.fraction = total-ticks
	for i in ticks:
		var input := {"health":host.starting_magic.health(),"maximum":PlayerHealth.limit_for(host),"base":int(a.base),"pending":int(a.pending),"pause":1 if host.starting_magic.protected() else 0,"hold":false,"frac":int(a.clock),"delta":ALOE_TICK_UNITS}
		var result := AloeEffect.tick(input)
		a.base = result.base
		a.pending = result.pending
		a.clock = (int(a.clock)+ALOE_TICK_UNITS) & 4095
		host.starting_magic.set_health(int(result.health))
func _process(delta: float) -> void:
	advance(delta)
	advance_belt(delta)
	preload("res://scripts/lol2/player_item_sight.gd").render(self)
func _exit_tree():preload("res://scripts/lol2/player_item_sight.gd").clear()
func melee_damage(base: int) -> int:
	# +20 is the recovered weapon-stat increment. The existing direct health-loss
	# adapter treats attack units as damage; this conversion remains provisional.
	return base+int(Effects.melee_bonus(state().champion).get("bonus",0))
func status() -> String:
	var s:=state()
	var lines: Array[String] = []
	if is_asleep():lines.append("Asleep · %ds"%ceili(float(s.mandrake_sleep)))
	if s.has("war_cluster"):lines.append("War Cluster · %ds"%ceili(float(s.war_cluster.remaining)))
	if s.get("offhand", "") != "":
		var offhand: String = str(s.offhand)
		lines.append("%s · Defense +%d" % [Catalog.label(offhand), Catalog.defense(offhand)] if host.player_form == 0 else Catalog.label(offhand) + " · Stored")
	if s.champion.active: lines.append("Champion Stone · %ds" % ceili(float(s.champion.timer)/65536.0/State.TICKS_PER_SECOND))
	if int(s.get("ancient_charges",0)) > 0: lines.append("Ancient Stone · %d charges" % int(s.ancient_charges))
	if s.get("dampened",false): lines.append("Dampen charm · used")
	for id in s.get("fire_crystals", {}):
		if id in carried(): lines.append("Fire crystal · burnt out" if int(s.fire_crystals[id]) <= 0 else "Fire crystal · %d charges" % int(s.fire_crystals[id]))
	return "\n".join(lines)

## Stored casts run after the inventory has actually exited and restored its
## pause/cursor state. Returning true here only asks the UI to close; consumption
## happens once, synchronously with an admitted cast below. Refusals keep the item.
var pending_scroll := ""
func scroll_consumption_ready(id: String) -> bool:
	if host.has_method("carried_items") or carried().count(id) != 1 or id in state().spent: return false
	if Catalog.stored_school(id).is_empty() or not State.validate(state(),carried()).is_empty(): return false
	var scrolls: Variant = host.get("scroll_pickups")
	var index := Catalog.MuseumScrolls.IDS.find(id)
	if index >= 0 and is_instance_valid(scrolls):
		return Catalog.MuseumScrolls.validate(scrolls.state,carried()).is_empty() and bool(scrolls.state.taken[index]) and not bool(scrolls.state.consumed[index])
	return true

func queue_stored_scroll(id: String) -> bool:
	if not pending_scroll.is_empty() or not scroll_consumption_ready(id): return false
	var inventory: Node = host.inventory
	if not is_instance_valid(inventory) or bool(inventory.previous_pause): return false
	pending_scroll = id
	inventory.tree_exited.connect(func(): finish_stored_scroll.call_deferred(id), CONNECT_ONE_SHOT)
	return true

func consume_stored_scroll(id: String) -> bool:
	if not scroll_consumption_ready(id): return false
	var scrolls: Variant = host.get("scroll_pickups")
	var index := Catalog.MuseumScrolls.IDS.find(id)
	if index >= 0 and is_instance_valid(scrolls):
		if not Catalog.MuseumScrolls.record_consumption(scrolls.state,carried(),index): return false
	else: carried().erase(id)
	state().spent.append(id)
	if host.get("carried_collected") is Array and host.get("quest_state") is Dictionary: Catalog.Act2Items.sync(host)
	if host.get("hand_item") == id: host.hand_item = ""
	return true

func finish_stored_scroll(id: String) -> void:
	if pending_scroll != id: return
	pending_scroll = ""
	if not is_instance_valid(host) or not host.is_inside_tree() or not scroll_consumption_ready(id): return
	var magic: Node = host.get("starting_magic")
	if not is_instance_valid(magic): return
	var school := Catalog.stored_school(id)
	var result: Dictionary = magic.use_stored_spell_from_interface(school)
	var text: String = magic.notice_text()
	if bool(result.get("used",false)):
		# No await/re-entry between the final preflight, effect and consumption.
		var consumed := consume_stored_scroll(id)
		assert(consumed,"Admitted scroll consumption must match its preflight")
		if bool(result.get("learned",false)): text = str(magic.SpellBook.NAMES[school])+" learned."
	elif text.is_empty(): text = "The scroll cannot be used now."
	if host.has_method("save_feedback"): host.save_feedback(text)
	elif host.has_method("_save_feedback"): host._save_feedback(text)

## Unconsciousness owns voluntary input, not the world clock: creatures and
## gravity continue. Save/load and passive menus retain their normal owners.
func _input(event:InputEvent)->void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E and use_belt_target():
		get_viewport().set_input_as_handled();return
	if not get_tree().paused and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F and host.starting_magic.world_active():
		use_belt_self();get_viewport().set_input_as_handled();return
	var roll:=0
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_BRACKETLEFT:roll=-1
		elif event.keycode==KEY_BRACKETRIGHT:roll=1
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:roll=-1
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:roll=1
	if roll!=0 and not get_tree().paused and host.starting_magic.world_active() and not is_asleep():
		BeltState.roll(belt_state(),carried(),roll)
		get_viewport().set_input_as_handled();return
	if not is_asleep() or get_tree().paused:return
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode in [KEY_E,KEY_Q,KEY_I,KEY_SPACE]:
		get_viewport().set_input_as_handled()

func belt_state()->Dictionary:
	if not state().has("belt"):
		state().belt=BeltState.initial()
		for id in carried():BeltState.pickup(state().belt,id,carried())
	return state().belt
func put_on_belt(id:Variant,index:int=-1)->bool:
	return BeltState.put(belt_state(),id,carried(),index)

var pending_globe:=""
func queue_stored_globe(id:String,world_request:bool)->bool:
	if not pending_globe.is_empty() or not StoredGlobes.ready(self,id) or host.player_form!=0:return false
	if world_request:return StoredGlobes.cast(self,id)
	if not is_instance_valid(host.inventory) or bool(host.inventory.previous_pause):return false
	pending_globe=id
	host.inventory.tree_exited.connect(func(): finish_stored_globe.call_deferred(id),CONNECT_ONE_SHOT)
	return true
func finish_stored_globe(id:String):
	if pending_globe!=id:return
	pending_globe=""
	if not is_instance_valid(host) or not host.is_inside_tree():return
	if not StoredGlobes.cast(self,id):
		if not item_refusal.is_empty():return
		var text:String=host.starting_magic.notice_text()
		host.save_feedback(text if not text.is_empty() else "The globe cannot be used here.")
func use_belt_self()->bool:
	if not is_instance_valid(host.starting_magic) or not host.starting_magic.world_active() or is_asleep():return false
	if host.player_form!=0:host.save_feedback("Return to Human form to use items.");return false
	var id:String=BeltState.resolve(belt_state(),int(belt_state().active),carried())
	if id.is_empty():host.save_feedback("The active belt slot is empty.");return false
	if not StoredGlobes.spell(id).is_empty():
		var used:=use(id,true)
		if not used and item_refusal.is_empty():host.save_feedback(host.starting_magic.notice_text() if not host.starting_magic.notice_text().is_empty() else "The globe cannot be used here.")
		return used
	if id==Catalog.Monastery.FLUTE:
		# F plays the carried flute; it must never take Hive's aimed-slot
		# inventory shortcut, because placing an item is an E action.
		var elevator:Variant=host.get("elevator")
		var played:bool=bool(elevator.play_flute()) if is_instance_valid(elevator) else bool(host.use_inventory_item(id)) if host.has_method("use_inventory_item") else false
		host.save_feedback("You play the flute." if played else "That does not fit here")
		return played
	if id==preload("res://scripts/lol2/l8_larkhon_state.gd").VAPORS and host.has_node("L8Larkhon"):
		return host.get_node("L8Larkhon").activate(id,true)
	if not Catalog.target_hint(id).is_empty() or Catalog.use_kind(id).is_empty():
		host.save_feedback("That does not fit here");return false
	# A belt slot identifies a definition; prefer a genuine free spare over
	# the exact Temple identity when both happen to share that definition.
	if not QuestResources.removing(host,carried(),id).is_empty():
		for candidate in carried():
			if candidate is String and Catalog.definition(candidate)==Catalog.definition(id) and QuestResources.removing(host,carried(),candidate).is_empty():id=candidate;break
	var previous_notice:String=host.interface_hud.hint.text if is_instance_valid(host.get("interface_hud")) else ""
	var used:=use(id,true)
	if not used and not item_refusal.is_empty():return false
	if not used and (not is_instance_valid(host.get("interface_hud")) or host.interface_hud.hint.text==previous_notice):host.save_feedback("That does not fit here")
	return used

var smart_item:=""
var smart_missing:=""
var smart_key:=""
var belt_seen:Array=[]
var belt_seen_ready:=false
var belt_observed_state:Dictionary={}
var belt_probe:=0.0
func advance_belt(delta:float):
	var owned:Array=carried()
	var value:=belt_state()
	if not is_same(belt_observed_state,state()):
		belt_seen=owned.duplicate();belt_seen_ready=true;belt_observed_state=state()
	if belt_seen_ready:
		for id in owned:
			if id not in belt_seen:BeltState.pickup(value,id,owned)
	belt_seen=owned.duplicate();belt_seen_ready=true
	for i in 5:
		if not BeltState.empty_ref(value.slots[i]) and BeltState.resolve(value,i,owned).is_empty():value.slots[i]=-1;value.ages[i]=0
	belt_probe-=delta
	if belt_probe>0:return
	belt_probe=0.1
	if not is_instance_valid(host.starting_magic) or not host.starting_magic.world_active() or host.player_form!=0 or is_asleep():smart_item="";smart_missing="";smart_key="";return
	var target:Dictionary=BeltTargets.find(host)
	var candidate:String=BeltTargets.pick(target,owned)
	smart_missing=BeltTargets.missing_hint(target) if candidate.is_empty() else ""
	var signature:String=str(target.get("key",""))+":"+candidate
	if signature!=smart_key:
		smart_key=signature
		if not candidate.is_empty():
			var index:int=value.slots.find(BeltState.identity(candidate))
			if index<0:
				# Aimed quest takes priority even when all five slots hold quests;
				# replacement only changes a reference, never the owned pack.
				index=value.slots.find(-1)
				if index<0:index=int(value.active)
				BeltState.put(value,candidate,owned,index)
			value.active=index
	var active:String=BeltState.resolve(value,int(value.active),owned)
	smart_item=active if not target.is_empty() and BeltTargets.accepts(target,active) else ""
func use_belt_target()->bool:
	if not is_instance_valid(host.starting_magic) or not host.starting_magic.world_active() or host.player_form!=0 or is_asleep():return false
	belt_probe=0.0;advance_belt(0.0) # Fresh aim on E, while preserving an explicit roll at the same target.
	var target:Dictionary=BeltTargets.find(host)
	if target.is_empty() or bool(target.get("native_e",false)):return false # Existing choices keep E, regardless of active slot.
	# E is an action on a carried quest item; a belt selection never gates it.
	var id:String=BeltTargets.pick(target,carried())
	if id.is_empty():
		host.save_feedback(BeltTargets.missing_hint(target));return true
	var result:Variant=target.apply.call(id)
	var text:String=str(result.get("reason","The item is used.")) if result is Dictionary else "The item is used."
	host.save_feedback(text)
	return true
