extends RefCounted
## Thieves' Den DLL handlers (TEXT_/TCEL_/TDOOR_/TINT_.WOM) as ordered host effects, one function per native callback.
## Inputs (flags, globals, locals, the held item, the random draw) come from the caller; no host effect is applied
## here. Call sites: scripts/lol2/thieves_den_source.json (tools/verify_thieves_den_sources.py); the branch
## conditions below are read from the listings (docs/thieves-den.md, AI_COMMS THIEVES_DEN_DECODE_20261027.md).
## Effect vocabulary follows magic_shop.gd: movie/movie_flags (speaker, line, view[, bits]), set_flag/clear_flag,
## give_item, set_local, add_fighting_xp, room, load_room, place, set_heading, exit_room, take_held_item, damage,
## arm_timer/cancel_timer (no-ops here, see docs/DEVIATIONS.md), sfx/ambient_start/cursor_* (presentation).

# Setup geometry (inclusive rects): room -> [id, x1, y1, x2, y2].
const HOTSPOTS := {
	"TEXT":[[0,294,218,554,344]],
	"TCEL":[[0,0,247,162,378],[1,317,255,383,307],[2,250,170,381,302],[3,457,244,525,322],[4,0,160,100,215],[5,265,48,314,93],[6,161,196,207,319]],
	"TDOOR":[[0,147,109,471,399]],
	"TINT":[[0,72,63,207,246],[1,0,253,156,358],[2,212,172,249,215],[3,365,99,384,144],[4,388,91,455,141],[5,287,194,376,238],[6,395,199,436,246],[7,268,281,391,385]]}
## TINT THFSHAPE sprites: id -> x, y, frame (TINT 0x58E / 0x5B1).
const SPRITES := {0:[528,145,0],1:[588,100,1]}
## Actor rects: id, speaker, x, y, width, height (TDOOR 0x4A8, TINT 0x5C8).
const NPC := {"TINT":[0,31,340,114,120,110],"TDOOR":[0,31,0,0,5,5]}
## Placements: native x, y and the 0xF0 heading in degrees (TEXT leave 0x4F2/0x500; TINT tunnel 0x83B/0x849, 0x9A1/0x9AF).
const PLACE := {"TEXT":[-2377,5337,288],"TINT":[-2576,5154,180]}
const ROOMS := ["TEXT","TCEL","TDOOR","TINT"]
## Flags this chain reads or writes (host bit array; docs/thieves-den.md ledger).
const FLAGS := [17,18,19,20,21,22,23,24,25,27,28,29,30,31,63,131,132,133,270,271,308]
const ITEMS := ["123-Pois paint","93-Skull key","9-Firestorm"]
const TIMER_PRICE := 300
const TIMER_FIRESTORM := 600

static func _f(flags: Dictionary, id: int) -> bool:
	return int(flags.get(str(id),0)) != 0
static func _movie(speaker: int, line: int, format: int, presentation: int = 0) -> Array:
	return ["movie",speaker,line,format] if presentation == 0 else ["movie_flags",speaker,line,format,presentation]
static func _hotspots(room: String) -> Array:
	var effects: Array = []
	for h in HOTSPOTS[room]: effects.append(["hotspot"]+h)
	return effects

## ---- TEXT (index 44): the yard ---------------------------------------------------------------------------------------
static func text_setup() -> Dictionary:
	return {"handled":1,"effects":_hotspots("TEXT")}
## Callback 4 (0x4CB): the broken boards open the cellar.
static func text_click(hotspot: int) -> Dictionary:
	if hotspot != 0: return {"handled":0,"effects":[]}
	return {"handled":1,"effects":[["room","TCEL"],["exit_room"]]}
## Callback 8 (0x4E8): back into the village at the yard point.
static func text_leave() -> Dictionary:
	return {"handled":1,"effects":[["place",PLACE.TEXT[0],PLACE.TEXT[1]],["set_heading",PLACE.TEXT[2]],["exit_room"]]}
## Callback 9 (0x512).
static func text_first_update() -> Dictionary:
	return {"handled":1,"effects":[["ambient_start",351,150]]}

## ---- TCEL (index 16): the cellar -------------------------------------------------------------------------------------
## Callback 1 (0x47C): the CELLAR walk-in only while flag 17 is clear; 17 is cleared on both paths.
static func tcel_setup(flags: Dictionary) -> Dictionary:
	var effects: Array = []
	if not _f(flags,17): effects.append(["load_room","CELLAR",1,0])
	effects.append(["clear_flag",17])
	return {"handled":1,"effects":effects+_hotspots("TCEL")}
