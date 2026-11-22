extends RefCounted
## Definition-wide food/healing admission. Existing effect owners retain their
## native rules; guide-only effects are labelled in the game-wide census.
const USES:={68:"ancient",72:"dampen_charm",84:"vels_fruit",109:"aloe",110:"aloe",111:"ironwood_sap",117:"silverleaf",119:"amaranth_serum",122:"black_lichen",123:"champion_stone",125:"poison_paint",127:"ancient",133:"mana_foil",116:"gorgonite",118:"mandrake",124:"inert_food",129:"death_sac",134:"mind_cluster",126:"war_cluster"}
static func kind(definition:int)->String:
 return str(USES.get(definition,""))
static func description(definition:int)->String:
 match definition:
  109,110:return "Eat to heal 5 health over time. Kept when health is full or the quest still needs it."
  111:return "A recipe ingredient; eating sap has no effect."
  117:return "Restores up to 5 mana. Also used in recipes and offerings."
  119:return "Has no effect alone. Keep it to mix with a Silverleaf."
  122:return "Restores up to 20 health. Also used on suitable soil."
  133:return "Restores up to 50 mana."
  118:return "Restores health and mana, then puts you to sleep for five seconds."
  116:return "A recipe ingredient. Eating it has a small chance of turning you into the Beast for one minute."
  134:return "Reveals the current area on the map."
  129:return "Apply to your weapon for one coat of Greater Poison."
  124:return "A failed mixture. It has no useful effect."
  126:return "Adds20% temporary health for one minute. Losing the borrowed health can be fatal."
 return ""
