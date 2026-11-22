extends RefCounted
## Named places, level exits and plot markers for the readable Atlas (owner direction 2026-11-08, AI_COMMS/ATLAS_READABLE_20261108.md:
## "the map needs to be understandable and have edges and have points of interest like location and plot points").
## Data only; the Atlas (museum_atlas.gd) draws it. Positions are Godot world x/z (native x, -native y). Evidence order for
## names: game text > hint book > longplay; the game's dialogue dump carries no place names, so the names come from the
## Prima hint book (the corresponding area chapter) and the Journal's own wording (my_journal.gd notes).
## A place shows once a region within `reveal` units of it has been explored (atlas_explored.gd: visited or seen), or when
## the area is "full" (older saves). A plot marker shows when its Journal note is discovered and its `done` quest path is
## still zero; Luther knows of the place from the note, so exploration is not required.

## Atlas titles for the areas whose host name is a preview label (museum_interface uses them when present).
const AREA_NAMES := {"L8_SJ": "Savage Jungle", "L12_CM": "Claw Mountains", "L13_RC": "Citadel of the Ruloi", "L10_DC": "Dracoid Cemetery",
	"L9_DR": "Dracoid Ruins", "L14_HT": "Huline Temple", "L16_CA": "City of the Ancients", "L1_DC": "Draracle’s Caverns", "L3_DH": "Draracle’s Museum",
	"L5_HC": "Hive Caves", "L17_HC": "Subterranean Caverns", "L19_BC": "Belial’s Laboratory", "L20_BB": "Birthing Chamber"}

static func area_title(area: String, fallback: String) -> String:
	return str(AREA_NAMES.get(area, fallback))

