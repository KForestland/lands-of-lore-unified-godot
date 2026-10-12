extends SceneTree
## Rashar room clicks through the host router: quip hotspots, sprite pickups,
## Rashar offers, save/load mid-line and knowledge mirrored for Julian's MOFF.
const State = preload("res://scripts/lol2/magic_shop_state.gd")
var failures := 0
func _initialize(): run.call_deferred()
func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: "+label)
func run():
	var path := "user://tests/magic_shop_hotspots_%d.json" % Time.get_ticks_usec()
	var jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle)
	await process_frame
	var shop = jungle.magic_shop
	shop.set_process(false)
	jungle.monastery.set_process(false)
	jungle.player.position = Vector3(-1066,32,-5676)
	shop._process(0.0)
	check(shop.active(),"room did not open")
	shop.advance(400.0) # Introduction; host deadline arms after line422.
	var s: Dictionary = shop.state()
	check(s.flags["53"] == 1 and s.timer_armed and not State.active(s),"introduction incomplete")
	# Rashar with an empty hand: host stop then re-arm (flag53 set, flag55 clear).
	s.timer_left = 3.0
	shop.click(Vector2i(300,200))
	check(s.timer_armed and s.timer_left == State.TIMER_SECONDS and not State.active(s),"empty-hand click did not re-arm")
	# Hotspot0 (150,6)-(495,151): one Luther quip per trigger bit per room load.
	check(shop.click(Vector2i(200,100)) and s.script.handler == "quip","hotspot quip did not start")
	await process_frame
	check(shop.view.clip.get("frames",-1) == 0 and not str(shop.view.clip.get("audio","")).is_empty(),"quip clip not audio-only")
	check(jungle.quicksave(path).is_empty(),"mid-quip save failed")
	shop.advance(2.0)
	check(not State.active(s),"quip did not finish")
	shop.click(Vector2i(200,100))
	check(not State.script_active(s),"second quip for hotspot0")
	check(jungle.quickload(path).is_empty() and shop.state().script.handler == "quip","mid-quip load lost the line")
	s = shop.state()
	shop.advance(2.0)
	# Sprite0 War cluster: flag51, sprite hidden, Luther 2:452. The inventory save
	# format does not admit MAGIC item IDs yet, so the grant is kept pending.
	check(shop.click(Vector2i(300,355)) and s.flags["51"] == 1 and not shop.sprite_nodes[0].visible,"war cluster pickup")
	check(s.pending_items == ["124-War cluster"] or "jungle:magic_shop:War_cluster" in jungle.carried_collected,"war cluster grant lost")
	shop.advance(2.0)
	check(s.timer_armed and s.timer_left > 0.0 and shop.active(),"deadline passed during the test")
	# Supplied held item only (its Act One producer is not integrated): the source
	# knowledge branch writes the global Julian's offer reads.
	jungle.carried_collected.append("12-Tho Broken")
	shop._refresh_hand()
	check(shop.offer_item("12-Tho Broken") and s.script.handler == "offer","knowledge offer did not start")
	shop.advance(60.0)
	check(s.globals.GV_KNOWLEDGE_OF_POWER_ORB == 1 and jungle.quest_state.monastery.globals.GV_KNOWLEDGE_OF_POWER_ORB == 1,"knowledge not mirrored")
	check("12-Tho Broken" in jungle.carried_collected,"knowledge branch consumed the dagger")
	jungle.carried_collected.erase("12-Tho Broken")
	shop.leave_room()
	check(not shop.active() and shop.state().flags["55"] == 1,"exit request")
	jungle.queue_free()
	await process_frame
	await process_frame
	if failures:
		push_error("FAIL: %d Rashar room hotspot checks" % failures)
		quit(1)
		return
	print("PASS: Rashar hotspot quips, sprite pickup, empty-hand timer re-arm, mid-line save/load and mirrored orb knowledge")
	quit()
