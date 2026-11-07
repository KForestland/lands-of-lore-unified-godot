extends RefCounted
## Original altar awards with a book-led current-sword transaction adapter.
const Kit=preload("res://scripts/lol2/mechanism_transaction.gd")
const Catalog=preload("res://scripts/lol2/item_catalog.gd")
const KEY="l13_altar"
const TARGET="citadel:sword_altar"
const DARK="act2:L13_RC:dark_sword"
const THOHAN="act2:L13_RC:enchanted_thohan"
const STONE="act2:L13_RC:dreamstone"
# Book-led admission of the sword currently in use; exact native offer dispatcher unjoined.
const SWORDS=[4,5,14,17,20,21,71]
static func initial()->Dictionary:return {"version":1,"slots":{},"sword":"","output":"","stone_taken":false}
static func enchanted(s:Dictionary)->bool:return Kit.slot(s,TARGET).committed
static func enchant(s:Dictionary,inventory:Array,item:String,equipped:String,boss_dead:bool,capacity:int=64)->Dictionary:
 if not boss_dead:return Kit.refuse("Defeat the creature guarding the altar first.")
 if s.stone_taken:return Kit.refuse("The Dreamstone has already been removed.")
 if enchanted(s):return Kit.refuse("The altar has already enchanted your sword.")
 if item!=equipped or Catalog.definition(item) not in SWORDS:return Kit.refuse("Place the sword you are using on the altar.")
 var output:String=THOHAN if Catalog.definition(item)==20 else DARK
 var recipe:={"target":TARGET,"accepts":[item],"output":output,"retrievable":true,"repeatable":false,"forms":["human"]}
 var snap:=Kit.empty_snapshot(inventory,capacity);snap.slots=s.slots.duplicate(true)
 var result:=Kit.offer(snap,recipe,item,{"form":"human"})
 if not result.ok:return result
 result=Kit.occupy(snap,result.proposal)
 if not result.ok:return result
 result=Kit.commit(result.snapshot,recipe,TARGET)
 if not result.ok:return result
 result=Kit.retrieve(result.snapshot,recipe)
 if not result.ok:return result
 return {"ok":true,"inventory":result.snapshot.inventory,"state":{"version":1,"slots":result.snapshot.slots,"sword":item,"output":output,"stone_taken":false}}
static func take_stone(s:Dictionary,inventory:Array,boss_dead:bool,capacity:int=64)->Dictionary:
 if not boss_dead or not enchanted(s):return Kit.refuse("Enchant your sword before taking the Dreamstone.")
 if s.stone_taken:return Kit.refuse("The Dreamstone has already been taken.")
 if inventory.size()>=capacity:return Kit.refuse("Your inventory is full.")
 var next:=s.duplicate(true);next.stone_taken=true
 var carried:=inventory.duplicate();carried.append(STONE)
 return {"ok":true,"inventory":carried,"state":next}

static func validate(s:Variant,quests:Dictionary)->String:
 if not s is Dictionary or s.size()!=5 or s.get("version")!=1 or not s.get("slots") is Dictionary or not s.get("sword") is String or not s.get("output") is String or not s.get("stone_taken") is bool:return "Invalid Citadel altar."
 var snap:=Kit.empty_snapshot();snap.slots=s.slots
 if not Kit.validate(snap).is_empty():return "Invalid altar transaction."
 if not enchanted(s):return "" if s==initial() else "Uncommitted altar changed."
 var slot:Dictionary=s.slots[TARGET]
 if s.slots.size()!=1 or slot.size()!=3 or slot.occupied!="" or slot.receipts!=[TARGET] or Catalog.definition(s.sword) not in SWORDS or s.output!=(THOHAN if Catalog.definition(s.sword)==20 else DARK):return "Invalid altar receipt."
 var history:Array=quests.get("act2_items",{}).get("collected",[])
 if s.output not in history or (s.stone_taken and STONE not in history):return "Altar lacks award history."
 if float(quests.get("act2_creatures_L13_RC",{}).get("actors",{}).get("40",{}).get("health",1))>0:return "Altar precedes boss death."
 return ""