## Places and exits: id, name, position, reveal radius, kind ("place" or "exit"), `to` (destination area for exits), source.
const PLACES := {
	"L4_HJ": [
		{"id": "museum_road", "name": "Road from the Museum", "x": 353.0, "z": -4909.0, "reveal": 120.0, "kind": "exit", "to": "L3_DH",
			"source": "arrival region 3875 (jungle_review/jungle.json start); hint book ch.6 'After you arrive, there is only one way to go'"},
		{"id": "village_gate", "name": "Huline Village", "x": -1376.0, "z": -5249.0, "reveal": 160.0, "kind": "place",
			"source": "gate passage between the leaves (tests/fixtures/village_escape_route.json gate_to_inside); hint book ch.6 'the gate of the Huline Village'"},
		{"id": "tavern", "name": "Tavern", "x": -1630.0, "z": -3900.0, "reveal": 120.0, "kind": "place",
			"source": "village_escape_route confidante_to_tavern end; hint book ch.6 'visit the tavern last to see the village leader'"},
		{"id": "chief_hut", "name": "Chief's hut", "x": -1769.0, "z": -5464.0, "reveal": 100.0, "kind": "place",
			"source": "monastery_rooms.gd CHUT_PLACE; hint book ch.6 'the village leader', Journal 'the chief's hut'"},
		{"id": "thieves_den", "name": "Thieves' den", "x": -2420.0, "z": -5350.0, "reveal": 60.0, "kind": "place",
			"source": "thieves_den_rooms.gd ENTRANCE; owner F10 R28 'thieves guild is here'; hint book ch.6 'a local thief'. Small reveal radius: a hidden door"},
		{"id": "shaman", "name": "Shaman", "x": -1066.0, "z": -5676.0, "reveal": 120.0, "kind": "place",
			"source": "tests/fixtures/magic_shop_walk.json to_shop end; hint book ch.6 'visit the shaman and pick up as much as you can' (Journal: 'the magic seller')"},
		{"id": "armorer", "name": "Armorer's Glen", "x": -5310.0, "z": -610.0, "reveal": 140.0, "kind": "place",
			"source": "tests/fixtures/weapon_shop_walk.json to_shop end; hint book ch.6 'Go directly to the south to the Armorer's Glen'"},
		{"id": "monastery", "name": "Monastery", "x": 4264.0, "z": 2375.0, "reveal": 160.0, "kind": "place",
			"source": "monastery_rooms.gd ENTRANCE; hint book ch.6 'Now it is time to find your way to the Monastery'"},
		{"id": "wooden_bridge", "name": "Wooden bridge", "x": 1336.0, "z": 1207.0, "reveal": 160.0, "kind": "place",
			"source": "plank chain 213-214-210-212 (static_collision_L4_HJ.json); hint book ch.6 'a long wooden bridge on the way to the Monastery. DO NOT CROSS IT AS THE BEAST'"},
		{"id": "hive", "name": "Hive Caves", "x": -6490.0, "z": 4878.0, "reveal": 160.0, "kind": "exit", "to": "L5_HC",
			"source": "hive_routes/routes.json jungle polygon (region 2809); hint book ch.6 'Beyond the pool is the entrance to the Hive Caves'"},
		{"id": "hive_tunnel", "name": "Lizard tunnel", "x": -1179.0, "z": 2033.0, "reveal": 40.0, "kind": "exit", "to": "L5_HC",
			"source": "hive_routes/routes.json jungle_small polygon (region 2604); a small-form passage, small reveal radius"},
		{"id": "land_bridge", "name": "Land bridge", "x": 5874.0, "z": -3779.0, "reveal": 200.0, "kind": "exit", "to": "L8_SJ",
			"source": "jungle_exit_woman_source.json / jungle_bacatta_source.json positions; hint book ch.6 'the bridge across the major river to the north'"},
		{"id": "beehive_1", "name": "Beehive", "x": 2648.0, "z": -4316.0, "reveal": 90.0, "kind": "place",
			"source": "jungle_beehives_source.json; hint book ch.6 'when you see a bee hive, click on it to get some wax'"},
		{"id": "beehive_2", "name": "Beehive", "x": -1816.0, "z": -2660.0, "reveal": 90.0, "kind": "place", "source": "jungle_beehives_source.json"},
		{"id": "beehive_3", "name": "Beehive", "x": 862.0, "z": 2269.0, "reveal": 90.0, "kind": "place", "source": "jungle_beehives_source.json"},
	],
	## Darker (Savage) Jungle: names from the Prima hint book ch.8 "The Savage Jungle" and the L8 hosts' own wording.
	"L8_SJ": [
		{"id": "l8_entry", "name": "Back to the Huline Jungle", "x": -4523.0, "z": 1174.0, "reveal": 200.0, "kind": "exit", "to": "L4_HJ",
			"source": "arrival selector 1 region 2359 (act2_travel.json; l8_map 'start at the native arrival' (-4577,1168)); the land bridge from the Huline Jungle"},
		{"id": "clubhouse", "name": "Tribal Clubhouse", "x": -1791.0, "z": 1190.0, "reveal": 160.0, "kind": "place",
			"source": "l8_clubhouse.gd AIM / l8_clubhouse_walk end; hint book ch.8 'Huline Tribal Clubhouse ... near the entrance of the Huline Temple'; two skull torches flank it"},
		{"id": "temple_door", "name": "Huline Temple", "x": 758.0, "z": 2046.0, "reveal": 260.0, "kind": "exit", "to": "L14_HT",
			"source": "l8_temple_door.gd POINT / l8_journey TARGETS temple; act2_temple_tree loop: level 14 arrival 1"},
		{"id": "wild_village", "name": "Wild Village", "x": 676.0, "z": -4541.0, "reveal": 200.0, "kind": "place",
			"source": "l8_journey TARGETS village; hint book ch.8 'the Wild Village' (herbalist and shaman treehouses, the guard at the great tree)"},
		{"id": "great_tree", "name": "Great tree", "x": -1244.0, "z": -2466.0, "reveal": 160.0, "kind": "place",
			"source": "l8_tree_approach end / arrival selector 0 region 671; l8_tree.gd (five torches ring the platform); Journal 'the guard at the great tree'"},
		{"id": "cache_ladder", "name": "Cache ladder", "x": -1092.0, "z": -2627.0, "reveal": 80.0, "kind": "place",
			"source": "l8_cache_ladder.gd BASE (grok BG00a/BI08)"},
		{"id": "pit", "name": "Pit to the Dracoid Ruins", "x": 1245.0, "z": -1392.0, "reveal": 140.0, "kind": "exit", "to": "L9_DR",
			"source": "tests/fixtures/l8_pit_descent_walk.json pit; l8_pit_earned: level 9 arrival 1; hint book ch.9 'the pit in the Savage Jungle and access the ruins that way'"},
		{"id": "cemetery_gate", "name": "Dracoid Cemetery gate", "x": 3990.0, "z": -2550.0, "reveal": 180.0, "kind": "exit", "to": "L10_DC",
			"source": "arrival selector 2 region 911 (3961,-2440) and l8_first_departure_walk departure end (4026,-2667); hint book ch.8 'go to the Dracoid Cemetery ... with the key the Huline shaman gave Luther'"},
		{"id": "lake_shore", "name": "Lake shore", "x": 1730.0, "z": 2968.0, "reveal": 160.0, "kind": "place",
			"source": "arrival selector 7 region 3574 (l8_shore.gd, the wet way back from the Ruins); hint book ch.8 'asleep on the banks of the Savage Jungle lake'"},
		{"id": "tree_bridge", "name": "Tree bridge", "x": 5096.0, "z": 1916.0, "reveal": 140.0, "kind": "place",
			"source": "l8_tree_bridge.gd AT (grok Y02/BG); l8_larkhon_walk bank end (5130,1880)"},
		{"id": "larkhon_pass", "name": "Larkhon's pass", "x": 7321.0, "z": 1936.0, "reveal": 220.0, "kind": "exit", "to": "L12_CM",
			"source": "l8_larkhon.gd blocked regions 3277/3278 (closed passage level 12); arrival selector 4 region 3449; Journal 'The Larkhon guards the way to the Claw Mountains'"},
		{"id": "riverbank", "name": "Riverbank", "x": -4086.0, "z": -1596.0, "reveal": 160.0, "kind": "place",
			"source": "arrival selector 5 region 66 / l8_dawn.gd AIM (-4252,-1515); Journal 'Dawn on the river'"},
	],
	## Claw Mountains: names from the Prima hint book ch.11 ("The Claw Mountains"); positions from the L12 hosts and the pack's
	## arrival records (adjacent labels 'Savage Jungle', 'Citadel'). Godot z = -native y.
	"L12_CM": [
		{"id": "icy_gulch", "name": "Icy gulch (to the Savage Jungle)", "x": -347.0, "z": -5603.0, "reveal": 240.0, "kind": "exit", "to": "L8_SJ",
			"source": "arrival selector 1 region 735, adjacent label 'Savage Jungle'; hint book ch.11 'he finds himself at the bottom of an icy gulch'"},
		{"id": "citadel_gate", "name": "Citadel of the Ruloi", "x": 3684.0, "z": -19361.0, "reveal": 260.0, "kind": "exit", "to": "L13_RC",
			"source": "l12_citadel.gd entrance_aim; arrivals 0/2 regions 1948/3642, adjacent label 'Citadel'; hint book ch.11 'the special scene that shows Luther entering the citadel'"},
		{"id": "baccata_l12", "name": "Baccata", "x": 2858.0, "z": -18172.0, "reveal": 160.0, "kind": "place",
			"source": "l12_citadel.gd BACCATA; hint book ch.11 'follow the twisting ice tunnel until you meet Baccata'"},
		{"id": "kenneth", "name": "Kenneth", "x": 4599.0, "z": -14076.0, "reveal": 160.0, "kind": "place",
			"source": "l12_citadel.gd BODY; hint book ch.11 'When you find Kenneth, search him thoroughly'"},
		{"id": "ice_tunnel", "name": "Ice tunnel (Lizard)", "x": 3000.0, "z": -13600.0, "reveal": 140.0, "kind": "place",
			"source": "l12_crevasse.gd ENTRANCE; hint book ch.11 'find a crevasse in the edge of the glacier. Turn into the Lizard'"},
		{"id": "frozen_bow", "name": "Frozen bow", "x": 3381.0, "z": -14629.0, "reveal": 120.0, "kind": "place",
			"source": "l12_frozen_bow.gd POINT; hint book ch.11 'melt the blue bow'"},
		{"id": "river_niche", "name": "River niche", "x": -55.0, "z": -14164.0, "reveal": 140.0, "kind": "place",
			"source": "l12_niche_armor.gd POINT; hint book ch.11 'a little niche at river level ... one key item'"},
		{"id": "icy_river", "name": "Icy river", "x": 2018.0, "z": -11533.0, "reveal": 200.0, "kind": "place",
			"source": "l12_river_rafts.gd POINTS (the ice floes); hint book ch.11 'The other path leads to an icy river'"},
	],
	## Huline Temple: names from the hint book ch.12 and the L14 hosts; the chain walk tests/l14_temple_chain_a/b/c (BJ08) gave the
	## positions (Godot x, z). The temple is entered from the Savage Jungle (arrival 1, region 864) and left through the Chamber
	## of Voices (prop 170 -> City of the Ancients arrival 1).
	"L14_HT": [
		{"id": "temple_exit", "name": "Back to the Savage Jungle", "x": 2411.0, "z": -2300.0, "reveal": 240.0, "kind": "exit", "to": "L8_SJ",
			"source": "regions 863/4176 groups 1462/3836 (020100001c68 -> L8 selector 3); l14_shard_return_earned_test exit walk"},
		{"id": "chamber_of_voices", "name": "Chamber of Voices (to the City)", "x": 688.0, "z": 10873.0, "reveal": 260.0, "kind": "exit", "to": "L16_CA",
			"source": "l14_chamber_voices.gd DOORS; hint book ch.12 'put the dreamstone in the chalice ... the City of the Ancients to resurface'"},
		{"id": "ritual_chamber", "name": "Ritual chamber (the stone rectangle)", "x": 2400.0, "z": -3400.0, "reveal": 200.0, "kind": "place",
			"source": "l14_priest_body.gd SLAB area; hint book ch.12 'The floor around the stone rectangle should descend'"},
		{"id": "ceremony_post", "name": "Room of ceremony (the wooden post)", "x": 3043.0, "z": -5600.0, "reveal": 180.0, "kind": "place",
			"source": "l14_post_shard.gd POINT; hint book ch.12 'Grab the green shard located in a wooden post'"},
		{"id": "hanging_passage", "name": "Secret passage (left wall hanging)", "x": 2174.0, "z": -3795.0, "reveal": 120.0, "kind": "place",
			"source": "l14_hanging.gd; hint book ch.12 'Click on the wall hanging on the left'"},
		{"id": "spider_tunnel", "name": "Spider tunnel", "x": 1362.0, "z": -5435.0, "reveal": 200.0, "kind": "place",
			"source": "l14_spider_passage.gd (actor 68); hint book ch.12 'The spiders are coming!'"},
		{"id": "coffin_flute", "name": "Coffin (the flute)", "x": 1234.0, "z": -3600.0, "reveal": 140.0, "kind": "place",
			"source": "item77 on the lower floor; hint book ch.12 'found a flute in a coffin'"},
		{"id": "grinder", "name": "The two machines", "x": 3240.0, "z": -3615.0, "reveal": 180.0, "kind": "place",
			"source": "l14_machines.gd INSERT; hint book ch.12 'the conveyor belt on one of the two machines'"},
		{"id": "bedroom", "name": "Bedroom (red pillows)", "x": 2200.0, "z": -5271.0, "reveal": 160.0, "kind": "place",
			"source": "l14_bedroom.gd POINT; hint book ch.12 'the really plush bedroom with the big red pillows'"},
		{"id": "library", "name": "Library", "x": 2035.0, "z": -4360.0, "reveal": 180.0, "kind": "place",
			"source": "l14_library.gd barrier 1518; hint book ch.12 'A secret door should open into the library'"},
		{"id": "statue_niche", "name": "Statue niches", "x": 2691.0, "z": -3887.0, "reveal": 140.0, "kind": "place",
			"source": "l14_niche.gd POINT; hint book ch.12 'Place your statue in the empty niche'"},
		{"id": "shard_bowls", "name": "Floating bowls", "x": 1235.0, "z": -3453.0, "reveal": 160.0, "kind": "place",
			"source": "l14_shard_bowls.gd BOWLS 405/406; hint book ch.12 'the room with the two floating bowls'"},
		{"id": "spiral_stair", "name": "Spiral staircase", "x": 35.0, "z": -3433.0, "reveal": 200.0, "kind": "place",
			"source": "l14_spiral.gd; hint book ch.12 'Go up the spiral staircase and over the bridge'"},
		{"id": "three_doors", "name": "Three doors (maze, tilt, fire)", "x": 36.0, "z": -2230.0, "reveal": 200.0, "kind": "place",
			"source": "l14_trials.gd DOORS 90/89/88; hint book ch.12 'the room with three consecutive doors'"},
		{"id": "flute_slot", "name": "Angled slot (the flute)", "x": -114.0, "z": -1516.0, "reveal": 140.0, "kind": "place",
			"source": "l14_flute_slot.gd POINT; hint book ch.12 'See the angled slot? Insert the flute to cover the oil'"},
		{"id": "boulder_hall", "name": "Boulder hall", "x": 0.0, "z": 1000.0, "reveal": 220.0, "kind": "place",
			"source": "l14_trap_route.gd trigger; hint book ch.12 'a boulder will quite suddenly and firmly end Luther's life'"},
		{"id": "pedestals", "name": "Three pedestals", "x": 19.0, "z": 3590.0, "reveal": 180.0, "kind": "place",
			"source": "l14_idol_pedestals.gd CASES 85/86/87; hint book ch.12 'Place one statue on each pedestal'"},
		{"id": "hopper_platform", "name": "Wooden platform (the hoppers)", "x": 41.0, "z": 5919.0, "reveal": 220.0, "kind": "place",
			"source": "l14_hopper_platform.gd; hint book ch.12 'a funny square wooden platform at floor level'"},
		{"id": "faux_belial", "name": "The faux Belial", "x": 42.0, "z": 11200.0, "reveal": 240.0, "kind": "place",
			"source": "l14_belial.gd (actor 90); hint book ch.12 'you are about to face the faux-Belial'"},
	],
	## Citadel of the Ruloi: names from the hint book ch.11 citadel pages and the L13 hosts; adjacent labels 'Claw Mountains',
	## 'The Great Forge', 'Egg Chamber' (arrivals 0/1, 2, 3).
	"L13_RC": [
		{"id": "citadel_exit", "name": "Way out to the Claw Mountains", "x": -3391.0, "z": 6670.0, "reveal": 220.0, "kind": "exit", "to": "L12_CM",
			"source": "l13_exit_lock.gd SLOT beside arrivals 0/1 (regions 488/487, adjacent label 'Claw Mountains'); hint book ch.11 'Put the dreamstone in the dreamstone-shaped slot on the wall to open the exit'"},
		{"id": "great_forge", "name": "The Great Forge", "x": -2336.0, "z": 4192.0, "reveal": 160.0, "kind": "exit", "to": "",
			"source": "arrival selector 2 region 636, adjacent label 'The Great Forge' (destination level not traced here)"},
		{"id": "elevator", "name": "Elevator", "x": -4781.0, "z": 2981.0, "reveal": 160.0, "kind": "place",
			"source": "l13_elevator.gd BRAIN; hint book ch.11 'the entrance to the elevator'"},
		{"id": "egg_chamber", "name": "Egg chamber", "x": -3270.0, "z": 4210.0, "reveal": 160.0, "kind": "place",
			"source": "l13_eggs.gd EYE, regions 322-332 (arrival 3 label 'Egg Chamber'); hint book ch.11 'destroy their egg chamber'"},
		{"id": "dawn_prison", "name": "Dawn's prison", "x": -6251.0, "z": -3061.0, "reveal": 160.0, "kind": "place",
			"source": "l13_dawn_prison.gd PLATE; hint book ch.11 'Lighting these globes gives you access to Dawn's prison'"},
		{"id": "maidens_cell", "name": "Maidens' cell", "x": -4090.0, "z": -2833.0, "reveal": 160.0, "kind": "place",
			"source": "l13_prison.gd PLATE; hint book ch.11 'the maiden's cell'"},
		{"id": "altar", "name": "Altar", "x": -2343.0, "z": -4538.0, "reveal": 160.0, "kind": "place",
			"source": "l13_altar.gd ALTAR; hint book ch.11 'place it on the altar to the right of the dreamstone'"},
		{"id": "dreamstone", "name": "Dreamstone", "x": -2710.0, "z": -4183.0, "reveal": 160.0, "kind": "place",
			"source": "l13_altar.gd STONE; hint book ch.11 'NOW you can take the dreamstone'"},
		{"id": "teleporter", "name": "Teleporter", "x": -2347.0, "z": -3828.0, "reveal": 140.0, "kind": "place",
			"source": "l13_return_pad.gd PAD; hint book ch.11 'taking the teleporter back upstairs'"},
		{"id": "hive_lord", "name": "Hive Lord", "x": -5482.0, "z": -155.0, "reveal": 200.0, "kind": "place",
			"source": "l13_belial.gd WEB; Journal 'The Dreamstone is past the Hive Lord'; hint book ch.11 'the first of Belial's spawn'"},
	],
	## Remaining areas: Prima chapters5,7,9,10,13,14; exact host/record anchors are retained per place.
	"L1_DC": [
		{"id": "cave_entrance", "name": "Cave entrance", "x": -953.0, "z": -4302.0, "reveal": 140.0, "kind": "place",
			"source": "cave_normal_start_test native arrival; Prima hint book ch.5 Draracle caves"},
		{"id": "guard_captain", "name": "Gladstone guards", "x": -2057.0, "z": -4430.0, "reveal": 180.0, "kind": "place",
			"source": "cave_captain_source captain.position; Prima hint book ch.5 Draracle caves"},
		{"id": "cave_bridge", "name": "Bridge", "x": -67.0, "z": -16782.0, "reveal": 180.0, "kind": "place",
			"source": "river_deck/deck.json native_xyz of movable56; bridge_warning first deck; Prima hint book ch.5 Draracle caves"},
		{"id": "stone_pillars", "name": "Stone pillars", "x": -475.0, "z": -10950.0, "reveal": 160.0, "kind": "place",
			"source": "cave_pillar_trap_source statics1213-1218; Prima hint book ch.5 Draracle caves"},
		{"id": "old_orc", "name": "Old orc", "x": 1452.0, "z": -12257.0, "reveal": 140.0, "kind": "place",
			"source": "cave_old_orc_source position; Prima hint book ch.5 Draracle caves"},
		{"id": "side_chamber", "name": "Side chamber", "x": 399.0, "z": -11409.0, "reveal": 100.0, "kind": "place",
			"source": "cave_side_chamber_source props139-143; Prima hint book ch.5 Draracle caves"},
		{"id": "rapids", "name": "Streams and the circular pit", "x": 589.0, "z": -17374.0, "reveal": 200.0, "kind": "place",
			"source": "cave_rapids_trigger_source prop453 placement; Prima hint book ch.5 Draracle caves"},
		{"id": "draracle_halls", "name": "Draracle's halls", "x": -98.0, "z": -17741.0, "reveal": 180.0, "kind": "exit", "to": "L3_DH",
			"source": "cave_draracle_door_source movable74; cave chamber arrival -> Museum; Prima hint book ch.5 Draracle caves"},
	],
	"L3_DH": [
		{"id": "halls_arrival", "name": "Draracle's halls", "x": -3796.0, "z": -369.0, "reveal": 120.0, "kind": "place",
			"source": "museum_draracle_source arrival1 region1226; Prima hint book ch.5 Draracle halls"},
		{"id": "draracle", "name": "The Draracle", "x": -3670.0, "z": -373.0, "reveal": 100.0, "kind": "place",
			"source": "museum_draracle_source region1220; Prima hint book ch.5 Draracle halls / Museum"},
		{"id": "long_arm", "name": "Axe of the Long Arm", "x": -729.0, "z": -1132.0, "reveal": 100.0, "kind": "place",
			"source": "museum_long_arm_source pedestal.position; Prima hint book ch.5 Draracle halls / Museum"},
		{"id": "pilot_niche", "name": "Torch niche", "x": -1883.0, "z": -1011.0, "reveal": 80.0, "kind": "place",
			"source": "museum_torches_source pilot.position; Journal pilot_spark_before_plate"},
		{"id": "fire_crystal", "name": "Blue gem", "x": -1300.0, "z": -716.0, "reveal": 100.0, "kind": "place",
			"source": "museum_crystal_source item6 position; Prima hint book ch.5 Draracle halls / Museum"},
		{"id": "time_machine", "name": "Time machine", "x": 1332.0, "z": -663.0, "reveal": 140.0, "kind": "place",
			"source": "museum_hourglass prop226, hourglass.json position [1332,10,-663]; Prima hint book ch.5 Draracle halls / Museum"},
		{"id": "shining_path", "name": "Shining Path to the Huline Jungle", "x": -4058.0, "z": -1381.0, "reveal": 100.0, "kind": "exit", "to": "L4_HJ",
			"source": "museum_mirror_route APPROACH region1419; Prima hint book ch.5 Draracle halls / Museum"},
	],
	"L5_HC": [
		{"id": "jungle_exit", "name": "Way to the Huline Jungle", "x": 874.0, "z": -4583.0, "reveal": 160.0, "kind": "exit", "to": "L4_HJ",
			"source": "hive_routes/routes.json hive region460; Prima hint book ch.7 Hive Caves"},
		{"id": "lizard_exit", "name": "Lizard tunnel to the Jungle", "x": 3057.0, "z": -5813.0, "reveal": 65.0, "kind": "exit", "to": "L4_HJ",
			"source": "hive_routes/routes.json hive_small region835; Prima hint book ch.7 Hive Caves"},
		{"id": "executioner", "name": "Spider cavern", "x": -642.0, "z": -6462.0, "reveal": 180.0, "kind": "place",
			"source": "hive_executioner_live SPAWN; Prima hint book ch.7 Hive Caves"},
		{"id": "shalla", "name": "Shalla alcove", "x": -1133.0, "z": -8885.0, "reveal": 100.0, "kind": "place",
			"source": "hive_shalla_source native[-1133,8885,-235], Godot z=-native y; Prima hint book ch.7 Hive Caves"},
		{"id": "lift_pit", "name": "Lift pit", "x": -2305.0, "z": -7616.0, "reveal": 160.0, "kind": "place",
			"source": "hive_elevator PIT_LIP; Journal hive_flute_at_pit; Prima hint book ch.7 Hive Caves"},
		{"id": "flute_slot", "name": "Flute slot over the oil", "x": -1834.5, "z": -6456.5, "reveal": 75.0, "kind": "place",
			"source": "hive_flute_floor SLOT_POINT (lower floor); Prima hint book ch.7 Hive Caves"},
	],
	"L9_DR": [
		{"id": "pit_arrival", "name": "Pit from the Savage Jungle", "x": 81.0, "z": 603.0, "reveal": 180.0, "kind": "place",
			"source": "dragon_level area.json native arrival1; Prima hint book ch.10 Dracoid Ruins"},
		{"id": "cemetery_pad", "name": "Teleporter to the Dracoid Cemetery", "x": -3220.5, "z": -8228.0, "reveal": 160.0, "kind": "exit", "to": "L10_DC",
			"source": "act2_travel.json region:2299; Prima hint book ch.10 Dracoid Ruins"},
		{"id": "jungle_pad", "name": "Way to the Savage Jungle", "x": -3027.0, "z": -8381.0, "reveal": 160.0, "kind": "exit", "to": "L8_SJ",
			"source": "act2_travel.json region:2301; Prima hint book ch.10 Dracoid Ruins"},
		{"id": "jungle_lake", "name": "Waterway to the Savage Jungle", "x": 7316.5, "z": -1784.75, "reveal": 160.0, "kind": "exit", "to": "L8_SJ",
			"source": "act2_travel.json region:5340; Prima hint book ch.10 Dracoid Ruins"},
		{"id": "magic_bridge", "name": "Magic bridge", "x": -1193.0, "z": -1943.0, "reveal": 120.0, "kind": "place",
			"source": "l9_magic_bridge AIM; Prima hint book ch.10 Dracoid Ruins"},
		{"id": "mage_tower", "name": "Mage's tower", "x": -3661.0, "z": -863.0, "reveal": 180.0, "kind": "place",
			"source": "l9_tower_source orb1090.position; Prima hint book ch.10 Dracoid Ruins"},
		{"id": "walking_statue", "name": "Walking statue alcove", "x": 2559.65, "z": -5990.6, "reveal": 100.0, "kind": "place",
			"source": "l9_statue POLYGON; Journal l9_statue_human; Prima hint book ch.10 Dracoid Ruins"},
		{"id": "pyre", "name": "Funeral pyre", "x": 10884.83, "z": -12566.17, "reveal": 180.0, "kind": "place",
			"source": "l9_pyre ALTAR; Prima hint book ch.10 Dracoid Ruins"},
		{"id": "lifting_table", "name": "Lifting table and flood escape", "x": 2440.0, "z": -9260.0, "reveal": 140.0, "kind": "place",
			"source": "static_collision_L9_DR movable122 placement x/y; l9_escape; Journal l9_flood_late; Prima hint book ch.10 Dracoid Ruins"},
	],
	"L10_DC": [
		{"id": "jungle_gate", "name": "Gate to the Savage Jungle", "x": -151.5, "z": -66.0, "reveal": 180.0, "kind": "exit", "to": "L8_SJ",
			"source": "act2_travel.json region:0; Prima hint book ch.9 Dracoid Cemetery"},
		{"id": "ruins_pad", "name": "Teleporter to the Dracoid Ruins", "x": -646.25, "z": -953.25, "reveal": 130.0, "kind": "exit", "to": "L9_DR",
			"source": "act2_travel.json region:42; Prima hint book ch.9 Dracoid Cemetery"},
		{"id": "tomb_barrel", "name": "Barrel above the tomb", "x": -1440.0, "z": -1950.0, "reveal": 130.0, "kind": "place",
			"source": "l10_barrel START; Prima hint book ch.9 Dracoid Cemetery"},
		{"id": "tomb_oil", "name": "Tomb oil", "x": -1443.0, "z": -3307.0, "reveal": 120.0, "kind": "place",
			"source": "l10_oil AIM; Journal l10_tomb_oil; Prima hint book ch.9 Dracoid Cemetery"},
		{"id": "priest", "name": "Priest", "x": 3396.0, "z": -3010.0, "reveal": 140.0, "kind": "place",
			"source": "l10_priest AIM; Prima hint book ch.9 Dracoid Cemetery"},
		{"id": "emperor_door", "name": "Emperor's door", "x": 3207.0, "z": -2321.0, "reveal": 120.0, "kind": "place",
			"source": "l10_emperor_entry SLAB_AIM; Journal l10_emperor_door; Prima hint book ch.9 Dracoid Cemetery"},
		{"id": "emperor", "name": "Emperor's tomb", "x": 3205.0, "z": -1285.0, "reveal": 160.0, "kind": "place",
			"source": "l10_emperor AIMS.remains; Prima hint book ch.9 Dracoid Cemetery"},
	],
	"L16_CA": [
		{"id": "arrival_lift", "name": "Arrival lift", "x": -3848.0, "z": -1201.0, "reveal": 180.0, "kind": "place",
			"source": "l16_arrival_elevator PLATE; Prima hint book ch.13 City of the Ancients"},
		{"id": "dry_fountain", "name": "South avenue fountain", "x": 440.0, "z": 10438.0, "reveal": 180.0, "kind": "place",
			"source": "l16_dry_fountain ORB; Journal l16_south_fountain; Prima hint book ch.13 City of the Ancients"},
		{"id": "glass_pyramid", "name": "Glass pyramid and hourglass", "x": 2287.0, "z": -593.0, "reveal": 150.0, "kind": "place",
			"source": "l16_greenhouse PLATE/HOURGLASS; Journal l16_hourglass_leaf; Prima hint book ch.13 City of the Ancients"},
		{"id": "northwest_room", "name": "Northwest tower room", "x": -10442.0, "z": -1838.0, "reveal": 180.0, "kind": "place",
			"source": "l16_nw_traps FIRE_AT; Prima hint book ch.13 City of the Ancients"},
		{"id": "starry_tower", "name": "Starry tower", "x": 16082.0, "z": 3886.0, "reveal": 180.0, "kind": "place",
			"source": "l16_ne_tower ARRIVAL; Prima hint book ch.13 City of the Ancients"},
		{"id": "centre_tower", "name": "Central tower", "x": 5511.0, "z": 9888.0, "reveal": 180.0, "kind": "place",
			"source": "l16_centre_tower BARS; Journal l16_one_tower; Prima hint book ch.13 City of the Ancients"},
		{"id": "dragon_room", "name": "Dragon room", "x": 1625.0, "z": 4417.0, "reveal": 180.0, "kind": "place",
			"source": "l16_dragon_room DRAGON_AT; Prima hint book ch.13 City of the Ancients"},
		{"id": "cavern_door", "name": "Way to the Subterranean Caverns", "x": 2100.0, "z": 4296.0, "reveal": 130.0, "kind": "exit", "to": "L17_HC",
			"source": "act2_travel control74; l16_dragon_room PAD; Prima hint book ch.13 City of the Ancients"},
		{"id": "cavern_passage", "name": "Other cavern passage", "x": -7778.5, "z": 10788.25, "reveal": 130.0, "kind": "exit", "to": "L17_HC",
			"source": "act2_travel.json region:9822; native region exit, adjacent label Hive Caverns"},
	],
	"L17_HC": [
		{"id": "city_throat", "name": "Way back to the City of the Ancients", "x": 1439.0, "z": -7256.0, "reveal": 150.0, "kind": "exit", "to": "L16_CA",
			"source": "act2_travel movable50; l17_cavern_run CIRCLE_AT; Prima hint book ch.14 Subterranean Caverns"},
		{"id": "red_strands", "name": "Red strands in the west wall", "x": -5632.0, "z": 5803.5, "reveal": 100.0, "kind": "place",
			"source": "l17_beast_blade WEST_AT; Prima hint book ch.14 Subterranean Caverns"},
		{"id": "laboratory_exit", "name": "Way to Belial's Laboratory", "x": -5436.0, "z": 5803.0, "reveal": 130.0, "kind": "exit", "to": "L19_BC",
			"source": "act2_travel.json region:1312; Prima hint book ch.14 Subterranean Caverns"},
		{"id": "city_side", "name": "Side passage to the City", "x": 8335.25, "z": 2238.25, "reveal": 130.0, "kind": "exit", "to": "L16_CA",
			"source": "act2_travel.json region:1318; Prima hint book ch.14 Subterranean Caverns"},
	],
	"L19_BC": [
		{"id":"golden_door","name":"Golden Door","x":2550.0,"z":-854.0,"reveal":130.0,"kind":"place","source":"l19_drain_path DOOR_AT; earned drain -> heads chain"},
		{"id": "cavern_exit", "name": "Way to the Subterranean Caverns", "x": 157.25, "z": 307.0, "reveal": 150.0, "kind": "exit", "to": "L17_HC",
			"source": "act2_travel.json region:22; Prima hint book ch.14 Belial's Laboratory"},
		{"id": "baccata_horn", "name": "Baccata and Belial's Horn", "x": 120.0, "z": 525.0, "reveal": 130.0, "kind": "place",
			"source": "l19_belial_horn PIPE_AT; Journal l19_horn_keep; Prima hint book ch.14 Belial's Laboratory"},
		{"id": "bars_gutter", "name": "Bars and the gutter", "x": -344.0, "z": -1621.0, "reveal": 120.0, "kind": "place",
			"source": "l19_sewer_forms DOOR_AT/MOUTH; Prima hint book ch.14 Belial's Laboratory"},
		{"id": "guck_switches", "name": "Three switches over the guck", "x": -304.0, "z": -2124.0, "reveal": 140.0, "kind": "place",
			"source": "l19_sewer_forms AT_75; Journal l19_sewer_cross; Prima hint book ch.14 Belial's Laboratory"},
		{"id": "ghostly_heads", "name": "Summoning room: four ghostly heads", "x": 1240.0, "z": -1510.0, "reveal": 180.0, "kind": "place",
			"source": "l19_ghostly_heads AT_67/69/68/70; Journal l19_ghostly_heads; Prima hint book ch.14 Belial's Laboratory"},
		{"id": "white_circle", "name": "White circle by the red fountain", "x": 1240.0, "z": -1600.0, "reveal": 100.0, "kind": "place",
			"source": "l19_ghostly_heads CIRCLE_AT; Prima hint book ch.14 Belial's Laboratory"},
		{"id": "dawn_lift", "name": "Lift to Dawn", "x": 2616.0, "z": -774.0, "reveal": 120.0, "kind": "place",
			"source": "l19_dawn_elevator LEVER_X/LEVER_Z; Prima hint book ch.14 Belial's Laboratory"},
		{"id": "dawn", "name": "Dawn", "x": 2802.0, "z": -882.0, "reveal": 120.0, "kind": "place",
			"source": "l19_dawn_curse DAWN_AT; Journal l19_curse_mother; Prima hint book ch.14 Belial's Laboratory"},
		{"id": "birthing_exit", "name": "Way to the Birthing Chamber", "x": 3320.75, "z": -875.25, "reveal": 130.0, "kind": "exit", "to": "L20_BB",
			"source": "act2_travel.json region:2369; Prima hint book ch.14 Belial's Laboratory"},
	],
	"L20_BB": [
		{"id":"armory_ball","name":"Armory white ball","x":-2650.0,"z":-2924.0,"reveal":130.0,"kind":"place","source":"l20_armory AT_196"},
		{"id":"armory_fire","name":"Armory fireball","x":-3619.0,"z":-3431.0,"reveal":130.0,"kind":"place","source":"l20_armory AT_197"},
		{"id":"false_draracle","name":"False Draracle","x":-6921.0,"z":-4828.0,"reveal":160.0,"kind":"place","source":"l20_faux_draracle AT_46; earned armory -> false Draracle"},
		{"id":"crystal_key0","name":"First Crystal Key","x":-4636.0,"z":-4913.0,"reveal":100.0,"kind":"place","source":"l20_faux_draracle AT_0"},
		{"id":"crystal_key1","name":"Second Crystal Key","x":-3485.0,"z":-4749.0,"reveal":100.0,"kind":"place","source":"l20_faux_draracle AT_1"},
		{"id":"crystal_key2","name":"Third Crystal Key","x":-1043.0,"z":-3120.0,"reveal":100.0,"kind":"place","source":"l20_faux_draracle AT_2"},
		{"id": "mother_beast", "name": "Mother beast", "x": -1160.0, "z": -4258.0, "reveal": 180.0, "kind": "place",
			"source": "l19_dawn_curse MOTHER_AT (L20 owner); Journal l19_curse_mother; Prima hint book ch.14 Birthing Chamber / The End"},
		{"id": "pillar_path", "name": "Five pillars", "x": -3482.0, "z": -4299.0, "reveal": 180.0, "kind": "place",
			"source": "l20_pillars_scotia AT_59 (centre of five); Prima hint book ch.14 Birthing Chamber / The End"},
		{"id": "scotia", "name": "Scotia chamber", "x": -3539.0, "z": -3877.0, "reveal": 160.0, "kind": "place",
			"source": "l20_pillars_scotia SCOTIA_AT; Prima hint book ch.14 Birthing Chamber / The End"},
		{"id": "armory", "name": "Armory", "x": -1375.0, "z": -1719.0, "reveal": 160.0, "kind": "place",
			"source": "l20_armory AT_62; Prima hint book ch.14 Birthing Chamber / The End"},
		{"id": "belial", "name": "Belial", "x": -1238.0, "z": -3207.0, "reveal": 180.0, "kind": "place",
			"source": "l20_finale AT_75; Prima hint book ch.14 Birthing Chamber / The End"},
		{"id": "laboratory_return", "name": "Way to Belial's Laboratory", "x": -2612.0, "z": -4262.0, "reveal": 130.0, "kind": "exit", "to": "L19_BC",
			"source": "act2_travel.json region:1477; Prima hint book ch.14 Birthing Chamber / The End"},
	],

}

