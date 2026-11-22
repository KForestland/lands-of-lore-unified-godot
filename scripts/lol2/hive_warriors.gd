extends Node3D
const PlayerHealth=preload("res://scripts/lol2/player_health.gd")
const PlayerCombat=preload("res://scripts/lol2/player_combat.gd")
## Stationary review guardians: source poses, authored health/reach/timing.
const CombatFeedback := preload("res://scripts/lol2/combat_feedback.gd")
const POSITIONS := [Vector3(-1052,-235,-8435),Vector3(-906,-235,-7308)]
const ACTORS := [32,34]
var _standalone_health:=PlayerHealth.MAXIMUM
var _pending_health:=false
func _enter_tree()->void:_player_health()
func _player_health()->Node:
	var owner:=PlayerHealth.owner_for(get_parent())
	if owner!=null and _pending_health:
		owner.set_value(_standalone_health);_pending_health=false
	return owner
var health:int:
	get:
		var owner:=_player_health()
		return owner.value() if owner!=null else _standalone_health
	set(v):
		var owner:=_player_health()
		if owner!=null:owner.set_value(v)
		else:_standalone_health=v;_pending_health=true
var enemies := [24,24]
var windups := [0.0,0.0]
var cooldown := 0.0
var bodies: Array[StaticBody3D] = []
var label: Label
func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(Image.load_from_file("res://assets/lol2/generated/hive_warriors/warrior.png"))
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.5
	material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	for i in range(2):
		var body := StaticBody3D.new()
		body.position = POSITIONS[i]
		body.collision_layer = 2
		body.set_meta("hive_guardian",i)
		add_child(body)
		bodies.append(body)
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = 14
		cylinder.height = 70
		shape.shape = cylinder
		shape.position.y = 35
		body.add_child(shape)
		var sprite := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(100,94) # Source selector0 state dimensions; static review pose.
		quad.center_offset.y = 47
		sprite.mesh = quad
		sprite.material_override = material
		body.add_child(sprite)
	# Parent finishes building the overlay after children are ready.
	call_deferred("attach_overlay")
func attach_overlay() -> void:
	label = Label.new()
	label.position = Vector2(16,16)
	var overlay := CanvasLayer.new()
	overlay.layer = 10
	add_child(overlay)
	overlay.add_child(label)
	# This label is the Hive's own prompt line at the populations' height (48 with the classic HUD): the shared
	# population line (target_status.gd) gives way while it shows text there.
	preload("res://scripts/lol2/target_status.gd").yield_to(get_parent(),label)
	get_parent().player.collision_mask |= 2
func input_enabled() -> bool:
	var magic=get_parent().get("starting_magic")
	return Input.mouse_mode==Input.MOUSE_MODE_CAPTURED or (magic!=null and magic.interface_request and magic.world_active())
func active() -> bool:
	var review = get_parent()
	var conversation = review.get_node("ConversationReview")
	return health > 0 and input_enabled() and not get_tree().paused and review.ready_for_review and not review.flying and not (conversation.started and not conversation.completed)
