extends SceneTree
## Cave→Museum completion packet validation. Sender: the real cave refuses to leave with a malformed
## packet, keeps its state and stays retryable, then leaves once the packet is valid. Receiver: the real
## Museum applies valid current/legacy packets in full (captain gear, fighting, magic, curse, form) and
## rejects malformed ones whole (no partial inventory/equipment). Supplied states; not an earned route.
## Preservation is compared synchronously after Museum _ready (before any clock advances) against the
## canonical forms the Museum itself applies (item_state.canonical, magic/fighting restore, curse snapshot).
const Cap=preload("res://scripts/lol2/cave_captain_items.gd")
const Museum=preload("res://scripts/lol2/museum_walkthrough.gd")
const Fighting=preload("res://scripts/lol2/player_fighting_transport.gd")
const Reward=preload("res://scripts/lol2/cave_melee_reward.gd")
const ItemState=preload("res://scripts/lol2/player_item_state.gd")
const Magic=preload("res://scripts/lol2/player_magic_state.gd")
const Curse=preload("res://scripts/lol2/player_curse.gd")
const Aloe=preload("res://scripts/lol2/cave_aloe.gd")
var failed:=false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok and not failed: failed=true;push_error(message);quit(1)
	return ok
func finish(node: Node) -> void:
	await RenderingServer.frame_post_draw
	node.queue_free()
	await process_frame
	await process_frame
	await physics_frame

## Non-default everywhere: captain gear, spent mana and earned magic XP, a pending Aloe heal with
## consumed harvest history, fighting XP and an active human-side curse warning.
func captain_packet() -> Dictionary:
	var effects:=ItemState.initial()
	effects.spent=[Aloe.item_id(791,1)]
	effects.aloe={"pending":5,"base":12,"clock":100,"fraction":0.25}
	effects.fraction=0.5
	var magic:=Magic.initial();magic.player.mana=13;magic.player.experience=40
	var curse:=Curse.initial()
	curse.merge({"phase":1,"previous":0,"target":2,"remaining":2.0,"duration":90.0,"seed":12345,"cave_triggered":true},true)
	return {"collected":["draracle/prop/1108/sample",Cap.SWORD,Cap.ARMOR,Aloe.item_id(791,2)],"item_effects":effects,
		"equipped_item":Cap.SWORD,"equipped_armor":Cap.ARMOR,"health":12,"curse":curse,
		"magic":magic,"player_form":0,"chamber_complete":true,
		"fighting":Fighting.pack(Reward.apply({},10,99,1).quests)}

## Transformed (form2) arrival mid-curse: gear stays owned/equipped but stored.
func transformed_packet() -> Dictionary:
	var p:=captain_packet()
	p.player_form=2
	p.curse.merge({"phase":2,"previous":0,"target":2,"remaining":45.5,"duration":90.0},true)
	return p

## Instantiate the Museum on `packet`; return its applied player state.
func enter(packet: Variant) -> Dictionary:
	set_meta("lol2_cave_completion",packet)
	var museum=load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	museum.introduction_state="complete"
	root.add_child(museum);current_scene=museum
	# Captured synchronously after _ready: no curse/healing clock has advanced yet.
	var result:={"ready":museum.get("champion_stones")!=null,"collected":museum.carried_collected.duplicate(),"weapon":museum.equipped_item,"armor":museum.equipped_armor,
		"health":museum.health,"form":museum.player_form,"fighting":museum.fighting_checkpoint.duplicate(true),"magic":museum.player_magic_checkpoint.duplicate(true),
		"item_effects":museum.item_effect_checkpoint.duplicate(true),"curse":museum.curse.snapshot()}
	for i in 3: await process_frame
	museum.set_physics_process(false)
	await finish(museum)
	remove_meta("lol2_cave_completion")
	# Museum exit stores a re-entry checkpoint that would override the next packet.
	remove_meta(Museum.CHECKPOINT_KEY)
	return result

