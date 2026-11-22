extends Node
const PlayerHealth=preload("res://scripts/lol2/player_health.gd")
## Manual-backed starting spell access; costs/effects/range are provisional.
## Basic Spark uses a collision trace; maximum Spark saves its homing bolts.
const CombatFeedback := preload("res://scripts/lol2/combat_feedback.gd")
const Magic = preload("res://scripts/lol2/player_magic_state.gd")
const Forms = preload("res://scripts/lol2/player_form_rules.gd")
const SpellBook = preload("res://scripts/lol2/player_spell_book.gd")
const Teaching = preload("res://scripts/lol2/player_spell_teaching.gd")
var aura: Node3D
var host: Node3D
static func fresh_magic() -> Dictionary:
	var saved:=Magic.initial()
	saved.spellbook=SpellBook.initial()
	return saved
var fallback: Dictionary=fresh_magic()
var label: Label
var notice := ""
## Lead 2026-11-16 (owner Citadel F10 01-15-52, mana bar empty): a mana refusal says that mana comes back.
const LOW_MANA := "Not enough mana - it returns over time."
const SPARK_WANTED := "This answers only to Spark (1, then Q)."
var notice_time := 0.0
var refusal_serial := 0 # Transient UI response identity; never part of a save.
## Modern spell panel (top right). In normal play the classic HUD cluster (docs/classic-hud.md) replaces it: the
## Magic Button/Spell Bar select and cast; notices, aura and item status go to the shared hint and Character page.
var panel: VBoxContainer
var school_buttons: Dictionary = {}
func classic_hud_present() -> bool:
	var hud = host.get("interface_hud")
	return hud != null and is_instance_valid(hud) and hud.has_method("refresh_vitals") and not bool(host.get("development_mode"))
## Status for the classic HUD: the loaded spell, a recent cast notice, the aura timer and item status.
func status_lines() -> Array:
	var saved: Dictionary=magic_state()
	var lines: Array = []
	if protected(): lines.append("Lightning aura · %ds" % ceili(float(aura.state().timer)/65536.0/aura.State.TICKS_PER_SECOND))
	if host.get("item_effects")!=null and is_instance_valid(host.item_effects):
		var item_status: String=host.item_effects.status()
		if not item_status.is_empty(): lines.append(item_status)
	return lines
func notice_text() -> String: return notice if notice_time > 0 else ""
func _ready() -> void:
	host=get_parent()
	aura=preload("res://scripts/lol2/player_spark_aura.gd").new()
	add_child(aura)
	aura.setup(host,self)
	var layer:=CanvasLayer.new()
	layer.layer=8
	add_child(layer)
	panel=VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.position=Vector2(-290,16)
	panel.custom_minimum_size.x=275
	layer.add_child(panel)
	label=Label.new()
	panel.add_child(label)
	var row:=GridContainer.new()
	row.columns=2
	panel.add_child(row)
	for index in SpellBook.SCHOOLS.size():
		var school: String = SpellBook.SCHOOLS[index]
		var button:=Button.new()
		button.text="%s [%d]" % [SpellBook.NAMES[school],index+1]
		button.pressed.connect(select_spell.bind(school))
		row.add_child(button)
		school_buttons[school]=button
	refresh_spell_buttons()
	if host.has_meta("lol2_loaded_magic_clock"):
		host.remove_meta("lol2_loaded_magic_clock")
		finish_load()

## A successful load is a fresh input opportunity. Preserve the saved spell,
## mana and effect clocks; only the transient half-second cast lock is released.
func finish_load() -> void:
	var saved:Dictionary=magic_state()
	if float(saved.get("cooldown",0))<=0:return
	saved=saved.duplicate(true);saved.cooldown=0.0
	commit(saved)

func refresh_spell_buttons() -> void:
	var learned := SpellBook.schools(magic_state().get("spellbook",SpellBook.initial()))
	for school in school_buttons: school_buttons[school].visible = school in learned
func magic_state() -> Dictionary:
	if host.get("player_magic_checkpoint") != null:
		return host.player_magic_checkpoint if not host.player_magic_checkpoint.is_empty() else fallback
	return host.quest_state.get("player_magic_reward_state",fallback)
