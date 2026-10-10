extends RefCounted
## Rashar MAGIC_.WOM dispatch handlers as ordered host effects. Each function
## mirrors one native handler (docs/magic-shop-callbacks-checks.json); flags and
## held/inventory/global values are supplied by the caller. No host effect is
## applied here.

# Host sprite/hotspot/NPC geometry from setup handler47C (inclusive rects).
const HOTSPOTS := [[0,150,6,495,151],[2,4,6,141,364],[3,507,2,629,242],[4,376,159,497,254],[1,180,211,250,264]]
const NPC := [0,30,260,160,100,130] # id, speaker, x, y, width, height
const SPRITES := {0:[285,345,0],1:[402,334,1],5:[385,289,5],4:[146,322,4],3:[165,322,3],2:[156,321,2]}
# Handler4 jump table at8F8: region -> F133C trigger bit.
const QUIP_BITS := [0x100,0x200,0x800,0x1000,0x400]
const QUIP_LINES := [56,21,27,58,26,33,57,20]
const TIMER_TICKS := 600
const INTRO := [[400,0],[401,0],[402,224],[403,0],[404,128],[405,128],[406,0],[407,160],[408,0],[409,0],[410,128],[411,0],[412,0],[413,128],[414,0],[416,0],[417,0],[418,0],[419,0],[420,0],[421,0],[422,0]]

static func _f(flags: Dictionary, id: int) -> bool:
	return int(flags.get(str(id),0)) != 0
static func _movie(speaker: int, line: int, format: int, presentation: int = 0) -> Array:
	return ["movie",speaker,line,format] if presentation == 0 else ["movie_flags",speaker,line,format,presentation]
static func _next_visit(flags: Dictionary) -> Array:
	for id in [55,56,57]:
		if not _f(flags,id): return [["set_flag",id]]
	return []

## Message1 (room load, 47C).
static func setup(flags: Dictionary) -> Dictionary:
	var effects: Array = [["load_room","MAGSHOP",1,1]]
	for h in HOTSPOTS: effects.append(["hotspot"]+h)
	effects.append(["load_shape","MAGSHAPE"])
	for id in visible_sprites(flags):
		effects.append(["show_sprite",id]+SPRITES[id])
	if not _f(flags,52):
		effects.append(["npc"]+NPC)
		effects.append(["start_loop",30,999,6])
	effects.append(["reset_trigger_bits"])
	return {"handled":1,"effects":effects}
static func visible_sprites(flags: Dictionary) -> Array:
	var ids: Array = []
	if not _f(flags,51): ids.append(0)
	if not _f(flags,50): ids.append(1)
	if not _f(flags,301): ids.append(5)
	if not _f(flags,46): ids.append(4)
	elif not _f(flags,47): ids.append(3)
	elif not _f(flags,48): ids.append(2)
	return ids

## Message2 (room unload, 66B).
static func unload(flags: Dictionary, ambient: int) -> Dictionary:
	var effects: Array = []
	if not _f(flags,51): effects.append(["hide_sprite",0])
	if not _f(flags,50): effects.append(["hide_sprite",1])
	if ambient > -1: effects.append(["ambient_stop",ambient,350])
	effects.append(["free_shape"])
	for id in [4,1,0,2,3]: effects.append(["remove_hotspot",id])
	return {"handled":1,"effects":effects}

## Message3 (click on a visible sprite, 6FA). Unhandled clicks fall through to hotspots.
static func pickup(sprite: int, flags: Dictionary) -> Dictionary:
	var dead := _f(flags,52)
	if sprite == 0 and not _f(flags,51):
		return {"handled":1,"effects":[["set_flag",51],["hide_sprite",0],["give_item","124-War cluster",0],_movie(2,452,6)]}
	if sprite == 1 and not _f(flags,50):
		return {"handled":1,"effects":[["set_flag",50],["hide_sprite",1],["give_item","131-Mana foil",0],_movie(2,29,24)]}
	if sprite == 5 and not _f(flags,301):
		return {"handled":1,"effects":[["set_flag",301],["hide_sprite",5],["give_item","138-SS5",0]]}
	if not _f(flags,46):
		return {"handled":1,"effects":[["set_flag",46],["hide_sprite",4],["show_sprite",3]+SPRITES[3],["give_item","57a-Fire crstl",4],_movie(2,30,24) if dead else _movie(2,451,6)]}
	if not _f(flags,47):
		var effects: Array = [["set_flag",47],["hide_sprite",3],["show_sprite",2]+SPRITES[2],["give_item","57a-Fire crstl",4]]
		if not dead: effects.append(_movie(2,453,6))
		return {"handled":1,"effects":effects}
	if not _f(flags,48):
		return {"handled":1,"effects":[["set_flag",48],["hide_sprite",2],["give_item","57a-Fire crstl",4]]}
	return {"handled":0,"effects":[]}

## Message4 (click in hotspot rect, 90C).
static func region(id: int) -> Dictionary:
	if id < 0 or id > 4: return {"handled":0,"effects":[]}
	return {"handled":1,"effects":[["quip",QUIP_BITS[id]]]}

## Host F133C: once per trigger bit per room load; shared eight-line history byte.
static func quip_plan(mask: int, bit: int, draws: Array) -> Dictionary:
	if mask & bit: return {"mask":mask,"line":0,"draws_used":0}
	mask |= bit
	if mask & 255 == 255: mask &= ~255
	for index in draws.size():
		var choice := int(draws[index])
		if choice < 0 or choice > 7: return {"error":"Invalid response draw."}
		if mask & (1<<choice): continue
		return {"mask":mask|(1<<choice),"line":QUIP_LINES[choice],"draws_used":index+1}
	return {"error":"No unused response draw."}

