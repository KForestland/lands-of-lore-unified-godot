extends RefCounted
## Dawn spell 58: Plasma bolt. SPELL.ODF family 11, effect 58, vtable 0x7860. A pure lifecycle module (modern adapter)
## for LOLG constructor 0x10519C, update 0x105644, collision 0x105950 and hit 0x105A40.
## Executed facts (tests/fixtures/dawn_spell7_58_requests_native.json):
## - flight selector -> impact state;
## - the requests per impact state, sent once (latch).
## Dawn passes selector 4, so impact 5: one request mask 0x11 / subtype 0x3A / amount 10, source Dawn.
## Effects returned for owners:
## - "move": speed 200 (shared motion);
## - "request" to the hit object's receiver (lead-owned health/mask handling);
## - "cue": presentation string slot;
## - "destroy".
const Heading=preload("res://scripts/lol2/dawn_heading.gd")
const Chain=preload("res://scripts/lol2/dawn_spell7_chain.gd")
const SPEED:=200
const DAWN_SELECTOR:=4
const FLIGHT_TO_IMPACT:={0:1,4:5,6:7,8:9}
const IMPACT_STATES:=[1,5,7,9]
## source "owner" = the caster; "none" = no source (state 1 only).
const IMPACT_REQUESTS:={
	1:[{"mask":0x10,"signature":2,"source":"none","mode":2,"subtype":0x3A,"amount":3},{"mask":1,"signature":2,"source":"none","mode":2,"subtype":0x3A,"amount":3}],
	5:[{"mask":0x11,"signature":1,"source":"owner","mode":2,"subtype":0x3A,"amount":10}],
	7:[{"mask":0x11,"signature":1,"source":"owner","mode":2,"subtype":0x3C,"amount":30}],
	9:[{"mask":0x11,"signature":1,"source":"owner","mode":2,"subtype":0x3A,"amount":4}]}
## Object types (virtual+0) a Plasma collision damages.
const HIT_TYPES:=[1,2,3,0x10]

static func initial(owner: Variant, target: Variant, heading: int, selector: int=DAWN_SELECTOR) -> Dictionary:
	return {"version":1,"owner":owner,"target":target,"state":selector,"heading":heading,"hit":false,"request_latched":false,"cue_pending":false,"ended":false}

static func impact(s: Dictionary) -> bool: return int(s.state) in IMPACT_STATES

## 0x105A40: one-shot requests by impact state to the hit object.
static func hit(s: Dictionary, target: Variant) -> Array:
	if target==null or s.request_latched: return []
	s.request_latched=true
	var out: Array=[]
	for r in IMPACT_REQUESTS.get(int(s.state),[]):
		var q: Dictionary=r.duplicate();q.to=target;q.source=s.owner if r.source=="owner" else null;q.type="request";out.append(q)
	return out

static func _strike(s: Dictionary) -> void:
	s.state=int(FLIGHT_TO_IMPACT.get(int(s.state),int(s.state)))
	s.hit=true

## One update. ctx: {position, step, positions:{id:[x,y]}, animation_done: bool, placement_failed: bool}.
static func step(s: Dictionary, ctx: Dictionary) -> Array:
	var fx: Array=[]
	if ctx.get("placement_failed",false) or s.ended: s.ended=true;return [{"type":"destroy"}]
	if s.cue_pending:
		s.cue_pending=false;fx.append({"type":"cue","slot":0x104 if int(s.state)==1 else 0x202})
	if impact(s):
		if ctx.get("animation_done",false): s.ended=true;fx.append({"type":"destroy"})
		return fx
	fx.append({"type":"move","heading":int(s.heading),"speed":SPEED})
	if s.target!=null:
		var at: Array=ctx.positions[s.target]
		if Chain.planar(ctx.position,at)>int(ctx.step):
			s.heading=int(Heading.between(ctx.position,at).word)
		else:
			var target=s.target
			_strike(s)
			fx.append({"type":"cue","slot":0x104 if int(s.state)==1 else 0x202})
			fx.append_array(hit(s,target))
			s.target=null
	return fx

## 0x105950: the bolt touched an object. ctx: {touched (id or null), touched_type, touched_is_owner, owner_blocks}.
static func collide(s: Dictionary, ctx: Dictionary) -> Array:
	if s.hit: return []
	if ctx.get("touched_is_owner",false) and not ctx.get("owner_blocks",false): return []
	s.cue_pending=true
	_strike(s)
	s.target=null
	var touched=ctx.get("touched")
	if touched!=null and int(ctx.get("touched_type",0)) in HIT_TYPES: return hit(s,touched)
	return []