## Fighting progression (read-only, for the HUD) from whichever owner this host uses: the Museum's fighting packet, the
## Hive checkpoint, or the Cave/Jungle quests. Absent everywhere = the initial values (nothing earned yet).
func fighting_state() -> Dictionary:
	var saved = null
	if host.get("fighting_checkpoint") is Dictionary: saved = host.fighting_checkpoint.get("player_reward_state")
	elif host.get("player_reward_checkpoint") is Dictionary and not host.player_reward_checkpoint.is_empty(): saved = host.player_reward_checkpoint
	elif host.get("quest_state") is Dictionary: saved = host.quest_state.get("player_reward_state")
	if saved is Dictionary and saved.get("player") is Dictionary: return saved.player
	if initial_fighting.is_empty(): initial_fighting = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/player_progression_initial.json")).fighting
	return initial_fighting
var initial_fighting: Dictionary = {}
func commit(saved: Dictionary) -> void:
	if host.get("player_magic_checkpoint") != null: host.player_magic_checkpoint=saved
	else: host.quest_state.player_magic_reward_state=saved
func award_hit(loss: int, effect: int, scale: int) -> bool:
	var saved: Dictionary=magic_state()
	var reward := preload("res://scripts/lol2/hive_live_spell_reward.gd").apply(saved,int(saved.get("spark_reward_seed",324508639)),loss,effect,scale)
	if reward.has("error"):
		push_error(reward.error)
		return false
	reward.checkpoint.spark_reward_seed=reward.seed
	commit(reward.checkpoint)
	return true
func protected() -> bool:
	return is_instance_valid(aura) and aura.protected()
func cancel_aura() -> void:
	if is_instance_valid(aura): aura.cancel()
func health() -> int:return PlayerHealth.read_host(host)
func set_health(value: int) -> void:PlayerHealth.write_host(host,value)
## The locked fullscreen hut movie freezes every world consumer; only its owner keeps a clock (movie_world_active()).
func world_active() -> bool:
	if host.has_node("L8HulineSpeech") and host.get_node("L8HulineSpeech").input_locked():return false
	if host.has_node("L8Tribe") and host.get_node("L8Tribe").input_locked():return false
	if host.get("chief_hut")!=null and is_instance_valid(host.chief_hut) and host.chief_hut.input_locked(): return false
	# Kityara's conversation hold freezes the world the same way; only her owner keeps its clip clock.
	if host.get("kityara")!=null and is_instance_valid(host.kityara) and host.kityara.movement_locked(): return false
	return movie_world_active()
## A click on the HUD Magic Button (docs/classic-hud.md) happens in interface cursor mode, so only for that request
## the mouse-captured and interface-cursor gates are waived; every other world gate still refuses.
var interface_request := false
func cast_from_interface(charge: int = 1) -> bool:
	interface_request = true
	var ok := cast(charge)
	interface_request = false
	return ok
## world_active() without the hut-movie lock: the chief-hut owner's movie clock only.
func movie_world_active() -> bool:
	if get_tree().paused or host.flying or health()<=0 or (Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED and not interface_request): return false
	if get_tree().current_scene!=null and get_tree().current_scene!=host: return false
	if host.get("drowning") != null and host.drowning.dead: return false
	if host.get("guard_encounter")!=null and is_instance_valid(host.guard_encounter) and host.guard_encounter.input_locked():return false
	if host.get("guard_controls")!=null and is_instance_valid(host.guard_controls) and host.guard_controls.input_locked(): return false
	if host.get("captain")!=null and is_instance_valid(host.captain) and host.captain.intro_active(): return false
	if host.get("chamber_arrival_state") != null and host.chamber_arrival_state!="not_started": return false
	if host.get("walkthrough_ready") != null and not host.walkthrough_ready: return false
	if host.get("introduction_state") != null and host.introduction_state!="complete": return false
	if host.get("mirror_transition_pending") != null and host.mirror_transition_pending: return false
	for name in ["inventory","video_overlay"]:
		if host.get(name)!=null and is_instance_valid(host.get(name)): return false
	if host.get("interface_hud") != null and host.interface_hud.cursor_active and not interface_request: return false
	for name in ["monastery","magic_shop","weapon_shop","thieves_den","departure","exit_encounter","runes","village_dialogue","followup_dialogue"]:
		if host.get(name)!=null and is_instance_valid(host.get(name)) and host.get(name).active(): return false
	if host.has_node("ConversationReview"):
		var actor=host.get_node("ConversationReview")
		if actor.started and not actor.completed: return false
	return true