## Message5 (click on Rashar's NPC rect, 960) with the hand item's source name.
static func offer(held: String, flags: Dictionary, has_broken: bool, soul: int) -> Dictionary:
	var effects: Array = [["stop_timer"]]
	if _f(flags,52): return {"handled":0,"effects":effects}
	if held == "12-Tho Broken" and _f(flags,49):
		effects.append_array([["cursor_hide"],["consume_held"],["award_fighting",100],_movie(30,443,6),_movie(30,444,6),["give_item","21-Tho fixed",0],["cursor_show"]])
		return {"handled":1,"effects":effects}
	if held == "12-Tho Broken":
		effects.append_array([_movie(30,423,6,160),_movie(30,424,6,128),_movie(30,425,6),_movie(30,426,6),_movie(30,427,6),["set_global","GV_KNOWLEDGE_OF_POWER_ORB",1],_movie(30,428,6)])
		return {"handled":1,"effects":effects}
	if held == "10-Th Dagger":
		effects.append_array([["cursor_hide"],["consume_held"],_movie(30,433,6),["give_item","28-Dag Light",0],_movie(30,434,6),["cursor_show"]])
		return {"handled":1,"effects":effects}
	if held == "83-Power orb" and not _f(flags,49) and has_broken:
		effects.append_array([["set_flag",49],["consume_held"],["set_global","GV_LUTHERS_SOUL",soul+1],_movie(30,442,6)])
		return {"handled":1,"effects":effects}
	if not held.is_empty():
		effects.append(_movie(30,429,6))
		return {"handled":1,"effects":effects}
	if not _f(flags,53): return {"handled":1,"effects":effects}
	# Native EBX is always1 here; only the flag55 test gates the re-arm.
	if not _f(flags,55): effects.append(["arm_timer",TIMER_TICKS])
	return {"handled":0,"effects":effects}

## Messages6/7 (BAE/BBB): Rashar killed. Player actions behind them are unbound.
static func killed(message: int, flags: Dictionary, soul: int) -> Dictionary:
	if _f(flags,52): return {"handled":0,"effects":[]}
	var effects: Array = [["set_flag",52],["set_global","GV_LUTHERS_SOUL",soul-1],_movie(30,432,6,192),_movie(2,432,6,192),["stop_npc",0]]
	return {"handled":1 if message == 7 else 0,"effects":effects}

## Message8 (exit request, C56).
static func exit_request(flags: Dictionary) -> Dictionary:
	return {"handled":0,"effects":_next_visit(flags)+[["exit_room"]]}

## Message10 (timer deadline reached, F5F). The host has already stopped the timer.
static func timer_expired(flags: Dictionary) -> Dictionary:
	var effects: Array = [["stop_timer"]]
	if _f(flags,52): return {"handled":0,"effects":effects}
	effects.append_array([["cursor_hide"],["stop_loop",30,999,6],_movie(30,430,6),_movie(30,431,6,128)])
	effects.append_array(_next_visit(flags))
	effects.append_array([["cursor_show"],["exit_room"]])
	return {"handled":1,"effects":effects}

## Message9 (first room update, C9F).
static func entry_callback(flags: Dictionary) -> Dictionary:
	var effects: Array = [["ambient_start",350,100]]
	if _f(flags,52): return {"handled":0,"effects":effects}
	if _f(flags,55) and not _f(flags,56):
		effects.append_array([_movie(30,440,6),_movie(30,441,6,128)])
		return {"handled":1,"effects":effects}
	if _f(flags,56) and not _f(flags,57): return {"handled":1,"effects":effects}
	if _f(flags,58): return {"handled":0,"effects":effects}
	effects.append(["set_flag",58])
	for row in INTRO:
		if row[0] == 419: effects.append(["mana_debit",1000]) # Guarded by flag52, clear here.
		effects.append(_movie(30,row[0],6,row[1]))
		if row[0] == 404: effects.append(["set_flag",53])
		if row[0] == 409: effects.append(["set_flag",54])
	effects.append(["arm_timer",TIMER_TICKS])
	return {"handled":1,"effects":effects}

## Messages11/12 (D0E): acknowledged, no effect.
static func completion() -> Dictionary:
	return {"handled":1,"effects":[]}

## Dialogue-only view of message9, used by the saved introduction sequence.
static func entry(flags: Dictionary) -> Dictionary:
	var plan := entry_callback(flags)
	var result := {"handled":true,"dialogue":[],"set_flags":[]}
	for effect in plan.effects:
		if effect[0] in ["movie","movie_flags"]: result.dialogue.append(effect[2])
		elif effect[0] == "set_flag": result.set_flags.append(effect[1])
	return result

## Host click router EFC74 (non-exit clicks): an active NPC rect wins; otherwise
## each hit sprite in slot order gets message3 until one is handled, then the
## first hit hotspot in slot order gets message4. Canvas coordinates are 640x400.
static func route(point: Vector2i, flags: Dictionary, sprite_sizes: Dictionary) -> Array:
	var hits: Array = []
	if point.y < 0 or point.y >= 400: return hits
	if not _f(flags,52) and Rect2i(NPC[2],NPC[3],NPC[4],NPC[5]).has_point(point): return [["npc",0]]
	var shown := visible_sprites(flags)
	for id in range(6):
		if not id in shown or not sprite_sizes.has(id): continue
		var s: Array = SPRITES[id]
		var size: Vector2i = sprite_sizes[id]
		if Rect2i(s[0],s[1],size.x,size.y).has_point(point): hits.append(["sprite",id])
	for id in range(5):
		for h in HOTSPOTS:
			if h[0] == id and point.x >= h[1] and point.y >= h[2] and point.x <= h[3] and point.y <= h[4]:
				hits.append(["hotspot",id])
				return hits
	return hits
