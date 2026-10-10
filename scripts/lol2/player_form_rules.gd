extends RefCounted
## Manual printed42: neither cursed form uses weapons; Beast cannot cast;
## every successful morph restores health. Natural attack numbers are provisional.
static func can_use_weapon(form: int) -> bool:
	return form==0
static func can_cast(form: int) -> bool:
	return form in [0,2]
static func melee_damage(form: int, armed: bool) -> int:
	if form==1: return 12
	if form==2: return 1
	return 8 if armed else 4
static func protected(host: Node) -> bool:
	return host.get("starting_magic") != null and is_instance_valid(host.starting_magic) and host.starting_magic.protected()
static func on_morphed(host: Node) -> void:
	# All currently playable health models cap at30. Reward-stat health is a
	# separate unintegrated native model; do not silently overwrite its maximum.
	if host.get("roach") != null:
		host.roach.model.player_health=host.roach.Model.PLAYER_HEALTH
	elif host.has_node("Warriors"):
		host.get_node("Warriors").health=30
	elif host.get("health") != null:
		host.health=30
	if host.get("interface_hud") != null and is_instance_valid(host.interface_hud):
		host.interface_hud.refresh_equipment()