## Callback 4 (0x5C9): the door (2) and the front barrel's cue (0); every other hotspot does nothing.
static func tcel_click(hotspot: int) -> Dictionary:
	if hotspot == 2: return {"handled":1,"effects":[["room","TDOOR"],["exit_room"]]}
	if hotspot == 0: return {"handled":1,"effects":[_movie(2,26,24)]}
	return {"handled":0,"effects":[]}
## Callback 8 (0x601): leaving the cellar revives the dead door (270).
static func tcel_leave() -> Dictionary:
	return {"handled":0,"effects":[["clear_flag",270],["room","TEXT"],["exit_room"]]}

## ---- TDOOR (index 17): the slot door ---------------------------------------------------------------------------------
## Callback 1 (0x47C): the door rect, the 5x5 voice actor, dead flags 131..133 cleared.
static func tdoor_setup() -> Dictionary:
	return {"handled":1,"effects":_hotspots("TDOOR")+[["actor"]+NPC.TDOOR,["clear_flag",131],["clear_flag",132],["clear_flag",133]]}
## Callback 4 (0x4EA). `met` = L4_HJ local Met_Confidant; `draw` = random(0..3) (host 0xE8 with 3).
static func tdoor_click(hotspot: int, met: bool, kelsrick_dead: bool, flags: Dictionary, draw: int) -> Dictionary:
	if _f(flags,270): return {"handled":0,"effects":[]}
	if _f(flags,63) and not _f(flags,271): return {"handled":0,"effects":[["sfx",394,200]]}
	if kelsrick_dead and not _f(flags,28): return {"handled":0,"effects":[["sfx",394,200]]}
	if hotspot != 0: return {"handled":0,"effects":[]}
	var effects: Array = [["cursor_hide"]]
	if not met:
		effects.append_array([["set_flag",131],["set_flag",270],["sfx",388,150],_movie(31,475,6)])
		effects.append(_movie(1,509 if draw == 0 else (510 if draw == 1 else 511),6))
		effects.append_array([_movie(31,476,6),["cursor_show"]])
		return {"handled":1,"effects":effects}
	if not _f(flags,271): effects.append_array([["sfx",388,150],_movie(31,475,6),_movie(1,476,6)])
	effects.append_array([["set_flag",271],["room","TINT"],["exit_room"],["cursor_show"]])
	return {"handled":1,"effects":effects}
## Callback 8 (0x690).
static func tdoor_leave() -> Dictionary:
	return {"handled":1,"effects":[["set_flag",17],["room","TCEL"],["exit_room"]]}

## ---- TINT (index 18): Mauri's den ------------------------------------------------------------------------------------
static func visible_sprites(flags: Dictionary) -> Array:
	var ids: Array = []
	if not _f(flags,21): ids.append(0)
	if not _f(flags,22): ids.append(1)
	return ids
## Callback 1 (0x47C): hotspots, THFSHAPE sprites still present, Mauri and his idle (31,999,6).
static func tint_setup(flags: Dictionary) -> Dictionary:
	var effects: Array = _hotspots("TINT")+[["load_shapes","THFSHAPE"]]
	for id in visible_sprites(flags): effects.append(["show_sprite",id]+SPRITES[id])
	effects.append_array([["actor"]+NPC.TINT,["idle",31,999,6]])
	return {"handled":1,"effects":effects}
## Callback 3 (0x680): the Poison Paint bottle (0) and the Skull Key (1), free and once.
static func tint_sprite(sprite: int, flags: Dictionary) -> Dictionary:
	if sprite == 0 and not _f(flags,21):
		return {"handled":1,"effects":[["set_flag",21],_movie(31,502,6),["hide_sprite",0],["give_item","123-Pois paint",0],_movie(31,503,6)]}
	if sprite == 1 and not _f(flags,22):
		return {"handled":1,"effects":[["set_flag",22],["hide_sprite",1],_movie(2,29,24),["give_item","93-Skull key",0]]}
	return {"handled":0,"effects":[]}
