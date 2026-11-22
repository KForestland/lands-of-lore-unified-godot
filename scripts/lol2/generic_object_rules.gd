extends RefCounted
## Decoded use/motion publication; the owner-approved cadence/closed-state bridges are modern.
## One logical position in 16.16; travel is the native target word, phase is object byte +0x55.
const POSITION := "position_0x48"
const PHASE := "state_0x55"
const TRAVEL := "travel_0x50"
const FRACTION := "generic_tick_fraction_16"
const FIXED := 65536
const REACH := 256.0
const TICKS_PER_SECOND := 30.0 # Adapter: tick-arm dispatch and original cadence remain untraced.
const FIELDS := [POSITION, PHASE, TRAVEL, FRACTION]

static func distance_word(mode: int, byte: int) -> int:
 return ((byte * 2 % 360) * FIXED) / 360 if mode == 6 else byte
static func initial(placement: PackedByteArray) -> Dictionary:
 return {POSITION:int(placement[0x26])*FIXED, PHASE:int(placement[0x27]), TRAVEL:0, FRACTION:0}
static func use(state: Dictionary, placement: PackedByteArray, distance: float, context: int = 0, disabled: bool = false) -> Dictionary:
 var result := {"state":state.duplicate(), "accepted":false, "callers":[]}
 if disabled or (int(placement[0x23]) & 2) == 0 or context != 0 or distance > REACH or distance < 0.0:return result
 var next: Dictionary = result.state
 match int(state[PHASE]):
  0, 5: # Adapter: the native closing arm ends in5; repeat use treats it as closed.
   next[PHASE]=2;next[TRAVEL]=distance_word(int(placement[0x22]),int(placement[0x24]))
  1: next[PHASE]=3;next[TRAVEL]=0
  2: next[PHASE]=1;result.callers=[0x11]
  3: next[PHASE]=0;result.callers=[0x11]
  _: return result
 result.accepted=true
 return result
static func tick(state: Dictionary, placement: PackedByteArray, delta: float) -> Dictionary:
 var next := state.duplicate()
 var result := {"state":next,"callers":[]}
 if int(next[PHASE]) not in [2,3] or delta <= 0.0:return result
 var fixed_ticks: int = int(next[FRACTION]) + int(round(delta * TICKS_PER_SECOND * FIXED))
 var ticks: int = fixed_ticks / FIXED
 next[FRACTION] = fixed_ticks % FIXED
 var step: int = maxi(1,distance_word(int(placement[0x22]),int(placement[0x25]))) * FIXED
 var target: int = int(next[TRAVEL]) * FIXED
 var position: int = int(next[POSITION])
 if int(next[PHASE]) == 2:
  next[POSITION] = mini(target,position + ticks * step)
  if int(next[POSITION]) == target:next[PHASE]=1;next[FRACTION]=0;result.callers=[0x0F,0x11]
 else:
  next[POSITION] = maxi(target,position - ticks * step)
  if int(next[POSITION]) == target:next[PHASE]=5;next[FRACTION]=0;result.callers=[0x10]
 return result
static func transform_for(mode: int, position_fixed: int, origin: Vector3) -> Transform3D:
 var amount := float(position_fixed) / FIXED
 var transform := Transform3D(Basis.IDENTITY,origin)
 match mode:
  0: transform.origin.y += amount
  1: transform.origin.y -= amount
  2: transform.origin.x += amount
  3: transform.origin.x -= amount
  4: transform.origin.z -= amount # native horizontal y has the opposite Godot z sign
  5: transform.origin.z += amount
  6: transform.basis=Basis(Vector3.UP,-amount/FIXED*TAU)
 return transform
## Compatibility only: older saves may predate a smaller published span.
## Malformed/negative fields still fail motion_error before any restore write.
static func clamp_saved_motion(value:Variant,placement:PackedByteArray)->Variant:
 if not value is Dictionary or value.size()!=FIELDS.size():return value
 var row:Dictionary=value.duplicate(true)
 var limit:int=distance_word(int(placement[0x22]),int(placement[0x24]))
 for pair in [[POSITION,limit*FIXED],[TRAVEL,limit]]:
  var field:String=pair[0];var number:Variant=row.get(field)
  if (number is int or number is float) and is_finite(float(number)) and number==int(number) and number>int(pair[1]):row[field]=int(pair[1])
 return row
static func motion_error(value: Variant, placement: PackedByteArray) -> String:
 if not value is Dictionary or value.size()!=FIELDS.size():return "Invalid generic movable state."
 for field in FIELDS:
  if not (value.get(field) is int or value.get(field) is float) or not is_finite(float(value[field])) or value[field]!=int(value[field]):return "Invalid generic movable field."
 var limit := distance_word(int(placement[0x22]),int(placement[0x24]))
 if int(value[POSITION])<0 or int(value[POSITION])>limit*FIXED or int(value[PHASE]) not in [0,1,2,3,5] or int(value[TRAVEL])<0 or int(value[TRAVEL])>limit or int(value[FRACTION])<0 or int(value[FRACTION])>=FIXED:return "Invalid generic movable bounds."
 return ""

## Adapter at the event boundary: VM dispatch stays first-success per event.
static func crossed_thresholds(old_life:int,remaining:int,thresholds:Array)->Array:
 var result:Array=[]
 for threshold in thresholds:
  if remaining<=int(threshold) and int(threshold)<old_life and not int(threshold) in result:result.append(int(threshold))
 result.sort();result.reverse()
 return result