func clear_path(target: Vector3, mask: int = 1) -> bool:
	var review = get_parent()
	var query := PhysicsRayQueryParameters3D.create(review.camera.global_position,target,mask,[review.player.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
func strike() -> bool:
	if not active() or not PlayerCombat.cooldown_ready(cooldown): return false
	cooldown = PlayerCombat.COOLDOWN
	var review = get_parent()
	var hit := aimed_hit()
	if not hit.is_empty() and hit.collider.has_meta("hive_chasm"):
		return review.get_node("Chasm").activate()
	if not hit.is_empty() and hit.collider.has_meta("hive_return_actor"):
		var damage := PlayerCombat.damage(review,true,PlayerCombat.Armed.EQUIPMENT_WEAPON)
		var owner = hit.collider.get_meta("hive_population_owner")
		var id := str(hit.collider.get_meta("hive_return_actor"))
		if not owner.receive_damage(id,damage): return false
		return PlayerCombat.after_landed(review,owner,id,{"poison":false,"record":true,"net":true,"prism":true,"armed_rule":PlayerCombat.Armed.EQUIPMENT_WEAPON})
	if not hit.is_empty() and hit.collider.has_meta("hive_executioner_live"):
		var damage := PlayerCombat.damage(review,true,PlayerCombat.Armed.EQUIPMENT_WEAPON)
		return CombatFeedback.landed(review.executioner_live.receive_strike(damage))
	if not hit.is_empty() and hit.collider.has_meta("hive_hit_receiver"):
		return hit.collider.get_meta("hive_hit_receiver").receive_hit()
	if hit.is_empty() or not hit.collider.has_meta("hive_guardian"): return false
	var index := int(hit.collider.get_meta("hive_guardian"))
	if enemies[index] <= 0: return false
	# Unarmed review attacks remain usable without granting inventory items.
	var damage := PlayerCombat.damage(review,true,PlayerCombat.Armed.EQUIPMENT_WEAPON)
	return CombatFeedback.landed(damage_guardian(index,damage))

func damage_guardian(index: int, damage: int, effect: int = -1) -> bool:
	if index<0 or index>=enemies.size() or damage<=0 or enemies[index]<=0: return false
	var review = get_parent()
	if effect >= 0 and not review.starting_magic.award_hit(mini(int(enemies[index]),damage),effect,8): return false
	enemies[index] = maxi(0,enemies[index]-damage)
	if enemies[index] == 0:
		bodies[index].hide()
		bodies[index].collision_layer = 0
		windups[index] = 0.0
		# Authored defeat timing; native event10 routing itself is verified.
		review.get_node("QuestPillar").apply_actor_event(ACTORS[index],10)
	return true

func aimed_hit() -> Dictionary:
	var review = get_parent()
	return PlayerCombat.aim_ray(review,PlayerCombat.REACH_HIVE,7)
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if active() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			strike()
			get_viewport().set_input_as_handled()
## Normal play with the classic HUD (docs/classic-hud.md): health is shown by the cluster, so this label carries
## only target information and the Defeated prompt, as the other areas' population labels do.
func classic_hud() -> bool:
	var review = get_parent()
	return is_instance_valid(review.get("interface_hud")) and review.interface_hud.has_method("refresh_vitals") and not review.development_mode
func _process(delta: float) -> void:
	_process_body(delta)
	if is_instance_valid(label) and classic_hud(): label.text = label.text.trim_prefix(" · ")
func _process_body(delta: float) -> void:
	if not is_instance_valid(label): return
	# Normal play: below the top-centre coordinate overlay, at the other areas' population-label height.
	label.position.y = 125 if get_parent().development_mode else (48 if classic_hud() else 16)
	if classic_hud() and health > 0: label.text = ""
	else: label.text = "Health %d/%d · Left click: strike" % [health,PlayerHealth.MAXIMUM] if health > 0 else "Defeated · F9: load or R: retry guardians"
	if not active(): return
	cooldown = PlayerCombat.cooldown_tick(cooldown,delta)
	var review = get_parent()
	var hit := aimed_hit()
	if not hit.is_empty() and hit.collider.has_meta("hive_chasm"):
		label.text += " · Loose rock"
	if not hit.is_empty() and hit.collider.has_meta("hive_executioner_live"):
		label.text += " · Executioner %d/%d" % [review.executioner_live.state.health,review.executioner_live.MAX_HEALTH]
	if not hit.is_empty() and hit.collider.has_meta("hive_return_actor"):
		var id := str(hit.collider.get_meta("hive_return_actor"))
		label.text += " · "+hit.collider.get_meta("hive_population_owner").target_label(id)
	var chasm = review.get_node("Chasm")
	if chasm.activated and not chasm.completed and review.player.position.distance_to(chasm.trigger.position) < 250:
		label.text += " · Rocks collapsing"
	for i in range(2):
		if enemies[i] <= 0: continue
		var target: Vector3 = POSITIONS[i]+Vector3(0,40,0)
		var in_reach: bool = review.camera.global_position.distance_to(target) <= 70 and clear_path(target)
		if not in_reach:
			windups[i] = 0.0
			continue
		windups[i] += delta
		label.text += " · Guardian preparing to strike"
		if windups[i] >= 1.5:
			windups[i] = 0.0
			if not preload("res://scripts/lol2/player_form_rules.gd").protected(review): PlayerHealth.lose_host(review,preload("res://scripts/lol2/player_defense.gd").incoming(review,15))
			if health == 0:
				review.set_physics_process(false)
				return
func checkpoint() -> Dictionary:
	return {"health":health,"enemies":enemies.duplicate(),"windups":windups.duplicate(),"cooldown":cooldown,"pillar_elapsed":get_parent().get_node("QuestPillar").elapsed}
func restore(state: Dictionary) -> void:
	health = int(state.health)
	enemies = [int(state.enemies[0]),int(state.enemies[1])]
	windups = state.windups.duplicate()
	cooldown = state.cooldown
	for i in range(2):
		bodies[i].visible = enemies[i] > 0
		bodies[i].collision_layer = 2 if enemies[i] > 0 else 0
	var pillar = get_parent().get_node("QuestPillar")
	pillar.elapsed = float(state.pillar_elapsed)
	pillar.opened = pillar.elapsed == pillar.DURATION
	pillar.moving = (enemies[0] == 0 or enemies[1] == 0) and not pillar.opened
	pillar.blocker.collision_layer = 0 if pillar.moving or pillar.opened else 1
	pillar.position = pillar.origin.lerp(pillar.destination,pillar.elapsed/pillar.DURATION)
	if health == 0: get_parent().set_physics_process(false)
