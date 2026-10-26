class_name Building
extends Node3D

var kind := "b"
var type := "hq"
var team := 0
var g: Main
var def: Dictionary
var cell := Vector2i.ZERO
var size := 3
var hp := 100.0
var max_hp := 100.0
var con := 1.0
var q: Array = []
var qt := 0.0
var cd := 0.0
var rally := Vector2i(-1, -1)
var dead := false
var selected := false
var model: Node3D
var turret: Node3D
var ring: MeshInstance3D
var bar_bg: MeshInstance3D
var bar_fg: MeshInstance3D
var ta := 0.0
var done_fired := false
var hit_cd := 0.0
var fx_t := 0.0
var smoke: CPUParticles3D
var fire: CPUParticles3D
var base_cols := {}
var tint_level := -1
var repairing := false
var rep_fx := 0.0
var scan_t := 0.0
var cached_tgt = null


func setup(main: Main, t: String, tm: int, c: Vector2i, built: bool) -> void:
	g = main
	type = t
	team = tm
	cell = c
	def = Data.BUILDINGS[t]
	size = int(def["size"])
	max_hp = float(def["hp"])
	hp = max_hp
	con = 1.0 if built else 0.0
	var cx: float = (c.x + size / 2.0) * Data.CELL
	var cz: float = (c.y + size / 2.0) * Data.CELL
	position = Vector3(cx, g.terrain.footprint(c, size).y, cz)
	var col: Color = Data.ARMIES[g.army_of[tm]]["color"]
	model = Models.building_model(t, col)
	add_child(model)
	turret = model.get_node_or_null("Turret")
	if not built:
		model.scale.y = 0.08
	rotation.y = 0.0
	_make_ui()


func _make_ui() -> void:
	var rr: float = size * Data.CELL * 0.62
	ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = rr
	tm.outer_radius = rr + 0.25
	ring.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(0.4, 1.0, 0.55)
	ring.material_override = rm
	ring.position.y = 0.2
	ring.visible = false
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	bar_bg = _bar(Color(0, 0, 0, 0.7), 0)
	bar_fg = _bar(Color(0.37, 0.83, 0.42), 1)
	bar_bg.visible = false
	bar_fg.visible = false


