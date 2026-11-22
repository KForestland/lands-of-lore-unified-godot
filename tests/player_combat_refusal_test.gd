extends SceneTree
const Spies=preload("res://tests/foundation/strike_spies.gd")
func _initialize(): run.call_deferred()
func run():
	var museum=Spies.Museum.new();root.add_child(museum);museum.set_process(false);museum.set_physics_process(false)
	for form in 3:
		museum.player_form=form
		for item in ["","museum:item11:Fine_Longsword","hive:item0:Wax"]:
			museum.equipped_item=item;museum.carried_collected=[]
			assert(not museum.melee_ready())
			museum.carried_collected=[item]
			assert(museum.melee_ready()==(form==0 and item=="museum:item11:Fine_Longsword"))
	museum.free()
	var host=Spies.Host.new();root.add_child(host)
	host.starting_magic=Spies.Magic.new();host.add_child(host.starting_magic)
	host.act2_creatures=Spies.AimedDaniel.new();host.add_child(host.act2_creatures)
	var tribe=Spies.Tribe.new();tribe.host=host;host.add_child(tribe);tribe.set_physics_process(false)
	for form in 3:
		for melee in [true,false]:
			host.player_form=form
			var state=tribe.State.initial();state.phase="fight";state.daniel=600
			host.quest_state[tribe.State.KEY]=state
			assert(tribe.receive_strike(8,melee)==(form==0 and melee))
			assert(tribe.state().daniel==(592 if form==0 and melee else 600))
	host.free()
	# Creature/prop empty-hand refusal is tested through all 13 real entry points in table test.
	# Daniel's full world/form/melee gates remain exercised by l8_tribe_serum_earned_test.
	print("PASS player_combat_refusal: Museum carried weapon slot and Human requirement; Daniel Human-only melee unscaled 8")
	quit()
