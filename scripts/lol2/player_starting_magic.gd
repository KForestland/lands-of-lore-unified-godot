extends Node
## Manual-backed starting spell access; costs/effects/range are provisional.
## Basic Spark uses a collision trace; maximum Spark saves its homing bolts.
const Magic = preload("res://scripts/lol2/player_magic_state.gd")
const Forms = preload("res://scripts/lol2/player_form_rules.gd")
var aura: Node3D
var host: Node3D
var fallback: Dictionary=Magic.initial()
var label: Label
var notice := ""
var notice_time := 0.0
func _ready() -> void:
	host=get_parent()
	aura=preload("res://scripts/lol2/player_spark_aura.gd").new()
	add_child(aura)
	aura.setup(host,self)
	var layer:=CanvasLayer.new()
	layer.layer=8
	add_child(layer)
	var panel:=VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.position=Vector2(-290,16)
	panel.custom_minimum_size.x=275
	layer.add_child(panel)
	label=Label.new()
	panel.add_child(label)
	var row:=HBoxContainer.new()
	panel.add_child(row)
	for entry in [["Spark [1]","spark"],["Healing [2]","heal"]]:
		var button:=Button.new()
		button.text=entry[0]
		button.pressed.connect(select_spell.bind(entry[1]))
		row.add_child(button)
func magic_state() -> Dictionary:
	if host.get("player_magic_checkpoint") != null:
		return host.player_magic_checkpoint if not host.player_magic_checkpoint.is_empty() else fallback
	return host.quest_state.get("player_magic_reward_state",fallback)
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
func health() -> int:
	if host.get("roach") != null: return host.roach.model.player_health
	if host.has_node("Warriors"): return host.get_node("Warriors").health
	return int(host.get("health")) if host.get("health") != null else 30
func set_health(value: int) -> void:
	if host.get("roach") != null: host.roach.model.player_health=value
	elif host.has_node("Warriors"): host.get_node("Warriors").health=value
	else: host.health=value
## The locked fullscreen hut movie freezes every world consumer; only its owner keeps a clock (movie_world_active()).
func world_active() -> bool:
	if host.get("chief_hut")!=null and is_instance_valid(host.chief_hut) and host.chief_hut.input_locked(): return false
	# Kityara's conversation hold freezes the world the same way; only her owner keeps its clip clock.
	if host.get("kityara")!=null and is_instance_valid(host.kityara) and host.kityara.movement_locked(): return false
	return movie_world_active()
## world_active() without the hut-movie lock: the chief-hut owner's movie clock only.
func movie_world_active() -> bool:
	if get_tree().paused or host.flying or health()<=0 or Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED: return false
	if get_tree().current_scene!=null and get_tree().current_scene!=host: return false
	if host.get("drowning") != null and host.drowning.dead: return false
	if host.get("guard_controls")!=null and is_instance_valid(host.guard_controls) and host.guard_controls.input_locked(): return false
	if host.get("captain")!=null and is_instance_valid(host.captain) and host.captain.intro_active(): return false
	if host.get("chamber_arrival_state") != null and host.chamber_arrival_state!="not_started": return false
	if host.get("walkthrough_ready") != null and not host.walkthrough_ready: return false
	if host.get("introduction_state") != null and host.introduction_state!="complete": return false
	if host.get("mirror_transition_pending") != null and host.mirror_transition_pending: return false
	for name in ["inventory","video_overlay"]:
		if host.get(name)!=null and is_instance_valid(host.get(name)): return false
	if host.get("interface_hud") != null and host.interface_hud.cursor_active: return false
	for name in ["monastery","magic_shop","weapon_shop","departure","exit_encounter","runes","village_dialogue","followup_dialogue"]:
		if host.get(name)!=null and is_instance_valid(host.get(name)) and host.get(name).active(): return false
	if host.has_node("ConversationReview"):
		var actor=host.get_node("ConversationReview")
		if actor.started and not actor.completed: return false
	return true
func available() -> bool:
	if host.get("chief_hut")!=null and is_instance_valid(host.chief_hut) and host.chief_hut.input_locked(): return false
	if host.get("bacatta")!=null and is_instance_valid(host.bacatta) and host.bacatta.input_locked(): return false
	return world_active() and Forms.can_cast(host.player_form)
func select_spell(spell: String) -> void:
	if spell not in ["spark","heal"] or get_tree().paused: return
	var saved: Dictionary=magic_state().duplicate(true)
	saved.spell=spell
	commit(saved)
func cast(charge: int = 1) -> bool:
	if not available() or charge not in [1,5]: return false
	var saved: Dictionary=magic_state().duplicate(true)
	if float(saved.get("cooldown",0))>0: return false
	var spell: String=saved.get("spell","spark")
	if charge == 5 and (spell != "spark" or int(host.curse.state.phase) in [1,3]): return false
	if spell == "heal" and protected(): return false
	var free: bool = charge == 5 and int(host.item_effects.state().get("ancient_charges",0)) > 0
	# Existing basic Spark cost1; highest charge10 preserves the source10x ratio.
	var cost:=0 if free else 10 if charge == 5 else 2 if spell=="heal" else 1
	if saved.player.mana<cost or (spell=="heal" and health()>=30): return false
	if charge == 1 and spell=="spark" and host.get("rune_light")!=null and host.rune_light.target():
		# The existing prop transaction owns its single mana debit.
		if not host.rune_light.cast(): return false
		saved=magic_state().duplicate(true)
	else:
		saved.player.mana-=cost
		if spell=="heal": set_health(mini(30,health()+6))
		else:
			# Commit the debit before the hit can award magic progression.
			commit(saved)
			if charge == 5:
				if free: host.item_effects.state().ancient_charges -= 1
				aura.start()
			else: spark()
			saved = magic_state().duplicate(true)
	saved.cooldown=0.5
	commit(saved)
	notice="Lightning aura" if charge == 5 else "Healing" if spell=="heal" else "Spark"
	notice_time=0.8
	return true
