extends RefCounted
## Modern physical throwing admission. Recovered guide: Long Arm returns;
## a rock and throwing dagger are physical missiles. Flight/reach and missing
## item damage are explicit fixed adapters, not a native physics reconstruction.
const DEFINITIONS:=[6,9,23]
const DAMAGE:=8 # Compatibility with current stand-in creature health.
const REACH:=384.0
const AREAS:=["res://scenes/lol2/cave_walkthrough.tscn","res://scenes/lol2/museum_walkthrough.tscn","res://scenes/lol2/jungle_walkthrough.tscn","res://scenes/lol2/hive_review.tscn","res://scenes/lol2/darker_jungle.tscn","res://scenes/lol2/dark_halls.tscn","res://scenes/lol2/maps/L9_DR.tscn","res://scenes/lol2/maps/L10_DC.tscn","res://scenes/lol2/maps/L12_CM.tscn","res://scenes/lol2/maps/L13_RC.tscn","res://scenes/lol2/maps/L14_HT.tscn","res://scenes/lol2/maps/L16_CA.tscn","res://scenes/lol2/maps/L17_HC.tscn","res://scenes/lol2/maps/L19_BC.tscn","res://scenes/lol2/maps/L20_BB.tscn"]
static func supported(definition:int)->bool:return definition in DEFINITIONS
static func validate(rows:Variant,spent:Array,collected:Array)->String:
 if not rows is Array or rows.size()>preload("res://scripts/lol2/item_catalog.gd").consumables().size():return "Invalid thrown item records."
 var seen:Array=[]
 for row in rows:
  if not row is Dictionary or row.size()!=3 or not row.get("id") is String:return "Invalid thrown item record."
  var id:String=row.id
  var C=load("res://scripts/lol2/item_catalog.gd")
  if C.definition(id) not in [9,23] or id not in spent or id in collected or id in seen:return "Invalid thrown item ownership."
  if row.get("area") not in AREAS:return "Invalid thrown item area."
  var p=row.get("position")
  if not p is Array or p.size()!=3:return "Invalid thrown item position."
  for value in p:
   if not (value is int or value is float) or not is_finite(float(value)) or absf(value)>32768:return "Invalid thrown item position."
  seen.append(id)
 return ""