## Plot markers: Journal note id -> place id, short label, and the quest-state path whose nonzero value means the step is
## done (the marker clears). Paths index host.quest_state, down through mechanism_transaction slots ("slots", target,
## "committed": the Larkhon's chest, the serum mix, the shaman's leaf, Dawn's bracers); a missing path never clears.
const PLOT := {
	"L4_HJ": [
		{"note": "gate_closed_before_shalla", "place": "hive", "label": "Shalla's people are in the Hive", "done": ["jungle_village", "local24"]},
		{"note": "no_confidante_yet", "place": "armorer", "label": "Ask Kit'yara about Daniel", "done": ["thieves_den", "flags", "17"]},
		{"note": "password_known_den_unfound", "place": "thieves_den", "label": "The word opens a door in a west yard", "done": ["thieves_den", "room"]},
		{"note": "thohan_sword_broken", "place": "shaman", "label": "The magic seller might mend the sword", "done": ["weapon_shop", "flags", "253"]},
		{"note": "firestorm_wanted", "place": "armorer", "label": "Kit'yara trades Firestorm for a Power Orb", "done": ["weapon_shop", "flags", "253"]},
		{"note": "kelsrick_attacked_then_hut", "place": "chief_hut", "label": "The hut is barred to me", "done": []},
		{"note": "jungle_river_drown", "place": "wooden_bridge", "label": "The river pulls me under; cross by the bank", "done": []},
	],
	"L8_SJ": [
		{"note": "l8_see_temple_first", "place": "temple_door", "label": "Go here first: the village stays closed until then", "done": ["l8_journey", "temple_visited"]},
		{"note": "l8_show_guard_blade", "place": "wild_village", "label": "Show Daniel's blade to the guard", "done": ["l8_journey", "admitted"]},
		{"note": "l8_blade_for_daniel", "place": "l8_entry", "label": "Daniel's knife lies where we met", "done": ["l8_journey", "gift"], "values": ["recovered", "returned"]},
		{"note": "l8_shaman_cemetery_mark", "place": "wild_village", "label": "The shaman keeps the cemetery mark", "done": ["l8_journey", "key_awarded"]},
		{"note": "l8_cemetery_gate_east", "place": "cemetery_gate", "label": "The shaman's sigil opens this gate", "done": ["l10_main_gate", "open"]},
		{"note": "l8_not_initiated", "place": "wild_village", "label": "The shaman asks the tribe's fight and a silver leaf", "done": ["l8_tribe", "phase"], "values": ["complete", "departed"]},
		{"note": "tree_torches_unlit", "place": "great_tree", "label": "Light the five torches with a Spark", "done": ["l8_tree", "stone"]},
		{"note": "larkhon_must_sleep", "place": "larkhon_pass", "label": "The Larkhon blocks the way; it must sleep", "done": ["l8_larkhon", "slots", "larkhon:chest", "committed"]},
		{"note": "larkhon_join_tribe", "place": "wild_village", "label": "Only the shaman can make the Larkhon sleep", "done": ["l8_tribe", "phase"], "values": ["complete", "departed"]},
		{"note": "larkhon_ask_shaman", "place": "wild_village", "label": "The shaman may help for another Silverleaf", "done": ["l8_shaman_trade", "slots", "shaman:silverleaf", "committed"]},
		{"note": "larkhon_serum_needs_leaf", "place": "larkhon_pass", "label": "Mix the Serum with a Silverleaf", "done": ["l8_larkhon", "slots", "mix:serum", "committed"]},
		{"note": "larkhon_vapors_unactivated", "place": "larkhon_pass", "label": "Activate the Vapors, then the creature's chest", "done": ["l8_larkhon", "slots", "larkhon:chest", "committed"]},
		{"note": "l10_trees_need_dawn", "place": "riverbank", "label": "Dawn on the river wants the bracers", "done": ["l8_dawn", "slots", "dawn:bracers", "committed"]},
	],
	"L14_HT": [
		{"note": "l14_scale_bowls", "place": "shard_bowls", "label": "Both crystal shards, one in each bowl", "done": ["l14_shard_bowls", "opened"]},
		{"note": "l14_boulder_side", "place": "boulder_hall", "label": "Keep to the side strip; the centre kills", "done": []},
		{"note": "l14_hopper_bodies", "place": "hopper_platform", "label": "Five hopper bodies on the platform, then step on", "done": ["l14_hopper_platform", "lowered"]},
		{"note": "l14_chalice", "place": "chamber_of_voices", "label": "The chalice takes the Dreamstone for good", "done": ["l14_chamber_voices", "offered"]},
	],
	"L12_CM": [
		{"note": "l13_dreamstone_home", "place": "icy_gulch", "label": "Take the Dreamstone home to the Huline Temple", "done": ["l8_temple_door", "slots", "temple:entrance1198", "committed"]},
	],
	"L13_RC": [
		{"note": "l13_citadel_sealed", "place": "egg_chamber", "label": "A charged globe, then the upper halls", "done": ["l13_egg_door", "opened"]},
		{"note": "l13_dreamstone", "place": "dreamstone", "label": "Past the Hive Lord; Dawn's lock and the temple door take it", "done": ["l13_exit_lock", "slots", "citadel:exit_lock104", "committed"]},
	],
	"L3_DH": [
		{"note": "long_arm_before_passage", "place": "long_arm", "label": "Find a way back before taking the axe", "done": ["museum_key_locks", "loaded"], "contains": 78},
		{"note": "pilot_spark_before_plate", "place": "pilot_niche", "label": "The niche must wake the little flame first", "done": ["museum_torches", "pilot_state"], "values": [1, 2]},
	],
	"L5_HC": [
		{"note": "hive_flute_at_pit", "place": "lift_pit", "label": "The iron flute calls the lift", "done": ["hive_elevator", "played_flute"]},
	],
	"L9_DR": [
		{"note": "l9_statue_human", "place": "walking_statue", "label": "Follow the statue as a man; Dampen holds the shape", "done": ["l9_statue_walk", "fight_done"]},
		{"note": "l9_flood_late", "place": "lifting_table", "label": "Reach the lifting table before the water wins", "done": ["l9_escape", "escaped"]},
	],
	"L10_DC": [
		{"note": "l10_tomb_oil", "place": "tomb_oil", "label": "Use a stronger Spark or dragon blood from a safe distance", "done": ["l10_oil", "burned"]},
		{"note": "l10_emperor_door", "place": "emperor_door", "label": "The priest's urn, chapel ashes and ankh open this way", "done": ["l10_ankh", "slots", "emperor:slab66", "committed"]},
	],
	"L16_CA": [
		{"note": "l16_south_fountain", "place": "dry_fountain", "label": "Break the ball over the dry fountain", "done": ["l16_dry_fountain", "broken"]},
		{"note": "l16_hourglass_leaf", "place": "glass_pyramid", "label": "The glass pyramid wants a Silverleaf", "done": ["l16_greenhouse", "silverleaf"]},
		{"note": "l16_one_tower", "place": "centre_tower", "label": "Three more towers and a box through the disk lead to the centre", "done": ["l16_centre_tower", "conveyed"]},
	],
	"L17_HC": [
		{"note": "l17_cavern_exit", "place": "laboratory_exit", "label": "Follow the caverns to the exit", "done": ["l17_cavern_run", "exit_region"], "values": [1312, 1313]},
	],
	"L19_BC": [
		{"note": "l19_horn_keep", "place": "baccata_horn", "label": "Keep Belial's Horn", "done": ["l19_belial_horn", "taken"]},
		{"note": "l19_sewer_cross", "place": "guck_switches", "label": "Human at the bars, Lizard in the gutter, then three switches", "done": ["l19_sewer_forms", "switches"], "minimum_count": 3},
		{"note": "l19_ghostly_heads", "place": "ghostly_heads", "label": "Four level-one Mists; the body goes on the white circle", "done": ["l19_ghostly_heads", "dragged"]},
		{"note": "l19_curse_mother", "place": "dawn", "label": "Dawn explains how to send the curse into the mother", "done": ["l19_dawn_curse", "glob_entered"]},
	],
	"L20_BB": [
		{"note": "l19_curse_mother", "place": "mother_beast", "label": "Expel the curse into the mother at ancient-magic level five", "done": ["l19_dawn_curse", "glob_entered"]},
	],

}