func available() -> bool:
	if preload("res://scripts/lol2/player_food_effects.gd").sleeping(host):return false
	if host.get("chief_hut")!=null and is_instance_valid(host.chief_hut) and host.chief_hut.input_locked(): return false
	if host.get("bacatta")!=null and is_instance_valid(host.bacatta) and host.bacatta.input_locked(): return false
	return world_active() and Forms.can_cast(host.player_form)
func select_spell(spell: String) -> void:
	if spell not in SpellBook.SCHOOLS or get_tree().paused: return
	if spell not in SpellBook.schools(magic_state().get("spellbook",SpellBook.initial())):
		refuse("That spell is not learned")
		return
	var saved: Dictionary=magic_state().duplicate(true)
	saved.spell=spell
	commit(saved)
## Acquisition/scroll owners use this same optional saved packet. Wiring those
## producers and actual quest receivers is the next G15 delivery, not implied here.
func learn_spell_group(group: String) -> bool:
	var saved := magic_state().duplicate(true)
	var learned := SpellBook.learn(saved.get("spellbook",SpellBook.initial()),group)
	if learned.is_empty(): return false
	saved.spellbook=learned
	commit(saved)
	refresh_spell_buttons()
	if is_instance_valid(host.get("interface_hud")): host.interface_hud.refresh_vitals()
	return true

## Inventory owners consume only when used=true. First use learns without a
## cast; subsequent use goes through the same cast() admission/receiver path.
## The loaded panel school is preserved. No item identities or pack writes here.
func use_stored_spell(school: String) -> Dictionary:
	if not SpellBook.STORED_CHARGES.has(school) or not available(): return {"used":false}
	var book: Dictionary = magic_state().get("spellbook",SpellBook.initial())
	if school not in SpellBook.schools(book):
		return {"used":learn_spell_group(school), "learned":true}
	return {"used":cast(int(SpellBook.STORED_CHARGES[school]),school), "learned":false}

## Scroll UI closes before this request. Reuse the existing HUD cursor waiver;
## inventory, pause, death, movies, form, target and cooldown guards all remain.
func use_stored_spell_from_interface(school: String) -> Dictionary:
	var previous := interface_request
	interface_request = true
	var result := use_stored_spell(school)
	interface_request = previous
	return result

## An item holds a single cast, not a permanent lesson. Receiver/cost/cooldown
## admission is shared with learned casts; the temporary authorization never saves.
var stored_charge_id := ""
func use_stored_charge_from_interface(school:String,charge:int)->bool:
	if not {"spark":3,"prism":3,"mists":1}.has(school) or charge!={"spark":3,"prism":3,"mists":1}[school]:return false
	if school=="prism":return refuse("The white globe holds a spell that does nothing here yet.")
	var previous:=interface_request
	interface_request=true
	stored_charge_id=school+str(charge)
	var used:=cast(charge,school)
	stored_charge_id=""
	interface_request=previous
	return used

## An admitting receiver must be a direct area child, with a read-only target/
## phase query and a commit that returns false without effects when refused.
func cast_quest_spell(saved: Dictionary, spell: String, charge: int) -> bool:
	var request := SpellBook.request(saved.get("spellbook",SpellBook.initial()),spell,charge,host.player_form)
	if stored_charge_id==spell+str(charge) and spell=="mists" and charge==1:
		request={"id":"mists1","cost":int(SpellBook.CASTS.mists1)}
	if request.has("error"): return refuse(request.error)
	var phase := int(host.curse.state.phase)
	if phase in [1,3] and charge in [3,5] and not (spell == "curse" and charge == 3): return refuse("The curse is changing your form")
	var free: bool = charge == 5 and int(host.item_effects.state().get("ancient_charges",0)) > 0
	var cost: int = 0 if free else int(request.cost)
	if int(saved.player.mana) < cost: return refuse(LOW_MANA)
	# Lead 2026-11-16 (owner Citadel F10): in the Citadel every cast receiver wants Spark; another spell aimed at one says so.
	if str(host.get("area_id")) == "L13_RC":
		var aimed: Dictionary = preload("res://scripts/lol2/player_combat.gd").aim_ray(host, 384.0, 3)
		if not aimed.is_empty() and aimed.collider is Object and (aimed.collider as Object).has_meta("spark_receiver"): return refuse(SPARK_WANTED)
	for receiver in host.get_children():
		if not receiver.has_method("accepts_player_spell") or not receiver.has_method("receive_player_spell"): continue
		if not receiver.accepts_player_spell(str(request.id)): continue
		if not receiver.receive_player_spell(str(request.id)):
			return refuse(str(receiver.spell_refusal()) if receiver.has_method("spell_refusal") else "The spell has no effect here")
		# A form receiver may cancel aura through the same magic owner. Retain
		# that update instead of restoring our pre-effect copy over it.
		var next := magic_state().duplicate(true)
		if free: host.item_effects.state().ancient_charges -= 1
		next.player.mana -= cost
		next.cooldown=0.5
		commit(next)
		if host.get("interface_hud") != null and is_instance_valid(host.interface_hud): host.interface_hud.cast_flash()
		notice="%s %s" % [SpellBook.NAMES[spell],str(request.id).trim_prefix(spell)]
		notice_time=0.8
		return true
	return refuse("The spell has no effect here")
