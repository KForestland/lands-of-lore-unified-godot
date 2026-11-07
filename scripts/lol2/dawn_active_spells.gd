extends RefCounted
## Original AB473 active-list update. Caller supplies the global22CC4 tick gate.
const Validation=preload("res://scripts/lol2/hive_player_conditions.gd")
static func expire(active: Variant, exclusive: Variant, tick: Variant) -> Dictionary:
	if not active is Array or active.size()>4 or not tick is bool or not Validation._integer(exclusive,0,255): return {"error":"Invalid active spell state."}
	var raw: Array[int]=[0,0,0,0,0,0,0,0]
	for i in range(active.size()):
		if not active[i] is Array or active[i].size()!=2: return {"error":"Invalid active spell record."}
		for j in range(2):
			if not Validation._integer(active[i][j],0,255): return {"error":"Invalid active spell byte."}
			raw[i*2+j]=int(active[i][j])
	var count: int=active.size()
	var flag:=int(exclusive)
	var index:=0
	var cursor:=0
	if tick:
		while index<count:
			if raw[cursor+1]!=0: raw[cursor+1]-=1
			if raw[cursor+1]==0:
				count-=1
				if raw[cursor]==61: flag=0
				# Source passes remaining record count as BYTE length to memmove.
				if count>index:
					var copied:=raw.slice(cursor+2,cursor+2+count-index)
					for j in range(copied.size()): raw[cursor+j]=copied[j]
				raw[count*2]=0;raw[count*2+1]=0
			else: cursor+=2
			# After removal native increments the loop index without advancing the pointer.
			index+=1
	var result: Array=[]
	for i in range(count):result.append([raw[i*2],raw[i*2+1]])
	return {"active":result,"exclusive":flag,"raw":raw}