func _bar(col: Color, prio: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q2 := QuadMesh.new()
	var w: float = maxf(3.0, size * 1.7)
	q2.size = Vector2(w, 0.5) if prio == 0 else Vector2(w - 0.16, 0.34)
	mi.mesh = q2
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = col
	m.no_depth_test = true
	m.render_priority = prio
	if col.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.position = Vector3(0, 4.2 + size * 1.1, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func set_selected(s: bool) -> void:
	selected = s
	ring.visible = s


func center() -> Vector3:
	return position


func radius_w() -> float:
	return size * Data.CELL * 0.5


func repair_cost() -> int:
	var basis: float = 1200.0 if type == "hq" else float(def["cost"])
	var miss: float = clampf((max_hp - hp) / max_hp, 0.0, 1.0)
	if miss <= 0.001:
		return 0
	return maxi(10, int(ceil(miss * basis * 0.6)))


func start_repair() -> void:
	repairing = true
	rep_fx = 0.0


func take_damage(dm: float, from_team: int) -> void:
	if dead:
		return
	hp -= dm
	if g.friendly(team) and g.hostile(from_team, team):
		g.notify_attack(self)
	if hit_cd <= 0.0 and (g.friendly(team) or visible):
		hit_cd = 0.14
		var rr: float = size * Data.CELL * 0.4
		g.impact(position + Vector3(randf_range(-rr, rr), 1.2 + randf() * size * 0.5, randf_range(-rr, rr)), true)
		Sfx.play("hit")
	if hp <= 0.0:
		die()


func _cache_colors(n: Node) -> void:
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n
		if mi.material_override is StandardMaterial3D:
			var sm: StandardMaterial3D = mi.material_override.duplicate()
			mi.material_override = sm
			base_cols[mi] = sm.albedo_color
	for c in n.get_children():
		_cache_colors(c)


func _damage_fx() -> void:
	var f: float = hp / max_hp
	var lvl := 0
	if f < 0.8:
		lvl = 1
	if f < 0.55:
		lvl = 2
	if f < 0.3:
		lvl = 3
	if lvl != tint_level:
		tint_level = lvl
		if base_cols.is_empty():
			_cache_colors(model)
		var k: float = [0.0, 0.18, 0.35, 0.55][lvl]
		for mi in base_cols.keys():
			if is_instance_valid(mi):
				(mi.material_override as StandardMaterial3D).albedo_color = (base_cols[mi] as Color).darkened(k)
	var ext := Vector3(size * 0.8, 0.2, size * 0.8)
	if lvl >= 2 and smoke == null:
		smoke = g.make_smoke(ext, 10 + size * 4)
		smoke.position = Vector3(0, size * 0.9 + 0.8, 0)
		add_child(smoke)
	if smoke != null:
		smoke.emitting = lvl >= 2
		if lvl == 3 and smoke.amount < 18 + size * 4:
			smoke.amount = 18 + size * 4
	if lvl >= 3 and fire == null:
		fire = g.make_fire(ext, 8 + size * 3)
		fire.position = Vector3(0, size * 0.7 + 0.5, 0)
		add_child(fire)
	if fire != null:
		fire.emitting = lvl >= 3


func die() -> void:
	dead = true
	g.remove_entity(self)
	ring.visible = false
	bar_bg.visible = false
	bar_fg.visible = false
	g.explosion(position + Vector3(0, 1.5, 0), true)
	if g.friendly(team) or visible:
		Sfx.play("boom")
	if base_cols.is_empty():
		_cache_colors(model)
	Models.darken(model, 0.6)
	if smoke != null:
		smoke.emitting = true
	if fire != null:
		fire.emitting = true
	var tw := create_tween()
	tw.tween_property(model, "scale:y", 0.2, 0.9).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(model, "rotation:z", 0.07, 0.9)
	tw.tween_interval(6.0)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	if dead or not g.running:
		return
	hit_cd -= delta
	fx_t -= delta
	if fx_t <= 0.0:
		fx_t = 0.5
		_damage_fx()
	var show_bar: bool = hp < max_hp - 0.5 or selected or con < 1.0
	bar_bg.visible = show_bar
	bar_fg.visible = show_bar
	if con < 1.0:
		con = minf(1.0, con + delta / float(def["bt"]))
		model.scale.y = lerpf(0.08, 1.0, con)
		bar_fg.scale.x = maxf(con, 0.01)
		(bar_fg.material_override as StandardMaterial3D).albedo_color = Color(0.9, 0.7, 0.25)
		if con >= 1.0:
			_on_built()
		return
	if repairing:
		hp = minf(max_hp, hp + max_hp * delta / 8.0)
		rep_fx -= delta
		if rep_fx <= 0.0:
			rep_fx = 0.35
			var rr2: float = size * Data.CELL * 0.4
			g.impact(position + Vector3(randf_range(-rr2, rr2), 0.8 + randf() * size * 0.6, randf_range(-rr2, rr2)), false)
		if hp >= max_hp:
			repairing = false
			if team == 0:
				Sfx.play("repaired")
				g.hud.toast("اكتمل تصليح " + str(def["name"]))
	if show_bar:
		var f: float = clampf(hp / max_hp, 0.0, 1.0)
		bar_fg.scale.x = maxf(f, 0.01)
		(bar_fg.material_override as StandardMaterial3D).albedo_color = Color(0.37, 0.83, 0.42) if f > 0.5 else (Color(0.9, 0.75, 0.25) if f > 0.25 else Color(0.88, 0.3, 0.24))
		if repairing:
			(bar_fg.material_override as StandardMaterial3D).albedo_color = Color(0.3, 0.8, 1.0)
	var train: Array = def["train"]
	if not train.is_empty() and not q.is_empty():
		qt += delta
		var ut: Dictionary = Data.UNITS[q[0]]
		if qt >= float(ut["time"]):
			qt = 0.0
			var t: String = q.pop_front()
			var u: Unit = g.spawn_unit(t, team, g.spawn_pos_near(g.free_spot(self), t))
			if rally.x >= 0 and team == 0:
				u.goto_cell(rally)
			if g.friendly(team) or visible:
				var uc: String = str(Data.UNITS[t]["cls"])
				Sfx.play("spawn_inf" if uc == "inf" else ("spawn_air" if uc == "air" else "spawn_tank"))
	if type == "twr":
		cd -= delta
		var rw: float = float(def["range"]) * Data.CELL
		scan_t -= delta
		if scan_t <= 0.0 or (cached_tgt != null and (not is_instance_valid(cached_tgt) or cached_tgt.dead)):
			scan_t = 0.25
			cached_tgt = g.nearest_enemy(position, team, rw, true)
		var e = cached_tgt
		if e != null and (not is_instance_valid(e) or e.dead):
			e = null
			cached_tgt = null
		if e != null:
			var tp: Vector3 = e.center()
			ta = atan2(tp.x - position.x, tp.z - position.z)
			if turret != null:
				turret.rotation.y = lerp_angle(turret.rotation.y, ta, clampf(delta * 8.0, 0.0, 1.0))
			if cd <= 0.0:
				cd = float(def["cd"])
				var a: Dictionary = Data.ARMIES[g.army_of[team]]
				var muzzle: Vector3 = position + Vector3(0, 1.8, 0) + Vector3(sin(ta), 0, cos(ta)) * 1.8
				g.spawn_tracer(muzzle, tp + Vector3(0, 1.0, 0), false)
				if g.friendly(team) or visible:
					g.muzzle_flash(muzzle, false)
				var tdm: float = float(def["dmg"]) * float(a.get("dmg", 1.0))
				if g.hostile(team, 0):
					tdm *= float(Data.DIFF[g.diff]["dmg"])
				e.take_damage(tdm, team)
				if g.friendly(team) or g.is_vis(position):
					Sfx.play("shot")


func _on_built() -> void:
	if done_fired:
		return
	done_fired = true
	if g.friendly(team) or visible:
		Sfx.play("built")
	if type == "dep":
		g.spawn_unit("truck", team, g.spawn_pos_near(g.free_spot(self), "truck"))