## A refused cast says why on the hint line (playtest 2026-10-14: refusals were silent). World locks stay silent.
func refuse(text: String) -> bool:
	refusal_serial += 1
	notice=text
	notice_time=1.2
	return false
func dismiss_lesson_for_cast() -> void:
	var hud:Variant=host.get("interface_hud")
	if is_instance_valid(hud) and hud.has_method("dismiss_lesson_for_cast"):hud.dismiss_lesson_for_cast()
func cast(charge: int = 1, stored_school: String = "") -> bool:
	if charge not in [1,3,5]: return false
	if not stored_school.is_empty() and not SpellBook.STORED_CHARGES.has(stored_school): return false
	if world_active() and not Forms.can_cast(host.player_form):
		dismiss_lesson_for_cast()
		return refuse("This form cannot cast")
	if not available(): return false
	dismiss_lesson_for_cast()
	var saved: Dictionary=magic_state().duplicate(true)
	if float(saved.get("cooldown",0))>0: return refuse("Wait a moment before casting again")
	var spell: String=saved.get("spell","spark") if stored_school.is_empty() else stored_school
	if spell not in ["spark","heal"]: return cast_quest_spell(saved,spell,charge)
	var citadel_cure: bool = charge == 3 and spell == "heal" and host.has_node("L13Belial") and host.get_node("L13Belial").cure_available()
	if charge in [3,5] and ((spell != "spark" and not citadel_cure) or int(host.curse.state.phase) in [1,3]): return false
	if spell == "heal" and protected(): return refuse("Healing is blocked")
	var free: bool = charge == 5 and int(host.item_effects.state().get("ancient_charges",0)) > 0
	# Basic cost1 and highest cost10 retained. Level3 cost3/range768/damage16 are modern adapters.
	var cost:=0 if free else 10 if charge == 5 else 3 if charge == 3 else 2 if spell=="heal" else 1
	if spell=="heal" and health()>=PlayerHealth.limit_for(host) and not citadel_cure: return refuse("Already at full health")
	if saved.player.mana<cost: return refuse(LOW_MANA)
	if charge == 1 and spell=="spark" and host.get("rune_light")!=null and host.rune_light.target():
		# The existing prop transaction owns its single mana debit.
		if not host.rune_light.cast(): return false
		saved=magic_state().duplicate(true)
	else:
		saved.player.mana-=cost
		if spell=="heal":
			if citadel_cure:host.get_node("L13Belial").cure()
			set_health(mini(PlayerHealth.limit_for(host),health()+6))
			if host.get("interface_hud") != null and is_instance_valid(host.interface_hud) and host.interface_hud.has_method("heal_flash"): host.interface_hud.heal_flash()
		else:
			# Commit the debit before the hit can award magic progression.
			commit(saved)
			if charge == 5:
				if free: host.item_effects.state().ancient_charges -= 1
				aura.start()
			else: spark(charge)
			saved = magic_state().duplicate(true)
	saved.cooldown=0.5
	commit(saved)
	if host.get("interface_hud") != null and is_instance_valid(host.interface_hud) and host.interface_hud.has_method("cast_flash"): host.interface_hud.cast_flash()
	notice="Healing III — poison cured" if citadel_cure else "Lightning aura" if charge == 5 else "Level 3 Spark" if charge == 3 else "Healing" if spell=="heal" else "Spark"
	notice_time=0.8
	return true