func run() -> void:
	# Validator: positive current/legacy, negatives by class.
	var good:=captain_packet()
	if not check(Museum.validate_cave_transfer(good).is_empty() and Museum.validate_cave_transfer({"collected":[Cap.SWORD],"equipped_item":Cap.SWORD}).is_empty() and Museum.validate_cave_transfer({}).is_empty(),"Valid packets rejected"):return
	var bad_cases:={}
	for change in [["collected",["bogus:item"]],["collected",["jungle:item51:Th_Dagger"]],["collected",[Cap.SWORD,Cap.SWORD]],["collected","x"],
			["equipped_item",""],["equipped_armor",Cap.SWORD],["item_effects",{"version":1}],["magic",{"version":99}],["fighting",{"bogus":1}],
			["health",-5],["health",31],["health",2.5],["player_form",7],["curse","x"],["chamber_complete",false]]:
		var p:=captain_packet();p[change[0]]=change[1]
		if change[0]=="equipped_item": p.collected.erase(Cap.SWORD);p.equipped_item=Cap.SWORD   # unowned weapon
		bad_cases[str(change)]=p
	var spent:=captain_packet();spent.item_effects.spent=["jungle:item63:Cave_aloe"]
	bad_cases["jungle aloe consumed in cave"]=spent
	for name in bad_cases:
		if not check(not Museum.validate_cave_transfer(bad_cases[name]).is_empty(),"Accepted malformed packet "+name):return
	if not check(not Museum.validate_cave_transfer(null).is_empty() and not Museum.validate_cave_transfer([]).is_empty(),"Accepted non-dictionary packet"):return
	if not check(Magic.restore(good.magic).has("checkpoint") and Curse.valid(good.curse,0) and Curse.valid(transformed_packet().curse,2) and Museum.validate_cave_transfer(transformed_packet()).is_empty(),"Fixture states are not valid source states"):return
	# Receiver: valid packets retained in full, compared in the Museum's canonical forms.
	for p in [good,transformed_packet()]:
		var applied:=await enter(p)
		var expected:={"collected":p.collected,"weapon":Cap.SWORD,"armor":Cap.ARMOR,"health":12,"form":p.player_form,
			"fighting":Fighting.restore(p.fighting).checkpoint,"magic":Magic.restore(p.magic).checkpoint,"item_effects":ItemState.canonical(p.item_effects),"curse":p.curse}
		for key in expected:
			if not check(applied.ready and applied[key]==expected[key],"Valid transfer (form %d) lost %s: %s != %s" % [p.player_form,key,applied[key],expected[key]]):return
		if not check(applied.magic.player.mana==13 and applied.item_effects.aloe.pending==5 and Aloe.item_id(791,1) in applied.item_effects.spent and applied.curse.phase==p.curse.phase,"Non-default fields not distinguishable from defaults"):return
	var applied:Dictionary
	# Legacy no-optional-fields packet.
	applied=await enter({"collected":["cave:prop641:harvest1:Stalagmite"],"equipped_item":"cave:prop641:harvest1:Stalagmite"})
	if not check(applied.ready and applied.weapon=="cave:prop641:harvest1:Stalagmite" and applied.health==30 and applied.fighting.is_empty(),"Legacy transfer differs"):return
	# Malformed packets are rejected whole: nothing partial, Museum still initializes.
	for name in ["[\"collected\", [\"bogus:item\"]]","[\"equipped_item\", \"\"]","[\"magic\", { \"version\": 99 }]","[\"fighting\", { \"bogus\": 1 }]","[\"health\", -5]"]:
		if not check(bad_cases.has(name),"Missing case "+name):return
		applied=await enter(bad_cases[name])
		if not check(applied.ready and applied.collected.is_empty() and applied.weapon=="" and applied.armor=="" and applied.health==30 and applied.form==0,"Malformed packet partially applied ("+name+"): "+str(applied)):return
	# Sender: the real cave refuses a malformed packet and remains retryable.
	var cave=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(cave);current_scene=cave
	for i in range(600):
		await process_frame
		if cave.walkthrough_ready: break
	if not check(cave.walkthrough_ready,"Cave not ready"):return
	cave.set_physics_process(false)
	cave.equipped_item=Cap.SWORD   # supplied inconsistency: weapon not owned
	var before: Dictionary=cave._save_state()
	cave.chamber_arrival_state="complete"
	cave._enter_museum()
	# Compared synchronously: other cave encounters keep their own clocks running on later frames.
	var unchanged: bool=cave._save_state()==before
	await process_frame
	if not check(unchanged and current_scene==cave and is_instance_valid(cave) and not has_meta("lol2_cave_completion") and cave.chamber_arrival_state=="not_started" and cave.save_notice.begins_with("Cannot leave the cave:"),"Cave left or changed state with a malformed packet"):return
	# Corrected state leaves normally with a validated packet.
	cave.equipped_item=""
	cave.chamber_arrival_state="complete"
	cave._enter_museum()
	if not check(has_meta("lol2_cave_completion") and Museum.validate_cave_transfer(get_meta("lol2_cave_completion")).is_empty(),"Valid cave completion not handed over"):return
	for i in 6: await process_frame
	if not check(current_scene!=null and current_scene.scene_file_path=="res://scenes/lol2/museum_walkthrough.tscn","Museum not entered after retry"):return
	await finish(current_scene)
	remove_meta("lol2_cave_completion")
	if failed: return
	print("PASS cave→Museum transfer: validator %d malformed classes rejected, current captain/legacy packets applied in full, malformed packets rejected whole on Museum entry, real cave refuses to leave with an unowned weapon (state unchanged, retryable) and leaves after correction. Supplied states; not earned." % bad_cases.size())
	quit()
