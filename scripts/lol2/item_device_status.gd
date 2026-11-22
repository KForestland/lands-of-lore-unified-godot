extends RefCounted
## A device's guide description does not establish its charge counter or cast
## level. Keep these gaps visible; do not invent a spell mapping.
const GAPS:={55:"Hurls lightning; its original charges and bolt mapping are not hosted.",56:"Burnt lightning crystal. Its recharge rule is not known.",60:"Creates stone growth; original size, placement and lifetime are not hosted.",62:"Summons a guarding sword; its lifetime and combat rules are not hosted.",63:"Creates ice; its projectile and temporary-world rules are not hosted.",66:"Invokes a storm; original charge count and storm effect are not hosted.",67:"Burnt storm crystal. Its recharge rule is not known.",132:"Changes Spark to fire for two minutes; the Fire Spark cast is not hosted.",135:"Petrifies a touched opponent; the native petrify clock is not yet hosted."}
static func description(definition:int)->String:return str(GAPS.get(definition,""))
