extends Node
## Playable item adapter: human inventory use, saved consumption and world clock.
const State = preload("res://scripts/lol2/player_item_state.gd")
const Effects = preload("res://scripts/lol2/player_item_effects.gd")
const Catalog = preload("res://scripts/lol2/item_catalog.gd")
const AncientEffect = preload("res://scripts/lol2/ancient_stone_effect.gd")
const Ancient = preload("res://scripts/lol2/hive_ancient_stone.gd")
const AloeEffect = preload("res://scripts/lol2/cave_aloe_effect.gd")
# Explicit modern cadence: 60 fixed updates/sec, 27 native clock units/update.
const ALOE_TICK_UNITS := 27
var host: Node
var dragon_blood: Node3D
func _ready() -> void:
	host=get_parent()
	dragon_blood=preload("res://scripts/lol2/player_dragon_blood.gd").new()
	add_child(dragon_blood);dragon_blood.setup(self)
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
	if id.is_empty(): state().erase("offhand")
	else: state().offhand = id
	return true
func use(id: String) -> bool:
	if host.player_form!=0 or Catalog.use_kind(id) == "" or id not in carried(): return false
	if not is_instance_valid(host.inventory): return false
	var current:=state()
	if Catalog.use_kind(id)=="dragon_blood":return dragon_blood.place(id)
	# Sap (handler98) and Vels fruit (handler20) consume the held item. Fruit also clears player status +1B5 and
	# turns its indicator off; the port has no status model, so that cure has nothing to clear (docs/vels-fruit-use.md).
	if Catalog.use_kind(id) in ["ironwood_sap","vels_fruit"]:
		if not is_instance_valid(host.starting_magic) or host.starting_magic.health() <= 0: return false
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
	if id == Ancient.ITEM:
		if not is_instance_valid(host.starting_magic) or host.starting_magic.health() <= 0: return false
		var use := AncientEffect.use(1,int(current.get("ancient_charges",0)),0)
		if use.result != 1: return false
		current.ancient_charges = use.counter
		current.spent.append(id)
		carried().erase(id)
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
	current.champion=result.state
	current.spent.append(id)
	if host.get("carried_inventory")!=null: host.carried_inventory.collected=result.inventory
	else: host.carried_collected=result.inventory
	return true
func advance(delta: float) -> void:
	if not is_instance_valid(host.starting_magic) or not host.starting_magic.world_active(): return
	dragon_blood.advance(delta)
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
		var input := {"health":host.starting_magic.health(),"maximum":30,"base":int(a.base),"pending":int(a.pending),"pause":1 if host.starting_magic.protected() else 0,"hold":false,"frac":int(a.clock),"delta":ALOE_TICK_UNITS}
		var result := AloeEffect.tick(input)
		a.base = result.base
		a.pending = result.pending
		a.clock = (int(a.clock)+ALOE_TICK_UNITS) & 4095
		host.starting_magic.set_health(int(result.health))
func _process(delta: float) -> void: advance(delta)
func melee_damage(base: int) -> int:
	# +20 is the recovered weapon-stat increment. The existing direct health-loss
	# adapter treats attack units as damage; this conversion remains provisional.
	return base+int(Effects.melee_bonus(state().champion).get("bonus",0))
func status() -> String:
	var s:=state()
	var lines: Array[String] = []
	if s.get("offhand", "") != "":
		var offhand: String = str(s.offhand)
		lines.append("%s · Defense +%d" % [Catalog.label(offhand), Catalog.defense(offhand)] if host.player_form == 0 else Catalog.label(offhand) + " · Stored")
	if s.champion.active: lines.append("Champion Stone · %ds" % ceili(float(s.champion.timer)/65536.0/State.TICKS_PER_SECOND))
	if int(s.get("ancient_charges",0)) > 0: lines.append("Ancient Stone · %d charges" % int(s.ancient_charges))
	if s.get("dampened",false): lines.append("Dampen charm · used")
	return "\n".join(lines)
