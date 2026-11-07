extends RefCounted
## Handler70 request effects, pinned to512 isolated native replays. No native bank is mutated here.
const ID:="act2:L9_DR:item55"
const Handlers=preload("res://scripts/lol2/item_handlers.gd")
static func request(mode: int,local_value: int,bank_exists: bool=true)->Dictionary:
 var next:=local_value
 if bank_exists and mode in [14,18]:next=1 if mode==18 else 0
 return {"local":next,"result":1 if mode==18 else 2 if mode==16 else 0,"writes":bank_exists and mode in [14,18]}
## Book inventory admission derives from current possession. This intentionally does not seed level locals.
static func available(inventory: Array)->bool:
 var carried:=inventory.any(func(id):return Handlers.Catalog.definition(id)==59)
 var mode:=18 if carried else 14
 var routed:=Handlers.route(59,mode)
 return routed.hosted and routed.handler==70 and request(mode,0).local==1
