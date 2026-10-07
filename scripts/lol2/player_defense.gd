extends RefCounted
## Bracers definition41 contributes5 to the native defense scalar. Existing
## playable health uses request*0.4; baseline defense0 and absent heading/mode
## modifiers remain explicit adapters. Evidence: gargoyle-bracers-checks.json.
const Catalog = preload("res://scripts/lol2/item_catalog.gd")
const BRACERS := "jungle:weapon_shop:Gargoyle_Bracers"
static func scalar(host: Node) -> int:
	if host == null or host.get("player_form") != 0: return 0
	var controller = host.get("item_effects")
	if controller == null: return 0
	var carried: Array=controller.carried()
	var value:=Catalog.defense(BRACERS) if controller.state().get("offhand", "") == BRACERS and BRACERS in carried else 0
	var armor=host.get("equipped_armor")
	if armor is String and armor in carried:
		if Catalog.slot(armor)=="armor":value+=Catalog.defense(armor)
	var weapon=host.get("equipped_item")
	if weapon is String and weapon in carried:
		if Catalog.slot(weapon)=="weapon":value+=Catalog.defense(weapon)
	return value
static func damage(request: int, defense: int = 0, signature: int = 36) -> int:
	if request <= 0: return 0
	if defense <= 0 or signature & 8: return maxi(1,roundi(request*0.4))
	var ratio: int = request*32768/maxi(1,defense) if defense>=request else 65536-defense*32768/request
	var fixed := request*ratio
	# Source physical signatures36/68 split then recombine two equal components.
	if signature & ~12:
		var component: int = fixed/2
		fixed = 2*(32768 if component == 0 else component)
	elif fixed == 0: fixed = 32768
	var native_loss: int = (fixed+65535)/65536
	return maxi(1,roundi(native_loss*0.4))
static func incoming(host: Node, request: int, signature: int = 36) -> int:
	return damage(request,scalar(host),signature)