func spark(charge: int = 1) -> void:
	var damage:=16 if charge==3 else 8
	var effect:=22 if charge==3 else 20
	var origin: Vector3=host.camera.global_position
	var end: Vector3=origin-host.camera.global_basis.z*(768 if charge==3 else 384)
	var query:=PhysicsRayQueryParameters3D.create(origin,end,11 if host.get("ambush_population")!=null else 3,[host.player.get_rid()])
	var hit: Dictionary=host.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		end=hit.position
		if host.get("roach")!=null and hit.collider==host.roach.body: host.roach.receive_magic(damage)
		elif hit.collider.has_meta("population_actor"): hit.collider.get_meta("population_owner").receive_damage(str(hit.collider.get_meta("population_actor")),damage,false,effect)
		elif hit.collider.has_meta("cave_population_actor"): hit.collider.get_meta("cave_population_owner").receive_damage(str(hit.collider.get_meta("cave_population_actor")),damage,false,effect)
		elif hit.collider.has_meta("hive_feeding_prop"): host.ambush_population.receive_feeding_spark()
		elif hit.collider.has_meta("hive_guardian"): host.get_node("Warriors").damage_guardian(int(hit.collider.get_meta("hive_guardian")),damage,effect)
		elif hit.collider.has_meta("hive_return_actor"): hit.collider.get_meta("hive_population_owner").receive_damage(str(hit.collider.get_meta("hive_return_actor")),damage,false,effect)
		elif hit.collider.has_meta("hive_executioner_live"): host.executioner_live.receive_strike(damage,false,effect)
		elif hit.collider.has_meta("chief_hut_rock"): hit.collider.get_meta("chief_hut_rock").receive_spark()
		elif hit.collider.has_meta("spark_receiver"):
			var receiver=hit.collider.get_meta("spark_receiver")
			if receiver.has_method("receive_spark_level"):receiver.receive_spark_level(charge)
			else:receiver.receive_spark()
	# Bolt plus white impact burst (combat_feedback.gd; presentation only, the ray above decides the hit).
	var start: Vector3=origin-host.camera.global_basis.z*24+host.camera.global_basis.x*3-Vector3(0,3,0)
	CombatFeedback.bolt(host,start,end,Color(0.55,0.8,1.0),0.2,0.5)
	CombatFeedback.projectile(host,start,end,Color(0.75,0.9,1.0),14.0 if not hit.is_empty() else 8.0)
## Fire crystal (handler2) fire effect, pool object 0x6E: modern adapter through the shared Spark ray and creature
## damage path (8 damage, non-melee reward path), without Spark-only receivers. Returns what the ray struck.
func crystal_fire() -> String:
	var origin: Vector3=host.camera.global_position
	var end: Vector3=origin-host.camera.global_basis.z*384
	var query:=PhysicsRayQueryParameters3D.create(origin,end,11 if host.get("ambush_population")!=null else 3,[host.player.get_rid()])
	var hit: Dictionary=host.get_world_3d().direct_space_state.intersect_ray(query)
	var struck := ""
	if host.get("rune_light")!=null and host.rune_light.ignite(): struck="rune_light"
	elif not hit.is_empty():
		end=hit.position
		if host.get("roach")!=null and hit.collider==host.roach.body: host.roach.receive_magic(8); struck="roach"
		elif hit.collider.has_meta("population_actor"): hit.collider.get_meta("population_owner").receive_damage(str(hit.collider.get_meta("population_actor")),8,false,20); struck=str(hit.collider.get_meta("population_actor"))
		elif hit.collider.has_meta("cave_population_actor"): hit.collider.get_meta("cave_population_owner").receive_damage(str(hit.collider.get_meta("cave_population_actor")),8,false,20); struck=str(hit.collider.get_meta("cave_population_actor"))
		elif hit.collider.has_meta("hive_guardian"): host.get_node("Warriors").damage_guardian(int(hit.collider.get_meta("hive_guardian")),8,20); struck="guardian"
		elif hit.collider.has_meta("hive_return_actor"): hit.collider.get_meta("hive_population_owner").receive_damage(str(hit.collider.get_meta("hive_return_actor")),8,false,20); struck=str(hit.collider.get_meta("hive_return_actor"))
		elif hit.collider.has_meta("hive_executioner_live"): host.executioner_live.receive_strike(8,false,20); struck="executioner"
	var start: Vector3=origin-host.camera.global_basis.z*24+host.camera.global_basis.x*3-Vector3(0,3,0)
	CombatFeedback.bolt(host,start,end,Color(1,0.45,0.1),0.2,0.5)
	CombatFeedback.projectile(host,start,end,Color(1,0.55,0.15),14.0 if not hit.is_empty() else 8.0)
	notice="Fire crystal"
	notice_time=0.8
	return struck
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode==KEY_E:
		if repeat_required_lesson():get_viewport().set_input_as_handled()
		return
	if event.keycode==KEY_1: select_spell("spark")
	elif event.keycode==KEY_2: select_spell("heal")
	elif event.keycode==KEY_3: select_spell("curse")
	elif event.keycode==KEY_4: select_spell("mists")
	elif event.keycode==KEY_5: select_spell("prism")
	elif event.keycode==KEY_6: select_spell("summon")
	elif event.keycode==KEY_Q: cast(5 if event.shift_pressed else 3 if event.ctrl_pressed else 1)
	else: return
	get_viewport().set_input_as_handled()
