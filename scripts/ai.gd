class_name Ai
extends Node
## ذكاء جيش الحاسوب (عدو أو حليف): يجمع الذهب بالشاحنات، يبني مقرات وقواعد، ويرسل موجات هجوم.
## يوجد جسم واحد لكل جيش حاسوب. slot = رقم الجيش (1..3).

var g: Main
var slot := 1
var t := 0.0
var bt := 10.0
var wt := 0.0


func reset() -> void:
	t = randf() * 3.0
	bt = 10.0
	wt = randf() * 2.0


func tick(delta: float) -> void:
	var cf: Dictionary = Data.DIFF[g.diff]
	t += delta
	if t >= float(cf["every"]):
		t = 0.0
		_train(cf)
	bt += delta
	if bt >= float(cf["bt"]):
		bt = 0.0
		_build(cf)
	wt += delta
	if wt >= 3.0:
		wt = 0.0
		_attack(cf)


func _mine_list(ty: String) -> Array:
	return g.blds.filter(func(b): return b.team == slot and not b.dead and b.con >= 1.0 and b.type == ty)


func _pick_vehicle(tech: int) -> String:
	var pool := ["lt", "tank"]
	if tech >= 1:
		pool = ["lt", "tank", "tank", "art", "aa"]
	if tech >= 2:
		pool = ["tank", "heavy", "heavy", "art", "aa", "lt"]
	return pool.pick_random()


func _pick_inf(tech: int) -> String:
	if tech == 0:
		return "inf"
	if tech == 1:
		return ["inf", "inf", "rpg"].pick_random()
	return ["inf", "rpg", "rpg", "sniper"].pick_random()


func _train(cf: Dictionary) -> void:
	var tech: int = int(cf["tech"])
	var deps: Array = _mine_list("dep")
	var trucks: int = g.units.filter(func(u): return u.team == slot and u.is_truck and not u.dead).size()
	var queued := 0
	for d in deps:
		queued += d.q.size()
	var gold: float = g.gold[slot]
	if not deps.is_empty() and trucks + queued < int(cf["trucks"]) and gold >= 300.0:
		g.queue_unit(deps.pick_random(), "truck")
		return
	var facs: Array = _mine_list("fac")
	var bars: Array = _mine_list("bar")
	var airs: Array = _mine_list("air")
	var bld = null
	var tp := ""
	if bool(cf["air"]) and not airs.is_empty() and gold >= 800.0 and randf() < 0.4:
		bld = airs.pick_random()
		tp = ["heli", "jet", "jet", "bomber"].pick_random()
	elif not facs.is_empty() and gold >= 450.0 and randf() < 0.55:
		bld = facs.pick_random()
		tp = _pick_vehicle(tech)
	elif not bars.is_empty() and gold >= 100.0:
		bld = bars.pick_random()
		tp = _pick_inf(tech)
	if bld != null and tp != "" and bld.q.size() < 3:
		g.queue_unit(bld, tp)


func _build(cf: Dictionary) -> void:
	var mine_b: Array = g.blds.filter(func(b): return b.team == slot and not b.dead)
	var count := func(ty: String) -> int:
		return mine_b.filter(func(b): return b.type == ty).size()
	var depots: int = count.call("dep")
	var max_f: int = 1
	match g.diff:
		"normal":
			max_f = 2
		"hard":
			max_f = 4
	var gold: float = g.gold[slot]
	if depots < int(cf["depots"]) and gold >= 600.0:
		_place_depot()
	elif bool(cf["air"]) and count.call("air") < 1 and count.call("fac") >= 1 and gold >= 1000.0:
		_auto_place("air")
	elif count.call("fac") < max_f and gold >= 800.0:
		_auto_place("fac")
	elif count.call("bar") < max_f + 1 and gold >= 500.0:
		_auto_place("bar")
	elif g.diff != "easy" and count.call("twr") < max_f * 2 and gold >= 650.0:
		_auto_place("twr")


func _attack(cf: Dictionary) -> void:
	if g.time < float(cf["first"]) + float(slot) * 15.0:
		return
	var free: Array = g.units.filter(func(u): return u.team == slot and not u.dead and not u.sent and not u.is_truck)
	if free.size() < int(cf["wave"]):
		return
	var targets: Array = g.blds.filter(func(b): return g.hostile(b.team, slot) and not b.dead)
	if targets.is_empty():
		return
	var me = g.find_hq(slot)
	if me != null:
		targets.sort_custom(func(a, b): return Vector2(a.cell).distance_to(Vector2(me.cell)) < Vector2(b.cell).distance_to(Vector2(me.cell)))
	var tb = targets[0]
	for u in free:
		u.sent = true
		u.amove = true
		u.dest = tb.cell + Vector2i(1, 1)
		u.goto_cell(u.dest)


func _place_depot() -> void:
	var own: Array = g.blds.filter(func(b): return b.team == slot and not b.dead and b.type == "dep")
	var best = null
	var bd := 1e9
	var hq = g.find_hq(slot)
	if hq == null:
		return
	for m in g.mines:
		if float(m["amount"]) <= 0.0:
			continue
		var near_dep := false
		for d in own:
			if Vector2(d.cell).distance_to(Vector2(m["cell"])) < 16.0:
				near_dep = true
		if near_dep:
			continue
		var dist: float = Vector2(m["cell"]).distance_to(Vector2(hq.cell))
		if dist < bd:
			bd = dist
			best = m
	if best == null or bd > 70.0:
		return
	for i in 40:
		var c: Vector2i = best["cell"] + Vector2i(randi_range(-7, 7), randi_range(-7, 7))
		if g.can_place(slot, "dep", c):
			g.gold[slot] -= float(Data.BUILDINGS["dep"]["cost"])
			g.add_building("dep", slot, c, false)
			return


func _auto_place(type: String) -> void:
	var hq = g.find_hq(slot)
	if hq == null:
		return
	for i in 40:
		var c := Vector2i(hq.cell.x + randi_range(-12, 12), hq.cell.y + randi_range(-12, 12))
		if g.can_place(slot, type, c):
			g.gold[slot] -= float(Data.BUILDINGS[type]["cost"])
			g.add_building(type, slot, c, false)
			return
