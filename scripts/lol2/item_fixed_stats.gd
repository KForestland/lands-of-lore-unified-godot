extends RefCounted
## Owner WO4: fixed numbers, no balancing. I03 proves signed+0x40 is
## ONE weapon/other-slot addend, not the whole native strike formula.
## Use it as the fixed modern value where present. Zero ranged terms do not
## identify projectile damage; those retain flat8. Protection is signed+0x41.
const Definitions=preload("res://scripts/lol2/item_definitions.gd")
const FALLBACK_DAMAGE:=8
static func row(index:int)->Dictionary:
 if Definitions.row(index).is_empty():return {}
 var term:int=Definitions.raw_byte(index,0x40)
 if term>=128:term-=256
 var slot:String=Definitions.slot(index)
 var weapon:bool=slot=="weapon" or index==25 # Preserve the existing Net held-weapon adapter.
 var damage:int=(term if term>0 else FALLBACK_DAMAGE) if weapon else term if slot!="" else 0
 var source:String="original signed+0x40 term as fixed adapter; full formula incomplete"
 if weapon and term<=0:source="flat8 fallback; projectile/base damage not recovered"
 elif slot.is_empty() and not weapon:source="not equipment"
 return {"definition":index,"damage":damage,"protection":Definitions.defense(index),"damage_source":source,"protection_source":"original signed+0x41"}
