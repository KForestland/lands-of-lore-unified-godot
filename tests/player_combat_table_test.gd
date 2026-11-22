extends SceneTree
const Spies=preload("res://tests/foundation/strike_spies.gd")
var assertions := 0
func _initialize(): run.call_deferred()
func run():
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var host=Spies.Host.new();root.add_child(host)
	host.player=CharacterBody3D.new();host.add_child(host.player)
	host.camera=Camera3D.new();host.add_child(host.camera)
	host.starting_magic=Spies.Magic.new();host.add_child(host.starting_magic)
	host.item_effects=Spies.Bonus.new();host.add_child(host.item_effects)
	var target=CharacterBody3D.new();target.position=Vector3(0,-6,-40);host.add_child(target)
	host.roach=Spies.Roach.new();host.roach.host=host;host.roach.body=target;host.add_child(host.roach)
	var scripts=[Spies.Shared,Spies.Dino,Spies.CavePop,Spies.Roach,Spies.Prototype,Spies.Hive,Spies.Confidante,Spies.Dam,Spies.Bramble,Spies.Progression,Spies.Orc,Spies.Stalactite,Spies.Pillar]
	for site in 13:
		var spy=scripts[site].new()
		if site==4:
			spy.player=host.player;spy.camera=host.camera;spy.enemy=target
		elif site!=5: spy.host=host
		host.add_child(spy);spy.set_process(false);spy.set_physics_process(false)
		if site==2: spy.bodies={"spy":target}
		if site==3: spy.body=target
		if site==5:
			spy.target=StaticBody3D.new();spy.add_child(spy.target);spy.target.set_meta("hive_guardian",0)
		if site==6: spy.src=spy.State.source()
		if site==9: spy.struck_refs={"spy":[]}
		for form in 3:
			for armed in [false,true]:
				for bonus in [false,true]:
					host.player_form=form;host.equipped_item="museum:item11:Fine_Longsword" if armed else ""
					host.carried_inventory.equipped_item=host.equipped_item;host.item_effects.enabled=bonus
					var expected: int=12 if form==1 else 1 if form==2 else 8 if armed else 4
					if site in [0,1,5,6,7,9] and bonus: expected+=20
					var refused: bool=site>=6 and form==0 and not armed
					if site==4:
						spy.encounter.player_health=30;spy.encounter.enemy_health=24;spy.encounter.strike_remaining=0
						assert(spy._try_player_strike());assert(spy.encounter.enemy_health==16) # default 8, independent of equipment/form
					elif site==6:
						# Native threshold predicate proves the value actually delivered into State.hit.
						for threshold in [expected,expected+1]:
							spy.state=spy.State.initial(spy.src);spy.state.controls["112"].present=true
							spy.src.hits["112"].threshold=threshold;spy.strike()
							assert(bool(spy.state.controls["112"].struck)==(not refused and threshold==expected),"site7 threshold")
					else:
						spy.amount=-1
						if site in [0,1]: spy.strike_remaining=0
						if site==2: host.roach.model.strike_remaining=0
						if site==5: spy.cooldown=0
						if site==9: spy.struck_durability={"spy":1000};spy.strike_ref("spy")
						else: spy.strike()
						assert(spy.amount==(-1 if refused else expected),"site%d form%d armed%s bonus%s: %d != %d" % [site+1,form,armed,bonus,spy.amount,-1 if refused else expected])
					assertions+=1
		spy.free()
	host.free()
	print("PASS player_combat_table: ",assertions," actual-site form/weapon/bonus contracts (13 sites)")
	quit()
