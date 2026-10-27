class_name Unit
extends Node3D

var kind := "u"
var type := "inf"
var cls := "inf"
var team := 0            # رقم صاحب الوحدة (0 اللاعب، 1..3 جيوش الحاسوب)
var g: Main
var def: Dictionary
var hp := 100.0
var max_hp := 100.0
var path: Array = []
var goal := Vector2i(-1, -1)
var tgt = null
var cd := 0.0
var amove := false
var dest := Vector2i(-1, -1)
var rp := 0.0
var forced := false
var sent := false
var dead := false
var is_air := false
var is_truck := false
var moving := false
var alt := 0.0
var ta := 0.0
var anim := 0.0
var selected := false
var model: Node3D
var turret: Node3D
var rotor: Node3D
var tail_rotor: Node3D
var cargo: Node3D
var legs: Array = []
var ring: MeshInstance3D
var bar_bg: MeshInstance3D
var bar_fg: MeshInstance3D
# حالة شاحنة الذهب
var state := "idle"
var load_gold := 0.0
var mine_id := -1
var depot = null
var work := 0.0
var wait := 0.0
var fail := 0
var hit_cd := 0.0
var fx_t := 0.0
var smoke: CPUParticles3D
var fire: CPUParticles3D
# كشف التعثر
var stuck_acc := 0.0
var stuck_ref := Vector3.ZERO
var stuck_cnt := 0
var scan_t := 0.0
var ui_made := false


func setup(main: Main, t: String, tm: int, pos: Vector3) -> void:
	g = main
	type = t
	team = tm
	def = Data.UNITS[t]
	cls = str(def["cls"])
	var a: Dictionary = Data.ARMIES[g.army_of[tm]]
	var hm := 1.0
	if g.hostile(tm, 0):
		hm = float(Data.DIFF[g.diff]["hp"])
	max_hp = float(def["hp"]) * float(a.get("hp", 1.0)) * hm
	hp = max_hp
	is_air = bool(def["air"])
	is_truck = t == "truck"
	alt = 0.0
	if t == "heli":
		alt = 7.0
	elif t == "jet":
		alt = 10.0
	elif t == "bomber":
		alt = 12.0
	position = pos + Vector3(0, alt, 0)
	stuck_ref = position
	var c := Vector3(Data.MAP * Data.CELL * 0.5, 0, Data.MAP * Data.CELL * 0.5)
	rotation.y = atan2(c.x - pos.x, c.z - pos.z)
	model = ModelsEx.unit_model(t, a["color"])
	add_child(model)
	turret = model.get_node_or_null("Turret")
	rotor = model.get_node_or_null("Rotor")
	tail_rotor = model.get_node_or_null("TailRotor")
	cargo = model.get_node_or_null("Cargo")
	if cargo != null:
		cargo.visible = false
	for nm in ["LegL", "LegR"]:
		var l := model.get_node_or_null(nm)
		if l != null:
			legs.append(l)
	scan_t = randf() * 0.3


func _ensure_ui() -> void:
	if ui_made:
		return
	ui_made = true
	_make_ui()


func _make_ui() -> void:
	var r: float = float(def["radius"])
	ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r + 0.25
	tm.outer_radius = r + 0.45
	ring.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(0.4, 1.0, 0.55)
	ring.material_override = rm
	ring.position.y = 0.12 - alt
	ring.visible = false
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	bar_bg = _bar(Color(0, 0, 0, 0.7), 0)
	bar_fg = _bar(Color(0.37, 0.83, 0.42), 1)
	bar_bg.visible = false
	bar_fg.visible = false