## Callback 4 (0x73C). `alert` = GV_HULINE_ALERT == 1.
static func tint_hotspot(hotspot: int, flags: Dictionary, alert: bool) -> Dictionary:
	match hotspot:
		2, 3: return {"handled":1,"effects":[_movie(2,32,24)]}
		6, 7: return {"handled":1,"effects":[_movie(2,26,24)]}
		1: return {"handled":1,"effects":[_movie(31,993,6),_movie(31,506,6),_movie(31,992,6)]}
		5:
			if not _f(flags,20): return {"handled":1,"effects":[["set_flag",20],_movie(31,993,6),_movie(31,506,6),_movie(31,992,6)]}
			return {"handled":1,"effects":[_movie(31,993,6),_movie(31,994,6),["exit_room"]]}
		0:
			if _f(flags,18):
				return {"handled":1,"effects":[["cancel_timer"],["clear_flag",18],["load_room","TINTTRAN",1,0],["place",PLACE.TINT[0],PLACE.TINT[1]],["set_heading",PLACE.TINT[2]],["exit_room"]]}
			if alert: return {"handled":1,"effects":[_movie(31,554,6),_movie(31,556,6,0xA0),_movie(31,557,6),["set_flag",19],["arm_timer",TIMER_PRICE]]}
			if _f(flags,23): return {"handled":1,"effects":[_movie(31,519,6)]}
			return {"handled":1,"effects":[]}
	return {"handled":0,"effects":[]}
## Callback 5 (0x8E2): a click on Mauri's actor rect (id 0) with the hand item. `holding` = host 0x74, `magic` = the
## held definition's byte +0x43 bit 0 (host 0xA8), `state_bit` = host 0xA4 (always clear in the port).
static func tint_offer(npc: int, flags: Dictionary, holding: bool, magic: bool, state_bit: bool) -> Dictionary:
	if npc != 0: return {"handled":0,"effects":[]}
	if not holding: return {"handled":1,"effects":[_movie(31,504,6)]}
	if not magic:
		if state_bit: return {"handled":1,"effects":[_movie(31,504,6)]}
		return {"handled":0,"effects":[]}
	if state_bit: return {"handled":1,"effects":[_movie(31,504,6)]}
	var effects: Array = [["take_held_item"]]
	if _f(flags,19):
		effects.append_array([["cancel_timer"],["clear_flag",19],_movie(31,558,6),_movie(31,560,6,0x80),["load_room","TINTTRAN",1,0],["place",PLACE.TINT[0],PLACE.TINT[1]],["set_heading",PLACE.TINT[2]],["exit_room"]])
		return {"handled":1,"effects":effects}
	effects.append(_movie(31,505,6))
	return {"handled":1,"effects":effects}
## Callbacks 6/7 (0x9EB/0x9F4): any spell or weapon in the den; Damon kills Luther (host 0x5C with -1).
static func tint_attack(flags: Dictionary) -> Dictionary:
	if _f(flags,27): return {"handled":0,"effects":[]}
	return {"handled":1,"effects":[["set_flag",27],["cursor_hide"],_movie(31,993,6),_movie(31,994,6),["cursor_show"],["damage",-1],["exit_room"]]}
## Callback 8 (0xA58): the visit counter, then the pending price/tunnel lapse or the first farewell.
static func tint_leave(flags: Dictionary) -> Dictionary:
	var effects: Array = []
	for id in [23,24,25]:
		if not _f(flags,id):
			effects.append(["set_flag",id])
			break
	if _f(flags,19): effects.append_array([["clear_flag",19],_movie(31,561,6,0x80),_movie(31,562,6,0x80),_movie(31,563,6)])
	elif _f(flags,18): effects.append_array([["clear_flag",18],_movie(31,561,6,0x80),_movie(31,562,6,0x80),_movie(31,563,6)])
	elif not _f(flags,24): effects.append_array([_movie(31,507,6),_movie(31,508,6)])
	effects.append_array([["set_flag",17],["room","TCEL"],["exit_room"]])
	return {"handled":1,"effects":effects}
## The Firestorm scene (0xEB8 and 0x1106, identical).
static func _firestorm(flags: Dictionary, alert: bool) -> Array:
	var effects: Array = [_movie(31,600,6,0x80)]
	if not _f(flags,63):
		effects.append_array([_movie(31,601,6),["give_item","9-Firestorm",0],["set_local","Luther_has_firestorm",1]])
		if alert: effects.append(_movie(31,603,6,0xA0))
	if alert:
		effects.append(_movie(31,604,6,0x80))
		if not _f(flags,63): effects.append(_movie(31,605,6))
		effects.append_array([_movie(31,606,6),["arm_timer",TIMER_FIRESTORM],["set_flag",18]])
	effects.append_array([["set_flag",63],["add_fighting_xp",100],["set_flag",308]])
	return effects
