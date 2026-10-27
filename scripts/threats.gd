class_name Threats
extends RefCounted
## سجل الهجمات: كل مبنى يتعرض لضرر من عدو يُسجَّل هنا، فيستجيب الحلفاء والقاذفات للدفاع عنه.

const KEEP := 14.0   # ثواني بقاء التهديد نشطاً بعد آخر ضربة

static var list: Array = []


static func add(b, from_team: int) -> void:
	var g: Main = b.g
	var now: float = g.time
	var pos: Vector3 = b.position
	for e in list:
		if int(e["owner"]) == b.team and (e["pos"] as Vector3).distance_to(pos) < 14.0:
			e["t"] = now
			e["from"] = from_team
			e["pos"] = pos
			return
	list.append({"pos": pos, "owner": b.team, "from": from_team, "t": now})


# أحدث تهديد على أي مبنى يخص فريق الجيش slot (نفسه أو حلفائه). يرجع null إن لم يوجد.
static func latest(g: Main, slot: int):
	list = list.filter(func(e): return float(e["t"]) <= g.time + 1.0 and g.time - float(e["t"]) < KEEP)
	var best = null
	var bt := -1e9
	for e in list:
		var o: int = int(e["owner"])
		if g.team_of[o] != g.team_of[slot]:
			continue
		if float(e["t"]) > bt:
			bt = float(e["t"])
			best = e
	return best