static func places(area: String) -> Array:
	return PLACES.get(area, [])

static func plot(area: String) -> Array:
	return PLOT.get(area, [])

static func place(area: String, id: String) -> Dictionary:
	for row in places(area):
		if str(row.id) == id: return row
	return {}

## Nonzero/non-empty value at a saved owner path ([] never); values matches an enum, contains a loaded slot,
## minimum_count an array of completed switches. These are read-only presentation predicates.
static func step_done(quests: Variant, path: Array, values: Array = [], contains: Variant = null, minimum_count: int = -1) -> bool:
	if path.is_empty() or not quests is Dictionary: return false
	var node: Variant = quests
	for key in path:
		if node is Dictionary and (node as Dictionary).has(key): node = node[key]
		else: return false
	if contains != null: return node is Array and contains in node
	if minimum_count >= 0: return node is Array and node.size() >= minimum_count
	if not values.is_empty(): return node in values
	if node is bool: return node
	if node is int or node is float: return float(node) != 0.0
	if node is String: return node != ""
	return false

## Plot markers to draw: discovered Journal notes of this area whose step is not done.
static func active_plot(area: String, notes: Array, quests: Variant) -> Array:
	if area == "L16_CA" and quests is Dictionary:
		return city_road_plot(notes,quests)
	if area in ["L17_HC","L19_BC","L20_BB"] and quests is Dictionary:
		var directions:Script=load("res://scripts/lol2/act3_journal_hints.gd")
		var row:Dictionary=directions.ROAD[area][directions.road_stage(area,quests)]
		if row.when in notes:
			var next:=place(area,row.place)
			return [] if next.is_empty() else [{"note":row.when,"label":"Next: "+str(next.name),"x":next.x,"z":next.z,"place":next.id}]
	var out: Array = []
	for row in plot(area):
		if not (str(row.note) in notes): continue
		if step_done(quests, row.done, row.get("values", []), row.get("contains"), int(row.get("minimum_count", -1))): continue
		var at := place(area, str(row.place))
		if at.is_empty(): continue
		out.append({"note": row.note, "label": row.label, "x": at.x, "z": at.z, "place": at.id})
	return out