func spark() -> void:
	var origin: Vector3=host.camera.global_position
	var end: Vector3=origin-host.camera.global_basis.z*384
	var query:=PhysicsRayQueryParameters3D.create(origin,end,11 if host.get("ambush_population")!=null else 3,[host.player.get_rid()])
	var hit: Dictionary=host.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		end=hit.position
		if host.get("roach")!=null and hit.collider==host.roach.body: host.roach.receive_magic(8)
		elif hit.collider.has_meta("population_actor"): hit.collider.get_meta("population_owner").receive_damage(str(hit.collider.get_meta("population_actor")),8,false,20)
		elif hit.collider.has_meta("cave_population_actor"): hit.collider.get_meta("cave_population_owner").receive_damage(str(hit.collider.get_meta("cave_population_actor")),8,false,20)
		elif hit.collider.has_meta("hive_feeding_prop"): host.ambush_population.receive_feeding_spark()
		elif hit.collider.has_meta("hive_guardian"): host.get_node("Warriors").damage_guardian(int(hit.collider.get_meta("hive_guardian")),8,20)
		elif hit.collider.has_meta("hive_return_actor"): hit.collider.get_meta("hive_population_owner").receive_damage(str(hit.collider.get_meta("hive_return_actor")),8,false,20)
		elif hit.collider.has_meta("hive_executioner_live"): host.executioner_live.receive_strike(8,false,20)
		elif hit.collider.has_meta("chief_hut_rock"): hit.collider.get_meta("chief_hut_rock").receive_spark()
		elif hit.collider.has_meta("spark_receiver"): hit.collider.get_meta("spark_receiver").receive_spark()
	var mesh:=ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(origin+host.camera.global_basis.x*4-Vector3(0,4,0))
	mesh.surface_add_vertex(end)
	mesh.surface_end()
	var visual:=MeshInstance3D.new()
	visual.mesh=mesh
	var material:=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=Color(0.3,0.7,1)
	visual.material_override=material
	host.add_child(visual)
	get_tree().create_timer(0.12).timeout.connect(visual.queue_free)
## Fire crystal (handler2) fire effect, pool object 0x6E: modern adapter through the shared Spark ray and creature
## damage path (8 damage, non-melee reward path), without Spark-only receivers. Returns what the ray struck.
func crystal_fire() -> String:
	var origin: Vector3=host.camera.global_position
	var end: Vector3=origin-host.camera.global_basis.z*384
	var query:=PhysicsRayQueryParameters3D.create(origin,end,11 if host.get("ambush_population")!=null else 3,[host.player.get_rid()])
	var hit: Dictionary=host.get_world_3d().direct_space_state.intersect_ray(query)
	var struck := ""
	if not hit.is_empty():
		end=hit.position
		if host.get("roach")!=null and hit.collider==host.roach.body: host.roach.receive_magic(8); struck="roach"
		elif hit.collider.has_meta("population_actor"): hit.collider.get_meta("population_owner").receive_damage(str(hit.collider.get_meta("population_actor")),8,false,20); struck=str(hit.collider.get_meta("population_actor"))
		elif hit.collider.has_meta("cave_population_actor"): hit.collider.get_meta("cave_population_owner").receive_damage(str(hit.collider.get_meta("cave_population_actor")),8,false,20); struck=str(hit.collider.get_meta("cave_population_actor"))
		elif hit.collider.has_meta("hive_guardian"): host.get_node("Warriors").damage_guardian(int(hit.collider.get_meta("hive_guardian")),8,20); struck="guardian"
		elif hit.collider.has_meta("hive_return_actor"): hit.collider.get_meta("hive_population_owner").receive_damage(str(hit.collider.get_meta("hive_return_actor")),8,false,20); struck=str(hit.collider.get_meta("hive_return_actor"))
		elif hit.collider.has_meta("hive_executioner_live"): host.executioner_live.receive_strike(8,false,20); struck="executioner"
	var mesh:=ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(origin+host.camera.global_basis.x*4-Vector3(0,4,0))
	mesh.surface_add_vertex(end)
	mesh.surface_end()
	var visual:=MeshInstance3D.new()
	visual.mesh=mesh
	var material:=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=Color(1,0.45,0.1)
	visual.material_override=material
	host.add_child(visual)
	get_tree().create_timer(0.12).timeout.connect(visual.queue_free)
	notice="Fire crystal"
	notice_time=0.8
	return struck
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode==KEY_1: select_spell("spark")
	elif event.keycode==KEY_2: select_spell("heal")
	elif event.keycode==KEY_Q: cast(5 if event.shift_pressed else 1)
	else: return
	get_viewport().set_input_as_handled()
func _process(delta: float) -> void:
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
	label.text="%s · Mana %d/%d\nQ — Cast%s" % ["Healing" if saved.get("spell","spark")=="heal" else "Spark",saved.player.mana,saved.player.maximum," · "+notice if notice_time>0 else ""]

	if saved.get("spell","spark") == "spark": label.text += "\nShift+Q — Max Spark"
	if protected(): label.text += "\nLightning aura · %ds" % ceili(float(aura.state().timer)/65536.0/aura.State.TICKS_PER_SECOND)

	if host.get("item_effects")!=null and is_instance_valid(host.item_effects):
		var item_status: String=host.item_effects.status()
		if not item_status.is_empty(): label.text+="\n"+item_status
