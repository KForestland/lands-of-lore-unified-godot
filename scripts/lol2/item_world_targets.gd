extends RefCounted
## Inventory selection only. Target owners retain reach, story, transaction and
## save guards; this table neither consumes an item nor replays an event.
const TARGETS:={73:"a place that needs wax",74:"the Draracle",77:"the Emperor's urn",78:"the Emperor's ashes",81:"the Citadel door",94:"a matching skull lock",95:"a matching skull lock",96:"a flute slot",97:"the ankh slab",98:"a globe charger",99:"a matching globe socket",100:"a matching globe socket",101:"a matching globe socket",102:"a Dracoid sigil lock",105:"a crystal-shard receptacle",107:"the Draracle",108:"a matching Temple pedestal",136:"the Dreamstone exit slot",168:"the Emperor's tomb"}
static func hint(definition:int)->String:
 return "Hold for E at "+str(TARGETS[definition])+"." if TARGETS.has(definition) else ""