func show_required_lesson(lesson:Dictionary) -> void:
	preload("res://scripts/lol2/my_journal.gd").discover(host,str(lesson.journal))
	var hud:Variant=host.get("interface_hud")
	if is_instance_valid(hud) and hud.has_method("show_lesson"):hud.show_lesson(str(lesson.message))
	elif host.has_method("save_feedback"):host.save_feedback(str(lesson.message))
func repeat_required_lesson()->bool:
	if not available():return false
	var lessons:Array=Teaching.echo_candidates(host,magic_state().get("spellbook",SpellBook.initial()))
	if lessons.is_empty():return false
	show_required_lesson(lessons[0]);return true
func teach_required_casts() -> void:
	if not available():return
	var book:Dictionary=magic_state().get("spellbook",SpellBook.initial())
	var candidates:Array=Teaching.live_candidates(host,book)
	if candidates.is_empty():return
	var lesson:Dictionary=candidates[0]
	if learn_spell_group(str(lesson.group)):show_required_lesson(lesson)

func _process(delta: float) -> void:
	# Run after the host's synchronous load is complete, never against the old
	# world's partially replaced quests. New-game fallback already has a book.
	if not magic_state().has("spellbook"):
		var quests: Dictionary=host.quest_state if host.get("quest_state") is Dictionary else {}
		var effects: Variant=host.get("item_effects")
		var carried: Array=effects.carried() if is_instance_valid(effects) else []
		var spent: Array=effects.state().get("spent",[]) if is_instance_valid(effects) else []
		commit(Teaching.migrate(magic_state(),quests,preload("res://scripts/lol2/atlas_explored.gd").area_of(host),carried,spent))
	teach_required_casts()
	if world_active(): aura.advance(delta)
	else: aura.present(aura.state())
	var saved: Dictionary=magic_state()
	if world_active() and (float(saved.get("cooldown",0))>0 or saved.player.mana<saved.player.maximum):
		saved=saved.duplicate(true)
		if saved.has("cooldown"): saved.cooldown=maxf(0,float(saved.cooldown)-delta)
		if saved.player.mana<saved.player.maximum:
			var period: float=Magic.Progress.CAST_REGEN_SECONDS
			var elapsed: float=float(saved.get("regen_elapsed",0))+maxf(0,delta)
			saved.player.mana=mini(int(saved.player.maximum),int(saved.player.mana)+int(elapsed/period))
			saved.regen_elapsed=fmod(elapsed,period) if saved.player.mana<saved.player.maximum else 0.0
		commit(saved)
	notice_time=maxf(0,notice_time-delta)
	refresh_spell_buttons()
	if is_instance_valid(panel): panel.visible = not classic_hud_present()
	label.text="%s · Mana %d/%d\nQ — Cast%s" % [SpellBook.NAMES.get(saved.get("spell","spark"),"Spark"),saved.player.mana,saved.player.maximum," · "+notice if notice_time>0 else ""]

	if saved.get("spell","spark") == "spark": label.text += "\nCtrl+Q — Level 3 Spark · Shift+Q — Max Spark"
	if protected(): label.text += "\nLightning aura · %ds" % ceili(float(aura.state().timer)/65536.0/aura.State.TICKS_PER_SECOND)

	if host.get("item_effects")!=null and is_instance_valid(host.item_effects):
		var item_status: String=host.item_effects.status()
		if not item_status.is_empty(): label.text+="\n"+item_status