func _bar(col: Color, prio: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.7, 0.2) if prio == 0 else Vector2(1.6, 0.14)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = col
	m.no_depth_test = true
	m.render_priority = prio
	if col.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.position = Vector3(0, 2.6 if not is_air else 1.9, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func set_selected(s: bool) -> void:
	selected = s
	if s:
		_ensure_ui()
	if ring != null:
		ring.visible = s


func center() -> Vector3:
	return position


func radius_w() -> float:
	return 0.0


func goto_cell(c: Vector2i) -> void:
	goal = c
	path = g.find_path_for(self, c)


func take_damage(dm: float, _from_team: int) -> void:
	if dead:
		return
	hp -= dm
	if hit_cd <= 0.0 and (g.friendly(team) or g.is_vis(position)):
		hit_cd = 0.12
		g.impact(position + Vector3(0, 1.0, 0), cls != "inf")
		Sfx.play("hit")
	if hp <= 0.0:
		die()


func _damage_fx() -> void:
	if cls == "inf":
		return
	var f: float = hp / max_hp
	if f < 0.45 and smoke == null:
		smoke = g.make_smoke(Vector3(0.3, 0.1, 0.3), 8)
		smoke.position = Vector3(0, 1.3, -0.6)
		add_child(smoke)
	if smoke != null:
		smoke.emitting = f < 0.45
	if f < 0.22 and fire == null:
		fire = g.make_fire(Vector3(0.3, 0.1, 0.3), 8)
		fire.position = Vector3(0, 1.2, -0.4)
		add_child(fire)
	if fire != null:
		fire.emitting = f < 0.22


func die() -> void:
	dead = true
	g.remove_entity(self)
	if ui_made:
		ring.visible = false
		bar_bg.visible = false
		bar_fg.visible = false
	var tw := create_tween()
	if cls == "inf":
		g.impact(position + Vector3(0, 0.8, 0), false)
		if g.friendly(team) or visible:
			Sfx.play("hit")
		tw.tween_property(model, "rotation:x", -PI / 2.0, 0.35)
		tw.tween_interval(2.5)
		tw.tween_property(model, "position:y", -0.8, 1.0)
		tw.tween_callback(queue_free)
		return
	if is_air:
		var ground: float = g.terrain.height_at(position.x, position.z) + 0.6
		_damage_fx_force()
		tw.tween_property(self, "position:y", ground, 0.8).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(model, "rotation:z", 2.4, 0.8)
		tw.tween_callback(_crash)
		tw.tween_interval(4.0)
		tw.tween_callback(queue_free)
		return
	g.explosion(position + Vector3(0, 0.8, 0), false)
	if g.friendly(team) or visible:
		Sfx.play("boom")
	Models.darken(model, 0.65)
	_damage_fx_force()
	tw.tween_interval(5.0)
	tw.tween_callback(queue_free)


func _damage_fx_force() -> void:
	if smoke == null:
		smoke = g.make_smoke(Vector3(0.3, 0.1, 0.3), 10)
		smoke.position = Vector3(0, 1.3, -0.6)
		add_child(smoke)
	smoke.emitting = true
	if fire == null:
		fire = g.make_fire(Vector3(0.3, 0.1, 0.3), 8)
		fire.position = Vector3(0, 1.2, -0.4)
		add_child(fire)
	fire.emitting = true


func _crash() -> void:
	g.explosion(position, false)
	if g.friendly(team) or visible:
		Sfx.play("boom")
	Models.darken(model, 0.65)


func _process(delta: float) -> void:
	if dead or not g.running:
		return
	cd -= delta
	hit_cd -= delta
	moving = false
	if is_truck:
		_truck_logic(delta)
	else:
		_logic(delta)
	var gy: float = g.terrain.height_at(position.x, position.z)
	position.y = lerpf(position.y, gy + alt, clampf(delta * 5.0, 0.0, 1.0))
	if rotor != null:
		rotor.rotation.y += delta * 32.0
	if tail_rotor != null:
		tail_rotor.rotation.x += delta * 40.0
	if turret != null:
		var want: float = (ta if tgt != null else rotation.y) - rotation.y
		turret.rotation.y = lerp_angle(turret.rotation.y, want, clampf(delta * 8.0, 0.0, 1.0))
	if legs.size() == 2:
		if moving:
			anim += delta * 9.0
		var sw: float = sin(anim) * 0.6 if moving else 0.0
		legs[0].rotation.x = lerpf(legs[0].rotation.x, sw, clampf(delta * 14.0, 0.0, 1.0))
		legs[1].rotation.x = lerpf(legs[1].rotation.x, -sw, clampf(delta * 14.0, 0.0, 1.0))
	if cargo != null:
		cargo.visible = load_gold > 0.0
	fx_t -= delta
	if fx_t <= 0.0:
		fx_t = 0.5
		_damage_fx()
	var show_bar: bool = hp < max_hp or selected
	if show_bar:
		_ensure_ui()
	if ui_made:
		bar_bg.visible = show_bar
		bar_fg.visible = show_bar
	if show_bar:
		var f: float = clampf(hp / max_hp, 0.0, 1.0)
		bar_fg.scale.x = maxf(f, 0.01)
		(bar_fg.material_override as StandardMaterial3D).albedo_color = Color(0.37, 0.83, 0.42) if f > 0.5 else (Color(0.9, 0.75, 0.25) if f > 0.25 else Color(0.88, 0.3, 0.24))


func _face(a: float, delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, a, clampf(delta * 10.0, 0.0, 1.0))


func _unstick() -> void:
	stuck_acc = 0.0
	stuck_cnt += 1
	var a0: float = randf() * TAU
	for k in range(8):
		var a: float = a0 + k * TAU / 8.0
		var nx: float = position.x + cos(a) * 2.4
		var nz: float = position.z + sin(a) * 2.4
		if not g.blocked_for(self, nx, nz):
			position.x = nx
			position.z = nz
			break
	stuck_ref = position
	if goal.x >= 0:
		var gc := goal
		if stuck_cnt >= 2:
			gc = goal + Vector2i(randi_range(-3, 3), randi_range(-3, 3))
		path = g.find_path_for(self, gc)


func _move_along(delta: float) -> void:
	if path.is_empty():
		return
	if not is_air:
		stuck_acc += delta
		if position.distance_to(stuck_ref) > 0.5:
			stuck_ref = position
			stuck_acc = 0.0
			stuck_cnt = 0
		elif stuck_acc > 1.3:
			_unstick()
			if path.is_empty():
				return
	var w: Vector3 = path[0]
	var d := Vector2(w.x - position.x, w.z - position.z)
	var dist: float = d.length()
	var st: float = float(def["speed"]) * Data.CELL * delta
	moving = true
	if dist > 0.02:
		_face(atan2(d.x, d.y), delta)
	if dist <= st:
		position.x = w.x
		position.z = w.z
		path.pop_front()
		return
	var nx: float = position.x + d.x / dist * st
	var nz: float = position.z + d.y / dist * st
	if is_air or g.blocked_for(self, position.x, position.z) or not g.blocked_for(self, nx, nz):
		position.x = nx
		position.z = nz
	elif not g.blocked_for(self, nx, position.z):
		position.x = nx
	elif not g.blocked_for(self, position.x, nz):
		position.z = nz
	else:
		moving = false


# ---------- شاحنة الذهب: منجم ← مقر تجميع الذهب ----------
func _mine_slot(m: Dictionary) -> Vector2i:
	var mp: Vector2 = m["pos"]
	var ang: float = float(get_instance_id() % 997) * 0.37
	var p: Vector2 = mp + Vector2(cos(ang), sin(ang)) * 5.2
	return Vector2i(clampi(int(p.x / Data.CELL), 0, Data.MAP - 1), clampi(int(p.y / Data.CELL), 0, Data.MAP - 1))


func _depot_slot(dp) -> Vector2i:
	var ang: float = float(get_instance_id() % 997) * 0.53
	var rr: float = dp.radius_w() + 3.6
	var p := Vector2(dp.position.x, dp.position.z) + Vector2(cos(ang), sin(ang)) * rr
	return Vector2i(clampi(int(p.x / Data.CELL), 0, Data.MAP - 1), clampi(int(p.y / Data.CELL), 0, Data.MAP - 1))


func _go_depot() -> void:
	depot = g.nearest_depot(self)
	if depot == null:
		state = "idle"
		wait = 2.0
		return
	goto_cell(_depot_slot(depot))
	state = "to_depot"
	fail = 0


func _truck_logic(delta: float) -> void:
	match state:
		"idle":
			wait -= delta
			if wait > 0.0:
				return
			wait = 1.0
			if load_gold > 0.0:
				_go_depot()
				return
			var m = g.pick_mine_for(self)
			if m != null:
				mine_id = m["id"]
				goto_cell(_mine_slot(m))
				state = "to_mine"
				fail = 0
		"to_mine":
			var m2 = g.mine_by_id(mine_id)
			if m2 == null or float(m2["amount"]) <= 0.0:
				state = "idle"
				return
			if path.is_empty():
				var dm: float = Vector2(position.x, position.z).distance_to(m2["pos"])
				if dm < Data.CELL * 5.5:
					state = "gather"
					work = 0.0
				else:
					fail += 1
					if fail > 3:
						state = "idle"
						fail = 0
					else:
						goto_cell(_mine_slot(m2))
			else:
				_move_along(delta)
		"gather":
			work += delta
			var m3 = g.mine_by_id(mine_id)
			if m3 == null or float(m3["amount"]) <= 0.0:
				state = "idle"
				return
			if work >= 3.0:
				var take: float = minf(Data.TRUCK_LOAD, float(m3["amount"]))
				g.take_from_mine(m3, take)
				load_gold = take
				_go_depot()
		"to_depot":
			if depot == null or not is_instance_valid(depot) or depot.dead:
				_go_depot()
				return
			if path.is_empty():
				var dd: float = Vector2(position.x, position.z).distance_to(Vector2(depot.position.x, depot.position.z))
				if dd < depot.radius_w() + Data.CELL * 5.0:
					g.deliver(team, load_gold)
					load_gold = 0.0
					state = "idle"
					wait = 0.2
				else:
					fail += 1
					if fail > 3:
						state = "idle"
						fail = 0
					else:
						goto_cell(_depot_slot(depot))
			else:
				_move_along(delta)


# ---------- وحدات القتال ----------
func _logic(delta: float) -> void:
	var rng_w: float = float(def["range"]) * Data.CELL
	var noair: bool = bool(def["noair"])
	if tgt != null and (not is_instance_valid(tgt) or tgt.dead):
		tgt = null
		forced = false
	if tgt != null and noair and tgt.kind == "u" and tgt.is_air:
		tgt = null
		forced = false
	var reach: float = 9.0
	if type == "bomber":
		reach = 22.0
	if tgt == null and type == "bomber" and team == 0 and not amove and path.is_empty():
		_scramble(delta)
	if tgt == null and (amove or path.is_empty()):
		scan_t -= delta
		if scan_t <= 0.0:
			scan_t = 0.3 + randf() * 0.15
			var r: float = (float(def["range"]) + (2.5 if amove else 3.0) + (12.0 if type == "bomber" else 0.0)) * Data.CELL
			var e = g.nearest_enemy(position, team, r, not noair, type == "aa" or type == "jet")
			if e != null:
				tgt = e
				path = []
	if tgt != null:
		var tp: Vector3 = tgt.center()
		var dv := Vector2(tp.x - position.x, tp.z - position.z)
		var dist: float = dv.length() - float(tgt.radius_w())
		ta = atan2(dv.x, dv.y)
		if dist > rng_w:
			if dist > (float(def["range"]) + reach) * Data.CELL and not forced:
				tgt = null
			else:
				rp -= delta
				if path.is_empty() or rp <= 0.0:
					rp = 0.8
					goto_cell(g.world_to_cell(tp))
				_move_along(delta)
		else:
			path = []
			_face(ta, delta)
			if cd <= 0.0:
				_fire(tgt)
				cd = float(def["cd"])
	elif not path.is_empty():
		_move_along(delta)
	elif amove and dest.x >= 0:
		var dc: Vector3 = g.cell_center(dest)
		if Vector2(dc.x - position.x, dc.z - position.z).length() > Data.CELL * 1.5:
			goto_cell(dest)
		else:
			amove = false
			dest = Vector2i(-1, -1)


# قاذفة اللاعب تهبّ للدفاع تلقائياً عندما يتعرض مبنى لي أو لحليفي للهجوم
func _scramble(delta: float) -> void:
	wait -= delta
	if wait > 0.0:
		return
	wait = 1.0
	var th = Threats.latest(g, team)
	if th == null:
		return
	var e = g.nearest_enemy(th["pos"], team, 30.0 * Data.CELL, false)
	if e != null:
		tgt = e
		forced = true
		path = []


func _fire(target) -> void:
	var a: Dictionary = Data.ARMIES[g.army_of[team]]
	var cls_t: String = "bld" if target.kind == "b" else str(target.def["cls"])
	var vsd: Dictionary = def["vs"]
	var mult: float = float(vsd.get(cls_t, 1.0))
	if mult <= 0.0:
		tgt = null
		return
	var dm: float = float(def["dmg"]) * float(a.get("dmg", 1.0)) * mult
	if g.hostile(team, 0):
		dm *= float(Data.DIFF[g.diff]["dmg"])
	var big: bool = cls == "veh" or type == "bomber"
	var muzzle := position + Vector3(0, 1.0, 0) + Vector3(sin(ta), 0, cos(ta)) * 1.6
	var tp: Vector3 = target.center() + Vector3(randf_range(-0.4, 0.4), 1.0, randf_range(-0.4, 0.4))
	g.spawn_tracer(muzzle, tp, big)
	var vis_ok: bool = g.friendly(team) or g.is_vis(position)
	if vis_ok:
		g.muzzle_flash(muzzle, big)
	target.take_damage(dm, team)
	if type == "bomber":
		_bomb_splash(target, dm)
	if vis_ok:
		Sfx.play("cannon" if (type == "tank" or type == "heavy" or type == "art" or type == "rpg" or type == "bomber") else "shot")


# انفجار القنبلة يصيب ما حول الهدف (بنصف الضرر) فتفيد القاذفة ضد الأرتال والمباني المتجمعة
func _bomb_splash(target, dm: float) -> void:
	var c: Vector3 = target.center()
	var rr: float = 6.0
	for u in g.units.duplicate():
		if u == target or u.dead or u.is_air or not g.hostile(u.team, team):
			continue
		if Vector2(u.position.x - c.x, u.position.z - c.z).length() <= rr:
			u.take_damage(dm * 0.5, team)
	for b in g.blds.duplicate():
		if b == target or b.dead or not g.hostile(b.team, team):
			continue
		if Vector2(b.position.x - c.x, b.position.z - c.z).length() - b.radius_w() <= rr:
			b.take_damage(dm * 0.5, team)
	if g.friendly(team) or g.is_vis(c):
		g.explosion(c + Vector3(0, 0.6, 0), false)