## One main-road plot pin replaces the unfinished central-tower itinerary.
static func city_road_plot(notes: Array, quests: Dictionary) -> Array:
	const Road = preload("res://scripts/lol2/l16_journal_hints.gd")
	var learned := false
	for id in notes:
		if str(id).begins_with("l16_road_") or id in ["l16_one_tower","l16_hourglass_leaf","l16_south_fountain"]: learned=true
	if not learned or bool(quests.get("l16_dragon_room",{}).get("pad_seen",false)): return []
	var stage := Road.road_stage(quests,notes)
	var at: Dictionary
	if stage==0: at=place("L16_CA","dry_fountain")
	elif stage in [1,2]: at=place("L16_CA","glass_pyramid")
	elif stage==3: at={"id":"canal","x":490.0,"z":9755.0}
	elif stage==4: at={"id":"oil_stair","x":-1273.0,"z":13725.0}
	elif stage in [5,6]: at={"id":"oil_court","x":-2201.0 if stage==5 else -2546.0,"z":12864.0}
	elif stage==7: at=place("L16_CA","dragon_room")
	else: at=place("L16_CA","cavern_door")
	return [{"note":Road.ROAD[stage].when,"label":Road.ROAD[stage].hint,"x":at.x,"z":at.z,"place":at.id}]