## Callback 9 (0xB4A): the per-visit flags, then the visit's conversation.
static func tint_first_update(flags: Dictionary, kelsrick_dead: bool, alert: bool, met_kelsrick: bool) -> Dictionary:
	var effects: Array = [["clear_flag",20],["clear_flag",19],["clear_flag",18]]
	if not _f(flags,28):
		effects.append_array([["set_flag",28],_movie(1,401,10),_movie(31,477,6,0xE0),_movie(31,478,6,0x80),_movie(31,479,6),_movie(31,480,6),["set_flag",29]])
		effects.append_array([_movie(31,481,6),_movie(31,482,6),_movie(31,483,6),_movie(31,484,6,0x80),_movie(31,485,6,0x80),_movie(31,486,6,0x80),_movie(31,487,6),_movie(31,488,6),_movie(31,489,6),_movie(31,490,6),["set_flag",30]])
		effects.append_array([_movie(31,491,6,0xA0),_movie(31,492,6),_movie(31,495,6,0x80),_movie(31,496,6),_movie(31,497,6),["set_flag",31]])
		if met_kelsrick: effects.append_array([_movie(31,498,6,0xE0),_movie(31,499,6,0xA0)])
		effects.append_array([_movie(31,500,6),_movie(31,501,6)])
		return {"handled":1,"effects":effects}
	if _f(flags,25): return {"handled":0,"effects":effects}
	if _f(flags,24):
		if not kelsrick_dead and not alert:
			effects.append_array([_movie(31,525,6),_movie(31,526,6),_movie(31,527,6),["set_flag",17],["room","TCEL"],["exit_room"]])
			return {"handled":1,"effects":effects}
		if not kelsrick_dead and alert:
			effects.append_array([_movie(31,575,6,0x80),_movie(31,576,6,0x80),_movie(31,577,6)])
			return {"handled":1,"effects":effects}
		if _f(flags,308): return {"handled":0,"effects":effects}
		return {"handled":1,"effects":effects+_firestorm(flags,alert)}
	if not _f(flags,23): return {"handled":0,"effects":effects}
	if not kelsrick_dead and not alert:
		effects.append_array([_movie(31,515,6),_movie(31,516,6,0x80),_movie(31,517,6,0x80),_movie(31,518,6)])
		return {"handled":1,"effects":effects}
	if not kelsrick_dead and alert:
		effects.append_array([_movie(31,550,6),_movie(31,551,6),_movie(31,552,6,0x80),_movie(31,553,6,0x80)])
		return {"handled":1,"effects":effects}
	if _f(flags,308): return {"handled":0,"effects":effects}
	return {"handled":1,"effects":effects+_firestorm(flags,alert)}
## Callback 10 (0x122F): host timer expiry only cancels the timer.
static func tint_timer() -> Dictionary:
	return {"handled":0,"effects":[["cancel_timer"]]}

## Host click router (EFC74, as magic_shop.route): an actor rect wins; then each visible sprite in slot order gets
## message 3; then the first hit hotspot in slot order gets message 4. Canvas coordinates are 640x400.
static func route(room: String, point: Vector2i, flags: Dictionary, sprite_sizes: Dictionary) -> Array:
	var hits: Array = []
	if point.y < 0 or point.y >= 400 or point.x < 0 or point.x >= 640: return hits
	if NPC.has(room):
		var n: Array = NPC[room]
		if Rect2i(n[2],n[3],n[4],n[5]).has_point(point): return [["npc",n[0]]]
	if room == "TINT":
		for id in visible_sprites(flags):
			if not sprite_sizes.has(id): continue
			var s: Array = SPRITES[id]
			var size: Vector2i = sprite_sizes[id]
			if Rect2i(s[0],s[1],size.x,size.y).has_point(point): hits.append(["sprite",id])
	for h in HOTSPOTS[room]:
		if point.x >= h[1] and point.y >= h[2] and point.x <= h[3] and point.y <= h[4]:
			hits.append(["hotspot",h[0]])
			return hits
	return hits
