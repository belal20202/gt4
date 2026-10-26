class_name Main
extends Node3D
## المتحكم الرئيسي: العالم، التحالفات، الإدخال باللمس، الأوامر، الاقتصاد، الضباب الدائم، الحفظ

const SAVE_DIR := "user://saves"
const AUTO_SLOT := "auto"

var world: Node3D
var terrain: Terrain
var rig: RtsCamera
var hud: Hud
var ais: Array = []
var astar: AStarGrid2D
var astar_big: AStarGrid2D
var units: Array = []
var blds: Array = []
var mines: Array = []
var sel: Array = []
var gold: Array = [0.0, 0.0, 0.0, 0.0]
var income: Array = [0.0, 0.0, 0.0, 0.0]
var gain_acc: Array = [0.0, 0.0, 0.0, 0.0]
var army_of: Array = ["red", "blue", "yellow", "white"]
var team_of: Array = [0, -1, 1, -1]
var players: Array = [0, 2]
var mode_key := "1v1"
var human_army := "red"
var boost := 1.0
var map_seed := 0
var diff := "normal"
var time := 0.0
var running := false
var over := false
var mode := ""
var place_type := ""
var amove_next := false
var box_mode := false
var ghost: MeshInstance3D
var explored := PackedByteArray()
var fog_data := PackedByteArray()
var mini_fog := PackedByteArray()
var fog_img: Image
var fog_tex: ImageTexture
var mini_img: Image
var fog_t := 0.0
var hud_t := 0.0
var mini_t := 0.0
var win_t := 0.0
var sep_t := 0.0
var loop_t := 0.0
var inc_t := 0.0
var save_t := 0.0
var cur_slot := ""
var loading_now := false
var pointers := {}
var ignored := {}
var last_c := Vector2.ZERO
var last_d := 1.0
var last_a := 0.0
var last_pos := Vector2.ZERO
var box_active := false
var box_rect := Rect2()
var spiral: Array = []
var mine_seq := 0
var fx_count := 0
var spark_mesh: SphereMesh
var puff_mesh: SphereMesh
var flame_mesh: SphereMesh
var debris_mesh: BoxMesh
var smoke_ramp: Gradient
var fire_ramp: Gradient
var dust_ramp: Gradient
var grow_curve: Curve
var alert_cd := 0.0
var alert_t := 0.0
var alert_pos := Vector3.ZERO
var alert_cell := Vector2i(-1, -1)


func friendly(o: int) -> bool:
	return o >= 0 and team_of[o] == team_of[0]


func hostile(a: int, b: int) -> bool:
	return team_of[a] != team_of[b]


func _ready() -> void:
	randomize()
	get_tree().auto_accept_quit = false
	DisplayServer.screen_set_keep_on(true)
	_build_environment()
	world = Node3D.new()
	add_child(world)
	rig = RtsCamera.new()
	add_child(rig)
	hud = Hud.new()
	add_child(hud)
	hud.setup(self)
	for y in range(-8, 9):
		for x in range(-8, 9):
			spiral.append(Vector2i(x, y))
	spiral.sort_custom(func(a, b): return a.length_squared() < b.length_squared())


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# زر الرجوع: يفتح قائمة الإيقاف أثناء اللعب بدل الخروج المفاجئ
		if running and not over and not loading_now:
			if get_tree().paused:
				resume_game()
			else:
				pause_game()
		elif hud != null and hud.close_overlays():
			pass
		else:
			get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		# حماية من إغلاق النظام للتطبيق: حفظ تلقائي في خانة مستقلة، لا يلمس محفوظاتك
		save_game(false, AUTO_SLOT)


func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.22, 0.42, 0.74)
	sm.sky_horizon_color = Color(0.82, 0.76, 0.62)
	sm.ground_horizon_color = Color(0.8, 0.72, 0.56)
	sm.ground_bottom_color = Color(0.42, 0.36, 0.27)
	sky.sky_material = sm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.83, 0.77, 0.63)
	env.fog_density = 0.0012
	env.glow_enabled = false
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.25
	env.adjustment_contrast = 1.06
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	sun.light_energy = 1.55
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 95.0
	add_child(sun)


# ---------- بدء وإنهاء ----------
func _clear_world() -> void:
	fx_count = 0
	if world != null:
		world.queue_free()
	world = Node3D.new()
	add_child(world)
	for a in ais:
		if is_instance_valid(a):
			a.queue_free()
	ais.clear()
	units.clear()
	blds.clear()
	mines.clear()
	sel.clear()
	pointers.clear()
	ignored.clear()
	ghost = null
	terrain = null


func _on_progress(p: float, text: String) -> void:
	hud.set_progress(p, text)


func _assign_armies(human_key: String) -> void:
	var keys := ["red", "blue", "yellow", "white"]
	army_of = ["", "", "", ""]
	army_of[0] = human_key
	var rest: Array = keys.filter(func(k): return k != human_key)
	if rest.has("blue"):
		rest.erase("blue")
		rest.push_front("blue")
	var enemies: Array = []
	var allies: Array = []
	for o in players:
		if o == 0:
			continue
		if team_of[o] != team_of[0]:
			enemies.append(o)
		else:
			allies.append(o)
	for o in enemies:
		army_of[o] = rest.pop_front()
	for o in allies:
		army_of[o] = rest.pop_front()


func start_game(army_key: String, diff_key: String, mode_in: String, restore := {}) -> void:
	if loading_now:
		return
	loading_now = true
	running = false
	hud.show_loading(true, "")
	hud.set_progress(0.0, "جاري التحضير...")
	await get_tree().process_frame
	await get_tree().process_frame
	_clear_world()
	get_tree().paused = false
	mode_key = mode_in
	var md: Dictionary = Data.MODES[mode_key]
	players = (md["players"] as Array).duplicate()
	team_of = (md["teams"] as Array).duplicate()
	boost = float(md["boost"])
	diff = diff_key
	human_army = army_key
	_assign_armies(army_key)
	gold = [0.0, 0.0, 0.0, 0.0]
	income = [0.0, 0.0, 0.0, 0.0]
	gain_acc = [0.0, 0.0, 0.0, 0.0]
	for o in players:
		gold[o] = 1000.0 + float(Data.ARMIES[army_of[o]].get("gold", 0))
	inc_t = 0.0
	mine_seq = 0
	time = 0.0
	over = false
	mode = ""
	amove_next = false
	box_mode = false
	map_seed = int(restore.get("seed", randi()))
	for o in players:
		if o != 0:
			var a := Ai.new()
			a.g = self
			a.slot = o
			a.reset()
			add_child(a)
			ais.append(a)
	terrain = Terrain.new()
	world.add_child(terrain)
	await terrain.generate(map_seed, Callable(self, "_on_progress"))
	hud.set_progress(0.93, "جاري تجهيز الجيوش والمباني...")
	await get_tree().process_frame
	_setup_fog()
	terrain.set_fog(fog_tex)
	_setup_astar()
	for c in Data.MINES:
		_add_mine(c)
	if restore.is_empty():
		_spawn_initial()
	else:
		_restore(restore)
	_build_minimap_base()
	var b0: Vector2i = Data.BASES[0]
	rig.focus = cell_center(b0 + Vector2i(1, 1))
	rig.yaw = 0.0
	rig.dist = 38.0
	rig.apply()
	hud.set_progress(0.97, "جاري تحضير الموسيقى...")
	await get_tree().process_frame
	Sfx.prepare_music()
	running = true
	update_fog()
	hud.set_toggles(false, false)
	hud.show_hud()
	hud.refresh(true)
	Sfx.start_music()
	hud.set_progress(1.0, "انطلقت المعركة")
	await get_tree().create_timer(0.35).timeout
	hud.show_loading(false)
	loading_now = false
	Sfx.play("go")
	save_t = 0.0
	cur_slot = str(restore.get("slot", ""))
	if cur_slot == AUTO_SLOT:
		cur_slot = ""
	hud.toast("اجمع الذهب بالشاحنات ودمّر مقرات العدو" if restore.is_empty() else "تمت استعادة اللعبة المحفوظة")


func _spawn_initial() -> void:
	var half: int = Data.MAP / 2
	for o in players:
		var b: Vector2i = Data.BASES[o]
		var low: bool = b.y > half
		var dep_off := Vector2i(0, -6) if low else Vector2i(0, 6)
		var bar_off := Vector2i(5, 0) if b.x < half else Vector2i(-5, 0)
		add_building("hq", o, b, true)
		add_building("dep", o, b + dep_off, true)
		add_building("bar", o, b + bar_off, true)
		if hostile(o, 0):
			add_building("fac", o, b + Vector2i(bar_off.x, -4 if low else 4), true)
		var hq = find_hq(o)
		var p: Vector3 = free_spot(hq)
		for i in 3:
			spawn_unit("inf", o, spawn_pos_near(p, "inf"))
		for bd in blds:
			if bd.team == o and bd.type == "dep":
				spawn_unit("truck", o, spawn_pos_near(free_spot(bd), "truck"))


# أقرب نقطة حرة لا تتداخل مع وحدة أخرى ولا مع عائق
func spawn_pos_near(center: Vector3, type: String) -> Vector3:
	var d: Dictionary = Data.UNITS[type]
	if bool(d["air"]):
		return center + Vector3(randf_range(-2.0, 2.0), 0.0, randf_range(-2.0, 2.0))
	var r_new: float = float(d["radius"])
	var big: bool = r_new > 1.2
	for ring in range(0, 9):
		var steps: int = 1 if ring == 0 else 6 + ring * 3
		for k in range(steps):
			var ang: float = TAU * float(k) / float(steps) + float(ring) * 0.7
			var pr: float = float(ring) * 2.6
			var px: float = center.x + cos(ang) * pr
			var pz: float = center.z + sin(ang) * pr
			var c := world_to_cell(Vector3(px, 0.0, pz))
			var blocked: bool = is_solid_big(c) if big else is_solid(c)
			if blocked:
				continue
			if _spot_clear(px, pz, r_new):
				return Vector3(px, terrain.height_at(px, pz), pz)
	return center


func _spot_clear(px: float, pz: float, r_new: float) -> bool:
	for u in units:
		if u.is_air or u.dead:
			continue
		var md: float = r_new + float(u.def["radius"]) + 0.5
		var dx: float = u.position.x - px
		var dz: float = u.position.z - pz
		if dx * dx + dz * dz < md * md:
			return false
	return true


func restart() -> void:
	start_game(hud.picked_army, hud.picked_diff, hud.picked_mode)


func save_and_menu() -> void:
	save_game(true, cur_slot if cur_slot != "" else "")
	to_menu()


func to_menu() -> void:
	cur_slot = ""
	loading_now = false
	hud.show_loading(false)
	Sfx.set_loops(0, 0, 0)
	get_tree().paused = false
	running = false
	_clear_world()
	Sfx.stop_music()
	hud.show_menu()


func pause_game() -> void:
	Sfx.set_loops(0, 0, 0)
	get_tree().paused = true
	hud.show_pause(true)


func resume_game() -> void:
	get_tree().paused = false
	hud.show_pause(false)


func _team_has_hq(t: int) -> bool:
	for b in blds:
		if b.type == "hq" and not b.dead and team_of[b.team] == t:
			return true
	return false


func end_game(win: bool) -> void:
	over = true
	delete_slot(AUTO_SLOT)
	Sfx.play("win" if win else "lose")
	var m: int = int(time)
	var txt := ("دُمّرت كل مقرات العدو" if win else "سقطت كل مقرات قيادتك") + "  ·  المدة %02d:%02d" % [m / 60, m % 60]
	get_tree().create_timer(1.3).timeout.connect(func(): if running: hud.show_end(win, txt))


# ---------- الحفظ والاستعادة (عدة خانات) ----------
func _slot_path(id: String) -> String:
	return SAVE_DIR + "/" + id + ".json"


func read_slot(id: String) -> Dictionary:
	var path := _slot_path(id)
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if parsed is Dictionary:
		var d: Dictionary = parsed
		d["slot"] = id
		return d
	return {}


func delete_slot(id: String) -> void:
	var path := _slot_path(id)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


# قائمة المحفوظات: الأحدث أولاً. كل عنصر: id, ts, date, mode, diff, army, time
func list_saves() -> Array:
	var out: Array = []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var fn := dir.get_next()
	while fn != "":
		if not dir.current_is_dir() and fn.ends_with(".json"):
			var id := fn.get_basename()
			var d := read_slot(id)
			if not d.is_empty():
				out.append({"id": id, "ts": int(d.get("ts", 0)), "date": str(d.get("date", "")), "mode": str(d.get("mode", "1v1")), "diff": str(d.get("diff", "normal")), "army": str(d.get("army", "red")), "time": float(d.get("time", 0.0))})
		fn = dir.get_next()
	dir.list_dir_end()
	out.sort_custom(func(a, b): return int(a["ts"]) > int(b["ts"]))
	return out


# slot_id فارغ = خانة جديدة، وإلا يُستبدل الحفظ الموجود
func save_game(show_msg := true, slot_id := "") -> void:
	if not running or over or loading_now or terrain == null:
		return
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var id := slot_id
	if id == "":
		id = "s%d" % int(Time.get_unix_time_from_system())
		while FileAccess.file_exists(_slot_path(id)):
			id += "x"
	var d := {"v": Data.VERSION, "seed": map_seed, "mode": mode_key, "diff": diff, "army": human_army, "time": time}
	d["ts"] = int(Time.get_unix_time_from_system())
	d["date"] = Time.get_datetime_string_from_system(false, true)
	d["gold"] = gold.duplicate()
	d["fog"] = Marshalls.raw_to_base64(explored)
	var ua: Array = []
	for u in units:
		if not u.dead:
			ua.append({"t": u.type, "o": u.team, "x": snappedf(u.position.x, 0.01), "z": snappedf(u.position.z, 0.01), "hp": snappedf(u.hp, 0.1), "lg": u.load_gold})
	d["units"] = ua
	var ba: Array = []
	for b in blds:
		if not b.dead:
			ba.append({"t": b.type, "o": b.team, "cx": b.cell.x, "cy": b.cell.y, "con": b.con, "hp": snappedf(b.hp, 0.1), "q": b.q.duplicate(), "rx": b.rally.x, "ry": b.rally.y})
	d["buildings"] = ba
	var ma: Array = []
	for m in mines:
		ma.append(m["amount"])
	d["mines"] = ma
	var f := FileAccess.open(_slot_path(id), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d))
		f.close()
		if slot_id != AUTO_SLOT:
			cur_slot = id
		if show_msg:
			hud.toast("تم حفظ اللعبة")
			Sfx.play("saved")


func continue_game(id: String) -> void:
	var d := read_slot(id)
	if d.is_empty():
		return
	start_game(str(d.get("army", "red")), str(d.get("diff", "normal")), str(d.get("mode", "1v1")), d)


func _restore(d: Dictionary) -> void:
	time = float(d.get("time", 0.0))
	var ga: Array = d.get("gold", [])
	for i in range(mini(4, ga.size())):
		gold[i] = float(ga[i])
	var ma: Array = d.get("mines", [])
	for i in range(mini(ma.size(), mines.size())):
		_set_mine_amount(mines[i], float(ma[i]))
	for bd in d.get("buildings", []):
		var built: bool = float(bd["con"]) >= 1.0
		var b := add_building(str(bd["t"]), int(bd["o"]), Vector2i(int(bd["cx"]), int(bd["cy"])), built)
		b.con = float(bd["con"])
		b.hp = float(bd["hp"])
		b.done_fired = built
		if not built:
			b.model.scale.y = lerpf(0.08, 1.0, b.con)
		b.q = (bd.get("q", []) as Array).duplicate()
		if int(bd.get("rx", -1)) >= 0:
			b.rally = Vector2i(int(bd["rx"]), int(bd["ry"]))
	for ud in d.get("units", []):
		var u := spawn_unit(str(ud["t"]), int(ud["o"]), Vector3(float(ud["x"]), 0.0, float(ud["z"])))
		u.hp = float(ud["hp"])
		u.load_gold = float(ud.get("lg", 0.0))
	var raw: PackedByteArray = Marshalls.base64_to_raw(str(d.get("fog", "")))
	if raw.size() == explored.size():
		explored = raw
		var n: int = Data.MAP
		for i in n * n:
			fog_data[i] = 255 if explored[i] == 1 else 0
			mini_fog[i * 4 + 3] = 0 if explored[i] == 1 else 235
		_push_fog_textures()


# ---------- الشبكة والمسارات ----------
func _new_grid() -> AStarGrid2D:
	var n: int = Data.MAP
	var ag := AStarGrid2D.new()
	ag.region = Rect2i(0, 0, n, n)
	ag.cell_size = Vector2(1, 1)
	ag.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	ag.update()
	return ag


func _setup_astar() -> void:
	var n: int = Data.MAP
	astar = _new_grid()
	astar_big = _new_grid()
	for y in n:
		for x in n:
			var t: int = terrain.types[y * n + x]
			if t == 2 or t == 3 or t == 5 or t == 6:
				astar.set_point_solid(Vector2i(x, y), true)
	for y in n:
		for x in n:
			if astar.is_point_solid(Vector2i(x, y)):
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var p := Vector2i(x + dx, y + dy)
						if astar_big.region.has_point(p):
							astar_big.set_point_solid(p, true)


func _set_solid_rect(c: Vector2i, s: int, v: bool) -> void:
	for y in range(c.y, c.y + s):
		for x in range(c.x, c.x + s):
			var p := Vector2i(x, y)
			if astar.region.has_point(p):
				astar.set_point_solid(p, v)
	for y in range(c.y - 2, c.y + s + 2):
		for x in range(c.x - 2, c.x + s + 2):
			var p2 := Vector2i(x, y)
			if not astar_big.region.has_point(p2):
				continue
			var any := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var q := Vector2i(x + dx, y + dy)
					if astar.region.has_point(q) and astar.is_point_solid(q):
						any = true
			astar_big.set_point_solid(p2, any)


func is_solid(c: Vector2i) -> bool:
	return not astar.region.has_point(c) or astar.is_point_solid(c)


func is_solid_big(c: Vector2i) -> bool:
	return not astar_big.region.has_point(c) or astar_big.is_point_solid(c)


func blocked_for(u: Unit, x: float, z: float) -> bool:
	var c := Vector2i(clampi(int(x / Data.CELL), 0, Data.MAP - 1), clampi(int(z / Data.CELL), 0, Data.MAP - 1))
	if float(u.def["radius"]) > 1.2:
		return astar_big.is_point_solid(c)
	return astar.is_point_solid(c)


# منع تداخل الوحدات (جنود، آليات، طائرات): شبكة مكانية + دفع متبادل على مرحلتين.
# الأخف يتحرك أكثر من الأثقل، والطائرات تُفصل عن بعضها فقط (ولا تتأثر بالأرضيات).
func _separate() -> void:
	for _i in range(2):
		_separate_once()


func _separate_once() -> void:
	var grid := {}
	for u in units:
		if u.dead:
			continue
		var k := Vector2i(int(u.position.x / 8.0), int(u.position.z / 8.0))
		if grid.has(k):
			grid[k].append(u)
		else:
			grid[k] = [u]
	var nbr := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1)]
	for k in grid.keys():
		var arr: Array = grid[k]
		for i in range(arr.size()):
			for j in range(i + 1, arr.size()):
				_push_pair(arr[i], arr[j])
		for o in nbr:
			var ok: Vector2i = k + o
			if not grid.has(ok):
				continue
			var arr2: Array = grid[ok]
			for a in arr:
				for b in arr2:
					_push_pair(a, b)


func _try_move(u: Unit, mx: float, mz: float) -> void:
	var nx: float = u.position.x + mx
	var nz: float = u.position.z + mz
	if u.is_air or not blocked_for(u, nx, nz):
		u.position.x = nx
		u.position.z = nz
	elif not blocked_for(u, nx, u.position.z):
		u.position.x = nx
	elif not blocked_for(u, u.position.x, nz):
		u.position.z = nz


func _push_pair(a: Unit, b: Unit) -> void:
	if a.is_air != b.is_air:
		return
	if a.is_air and absf(a.alt - b.alt) > 2.5:
		return
	var ra: float = float(a.def["radius"])
	var rb: float = float(b.def["radius"])
	var dx: float = b.position.x - a.position.x
	var dz: float = b.position.z - a.position.z
	var md: float = ra + rb + 0.4
	var d2: float = dx * dx + dz * dz
	if d2 >= md * md:
		return
	var d: float = sqrt(d2)
	var ux: float
	var uz: float
	if d < 0.01:
		var ang: float = randf() * TAU
		ux = cos(ang)
		uz = sin(ang)
		d = 0.0
	else:
		ux = dx / d
		uz = dz / d
	var p: float = md - d
	var ma: float = ra * ra
	var mb: float = rb * rb
	var fa: float = mb / (ma + mb)
	var fb: float = ma / (ma + mb)
	_try_move(a, -ux * p * fa, -uz * p * fa)
	_try_move(b, ux * p * fb, uz * p * fb)


func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(clampi(int(p.x / Data.CELL), 0, Data.MAP - 1), clampi(int(p.z / Data.CELL), 0, Data.MAP - 1))


func cell_center(c: Vector2i) -> Vector3:
	var x: float = (c.x + 0.5) * Data.CELL
	var z: float = (c.y + 0.5) * Data.CELL
	return Vector3(x, terrain.height_at(x, z), z)


func nearest_free(c: Vector2i, big := false, max_r := 8) -> Vector2i:
	var solid: bool = is_solid_big(c) if big else is_solid(c)
	if not solid:
		return c
	for r in range(1, max_r + 1):
		var best := Vector2i(-1, -1)
		var bd := 1e9
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var nc := c + Vector2i(dx, dy)
				var sn: bool = is_solid_big(nc) if big else is_solid(nc)
				if sn:
					continue
				var d: float = Vector2(dx, dy).length()
				if d < bd:
					bd = d
					best = nc
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)


func find_path_for(u: Unit, to_cell: Vector2i) -> Array:
	if u.is_air:
		var cc := cell_center(Vector2i(clampi(to_cell.x, 0, Data.MAP - 1), clampi(to_cell.y, 0, Data.MAP - 1)))
		return [cc]
	var big: bool = float(u.def["radius"]) > 1.2
	var grid: AStarGrid2D = astar_big if big else astar
	var s := nearest_free(world_to_cell(u.position), big)
	var gcell := nearest_free(to_cell, big)
	if s.x < 0 or gcell.x < 0:
		return []
	var ids: Array = grid.get_id_path(s, gcell)
	var out: Array = []
	for i in range(1, ids.size()):
		out.append(cell_center(ids[i]))
	return out


# ---------- الكيانات ----------
func spawn_unit(type: String, team: int, pos: Vector3) -> Unit:
	var u := Unit.new()
	u.setup(self, type, team, pos)
	world.add_child(u)
	units.append(u)
	return u


func add_building(type: String, team: int, c: Vector2i, built: bool) -> Building:
	var b := Building.new()
	b.setup(self, type, team, c, built)
	world.add_child(b)
	blds.append(b)
	_set_solid_rect(c, b.size, true)
	return b


func remove_entity(e) -> void:
	if e.kind == "u":
		units.erase(e)
	else:
		blds.erase(e)
		_set_solid_rect(e.cell, e.size, false)
	sel.erase(e)


func find_hq(team: int):
	for b in blds:
		if b.team == team and b.type == "hq" and not b.dead:
			return b
	return null


func free_spot(b: Building) -> Vector3:
	var cx: float = b.cell.x + b.size / 2.0
	var cy: float = b.cell.y + b.size / 2.0
	var other := Vector2(Data.MAP / 2.0, Data.MAP / 2.0)
	var best := Vector2i(-1, -1)
	var bd := 1e9
	var r0: int = int(ceil(b.size / 2.0)) + 1
	for r in range(r0, 12):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := Vector2i(int(cx) + dx, int(cy) + dy)
				if is_solid_big(c):
					continue
				var d: float = Vector2(c).distance_to(other)
				if d < bd:
					bd = d
					best = c
		if best.x >= 0:
			break
	if best.x < 0:
		return b.position + Vector3(0, 0, b.size * Data.CELL)
	return cell_center(best)


func can_place(owner_slot: int, type: String, c: Vector2i) -> bool:
	var s: int = int(Data.BUILDINGS[type]["size"])
	var n: int = Data.MAP
	if c.x < 1 or c.y < 1 or c.x + s > n - 1 or c.y + s > n - 1:
		return false
	var fp: Vector2 = terrain.footprint(c, s)
	if fp.y - fp.x > 1.1:
		return false
	for y in range(c.y, c.y + s):
		for x in range(c.x, c.x + s):
			var i: int = y * n + x
			if astar.is_point_solid(Vector2i(x, y)) or terrain.types[i] == 4 or terrain.build_block[i] == 1:
				return false
			if owner_slot == 0 and explored[i] == 0:
				return false
	for m in mines:
		var mc: Vector2i = m["cell"]
		if c.x < mc.x + 3 and c.x + s > mc.x - 1 and c.y < mc.y + 3 and c.y + s > mc.y - 1:
			return false
	var lim: float = 18.0 if owner_slot == 0 else 26.0
	for b in blds:
		if b.team == owner_slot and not b.dead and Vector2(c).distance_to(Vector2(b.cell)) <= lim:
			return true
	return false


func queue_unit(b, type: String) -> bool:
	var cost: float = float(Data.UNITS[type]["cost"])
	if gold[b.team] < cost or b.q.size() >= 6:
		return false
	gold[b.team] -= cost
	b.q.append(type)
	return true


func train(b, type: String) -> void:
	if queue_unit(b, type):
		var uc: String = str(Data.UNITS[type]["cls"])
		if type == "truck":
			Sfx.play("train_truck")
		elif uc == "inf":
			Sfx.play("train_inf")
		elif uc == "air":
			Sfx.play("train_air")
		else:
			Sfx.play("train_tank")
	else:
		hud.toast("الذهب غير كافٍ")
		Sfx.play("bad")


# تنبيه الهجوم على المدينة
func notify_attack(b) -> void:
	if alert_cd > 0.0:
		return
	alert_pos = b.position
	alert_cell = world_to_cell(b.position)
	alert_t = 6.0
	if b.team == 0:
		alert_cd = 7.0
		hud.show_alert("تنبيه! مدينتك تتعرض للهجوم", b.position)
	else:
		alert_cd = 12.0
		hud.show_alert("مدينة حليفك تتعرض للهجوم", b.position)
	Sfx.play("alert")


func goto_pos(p: Vector3) -> void:
	rig.focus = Vector3(p.x, 0.0, p.z)
	rig.apply()


func repair_building(b) -> void:
	if b == null or b.dead or b.team != 0 or b.con < 1.0:
		return
	if b.repairing:
		return
	var cost: int = b.repair_cost()
	if cost <= 0:
		hud.toast("المبنى سليم")
		return
	if gold[0] < float(cost):
		hud.toast("الذهب غير كافٍ للتصليح")
		Sfx.play("bad")
		return
	gold[0] -= float(cost)
	b.start_repair()
	Sfx.play("repair")
	hud.toast("جارٍ تصليح " + str(b.def["name"]))
	hud.refresh(true)


func nearest_enemy(pos: Vector3, team: int, rad: float, can_air: bool, air_first := false):
	var best = null
	var bd := rad * rad
	var best_air = null
	var bad := rad * rad
	var side_friendly: bool = friendly(team)
	for u in units:
		if u.dead or not hostile(u.team, team):
			continue
		if not can_air and u.is_air:
			continue
		if side_friendly and not _explored_at(u.position):
			continue
		var d: float = Vector2(u.position.x - pos.x, u.position.z - pos.z).length_squared()
		if d < bd:
			bd = d
			best = u
		if air_first and u.is_air and d < bad:
			bad = d
			best_air = u
	if best_air != null:
		return best_air
	if best != null:
		return best
	var bb = null
	var bbd := rad * rad
	for b in blds:
		if b.dead or not hostile(b.team, team):
			continue
		if side_friendly and not _explored_at(b.position):
			continue
		var e: float = maxf(0.0, Vector2(b.position.x - pos.x, b.position.z - pos.z).length() - b.radius_w())
		if e * e < bbd:
			bbd = e * e
			bb = b
	return bb


# ---------- المناجم ----------
func _add_mine(c: Vector2i) -> void:
	var node := Node3D.new()
	var cx: float = (c.x + 1) * Data.CELL
	var cz: float = (c.y + 1) * Data.CELL
	node.position = Vector3(cx, terrain.height_at(cx, cz), cz)
	world.add_child(node)
	var gold_mat := Models.mat(Color(1.0, 0.78, 0.2), 0.25, 0.6)
	gold_mat.emission_enabled = true
	gold_mat.emission = Color(0.55, 0.38, 0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = c.x * 131 + c.y
	for i in 9:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		var r: float = rng.randf_range(0.35, 0.8)
		sm.radius = r
		sm.height = r * 1.7
		sm.radial_segments = 5
		sm.rings = 3
		mi.mesh = sm
		mi.material_override = gold_mat
		mi.position = Vector3(rng.randf_range(-1.7, 1.7), r * 0.5, rng.randf_range(-1.7, 1.7))
		mi.rotation = Vector3(rng.randf() * 3.0, rng.randf() * 3.0, 0)
		node.add_child(mi)
	Models.cyl(node, 2.2, 2.6, 0.3, Vector3(0, 0.1, 0), Color(0.3, 0.22, 0.12), 0.95, 0.0)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 3.3
	tm.outer_radius = 3.6
	ring.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color.WHITE
	ring.material_override = rm
	ring.position.y = 0.25
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(ring)
	mine_seq += 1
	mines.append({"id": mine_seq, "cell": c, "amount": Data.MINE_GOLD, "node": node, "ring": ring, "pos": Vector2(cx, cz)})
	_set_solid_rect(c, 2, true)


func truck_count(team: int) -> int:
	var k := 0
	for u in units:
		if u.team == team and u.is_truck and not u.dead:
			k += 1
	return k


func mine_by_id(id: int):
	for m in mines:
		if m["id"] == id:
			return m
	return null


func _set_mine_amount(m: Dictionary, amt: float) -> void:
	m["amount"] = amt
	var f: float = clampf(amt / Data.MINE_GOLD, 0.0, 1.0)
	m["node"].scale = Vector3(1.0, 0.35 + 0.65 * f, 1.0)
	if amt <= 0.0:
		(m["ring"].material_override as StandardMaterial3D).albedo_color = Color(0.4, 0.4, 0.4)


func take_from_mine(m: Dictionary, take: float) -> void:
	_set_mine_amount(m, float(m["amount"]) - take)


func nearest_depot(u: Unit):
	var best = null
	var bd := 1e9
	for b in blds:
		if b.team != u.team or b.type != "dep" or b.dead or b.con < 1.0:
			continue
		var d: float = Vector2(b.position.x - u.position.x, b.position.z - u.position.z).length()
		if d < bd:
			bd = d
			best = b
	return best


func pick_mine_for(u: Unit):
	var best = null
	var bs := 1e9
	var dep = nearest_depot(u)
	var from := Vector2(u.position.x, u.position.z)
	if dep != null:
		from = Vector2(dep.position.x, dep.position.z)
	for m in mines:
		if float(m["amount"]) <= 0.0:
			continue
		var cnt := 0
		for o in units:
			if o != u and o.is_truck and o.team == u.team and o.mine_id == m["id"] and o.state != "idle":
				cnt += 1
		var score: float = from.distance_to(m["pos"]) + cnt * 28.0
		if score < bs:
			bs = score
			best = m
	return best


func deliver(team: int, amount: float) -> void:
	var a: Dictionary = Data.ARMIES[army_of[team]]
	var mult: float = float(a.get("inc", 1.0))
	if hostile(team, 0):
		mult *= float(Data.DIFF[diff]["gm"]) * boost
	elif team != 0:
		mult *= 0.9
	var v: float = amount * mult
	gold[team] += v
	gain_acc[team] += v
	if team == 0:
		Sfx.play("deliver")


# ---------- الضباب الدائم: أي منطقة تكتشفها تبقى ظاهرة ----------
func _setup_fog() -> void:
	var n: int = Data.MAP
	explored = PackedByteArray()
	explored.resize(n * n)
	explored.fill(0)
	fog_data = PackedByteArray()
	fog_data.resize(n * n)
	fog_data.fill(0)
	mini_fog = PackedByteArray()
	mini_fog.resize(n * n * 4)
	for i in n * n:
		mini_fog[i * 4] = 4
		mini_fog[i * 4 + 1] = 4
		mini_fog[i * 4 + 2] = 8
		mini_fog[i * 4 + 3] = 235
	fog_img = Image.create_from_data(n, n, false, Image.FORMAT_R8, fog_data)
	fog_tex = ImageTexture.create_from_image(fog_img)


func is_vis(pos: Vector3) -> bool:
	return _explored_at(pos)


func _explored_at(pos: Vector3) -> bool:
	var c := world_to_cell(pos)
	return explored[c.y * Data.MAP + c.x] == 1


func _mark(pos: Vector3, r: float) -> bool:
	var n: int = Data.MAP
	var cx: float = pos.x / Data.CELL
	var cz: float = pos.z / Data.CELL
	var r2: float = r * r
	var changed := false
	for y in range(maxi(0, int(cz - r)), mini(n - 1, int(cz + r)) + 1):
		for x in range(maxi(0, int(cx - r)), mini(n - 1, int(cx + r)) + 1):
			if (x + 0.5 - cx) * (x + 0.5 - cx) + (y + 0.5 - cz) * (y + 0.5 - cz) <= r2:
				var i: int = y * n + x
				if explored[i] == 0:
					explored[i] = 1
					fog_data[i] = 255
					mini_fog[i * 4 + 3] = 0
					changed = true
	return changed


func _push_fog_textures() -> void:
	var n: int = Data.MAP
	fog_img = Image.create_from_data(n, n, false, Image.FORMAT_R8, fog_data)
	fog_tex.update(fog_img)
	hud.update_mini_fog(Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, mini_fog))


func update_fog() -> void:
	var dirty := false
	for u in units:
		if friendly(u.team):
			if _mark(u.position, float(u.def["vis"])):
				dirty = true
	for b in blds:
		if friendly(b.team):
			if _mark(b.position, float(b.def["vis"])):
				dirty = true
	if dirty:
		_push_fog_textures()
	for u in units:
		if not friendly(u.team):
			u.visible = _explored_at(u.position)
	for b in blds:
		if not friendly(b.team):
			b.visible = _explored_at(b.position)


# ---------- الخريطة المصغرة (ثلاث طبقات: أرض + ضباب + نقاط) ----------
func _build_minimap_base() -> void:
	var n: int = Data.MAP
	var bytes := PackedByteArray()
	bytes.resize(n * n * 4)
	for i in n * n:
		var t: int = terrain.types[i]
		var c := Color(0.82, 0.70, 0.48)
		if t == 1:
			c = Color(0.42, 0.56, 0.26)
		elif t == 2:
			c = Color(0.45, 0.38, 0.31)
		elif t == 3:
			c = Color(0.16, 0.42, 0.6)
		elif t == 4:
			c = Color(0.42, 0.32, 0.22)
		elif t == 5:
			c = Color(0.2, 0.38, 0.16)
		elif t == 6:
			c = Color(0.7, 0.6, 0.42)
		bytes[i * 4] = int(c.r * 255.0)
		bytes[i * 4 + 1] = int(c.g * 255.0)
		bytes[i * 4 + 2] = int(c.b * 255.0)
		bytes[i * 4 + 3] = 255
	hud.set_mini_base(Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, bytes))


func _px(x: int, y: int, c: Color) -> void:
	var n: int = Data.MAP
	if x >= 0 and y >= 0 and x < n and y < n:
		mini_img.set_pixel(x, y, c)


func _update_minimap() -> void:
	var n: int = Data.MAP
	mini_img = Image.create(n, n, false, Image.FORMAT_RGBA8)
	for m in mines:
		var mc: Vector2i = m["cell"]
		if explored[mc.y * n + mc.x] == 1:
			var col := Color(1.0, 0.82, 0.2) if float(m["amount"]) > 0.0 else Color(0.5, 0.5, 0.5)
			for dy in 3:
				for dx in 3:
					_px(mc.x + dx, mc.y + dy, col)
	for b in blds:
		if friendly(b.team) or _explored_at(b.position):
			var col2: Color = Data.ARMIES[army_of[b.team]]["color"]
			for dy in b.size + 1:
				for dx in b.size + 1:
					_px(b.cell.x + dx, b.cell.y + dy, col2)
	for u in units:
		if friendly(u.team) or _explored_at(u.position):
			var c2 := world_to_cell(u.position)
			var col3: Color = Data.ARMIES[army_of[u.team]]["color"]
			for dy in 2:
				for dx in 2:
					_px(c2.x + dx, c2.y + dy, col3)
	if alert_t > 0.0 and int(alert_t * 3.0) % 2 == 0 and alert_cell.x >= 0:
		for dy in range(-4, 5):
			for dx in range(-4, 5):
				var rr: int = absi(dx) + absi(dy)
				if rr >= 5 and rr <= 6:
					_px(alert_cell.x + dx, alert_cell.y + dy, Color(1.0, 0.2, 0.15))
	var fc := world_to_cell(rig.focus)
	var hw: int = int(rig.dist * 0.93 / Data.CELL)
	var hh: int = int(rig.dist * 0.65 / Data.CELL)
	for x in range(fc.x - hw, fc.x + hw + 1):
		_px(x, fc.y - hh, Color.WHITE)
		_px(x, fc.y + hh, Color.WHITE)
	for y in range(fc.y - hh, fc.y + hh + 1):
		_px(fc.x - hw, y, Color.WHITE)
		_px(fc.x + hw, y, Color.WHITE)
	hud.update_mini_dots(mini_img)


func minimap_goto(uv: Vector2) -> void:
	var ws: float = Data.MAP * Data.CELL
	rig.focus = Vector3(clampf(uv.x, 0.0, 1.0) * ws, 0, clampf(uv.y, 0.0, 1.0) * ws)
	rig.apply()


# ---------- التحديد والأوامر ----------
func selection_sig() -> String:
	var s := mode + ":" + place_type + ":"
	for e in sel:
		s += str(e.get_instance_id()) + ","
	if sel.is_empty():
		s += str(blds.size())
	return s


func set_sel(arr: Array) -> void:
	for e in sel:
		if is_instance_valid(e):
			e.set_selected(false)
	sel = arr
	for e in sel:
		e.set_selected(true)
	hud.refresh(true)


func clear_selection() -> void:
	mode = ""
	if ghost != null:
		ghost.queue_free()
		ghost = null
	set_sel([])


func select_all() -> void:
	var a: Array = units.filter(func(u): return u.team == 0 and not u.dead and not u.is_truck)
	set_sel(a)
	hud.toast("%d وحدة" % a.size())
	Sfx.play("click")


func toggle_amove() -> void:
	amove_next = not amove_next
	hud.set_toggles(amove_next, box_mode)
	if amove_next:
		hud.toast("اضغط الأرض لتتحرك وتهاجم")


func toggle_box() -> void:
	box_mode = not box_mode
	hud.set_toggles(amove_next, box_mode)
	hud.toast("اسحب لرسم إطار التحديد" if box_mode else "السحب يحرك الكاميرا")


func stop_selected() -> void:
	for e in sel:
		if e.kind == "u":
			e.path = []
			e.tgt = null
			e.amove = false
	Sfx.play("click")


func order_move(us: Array, wp: Vector3, am: bool) -> void:
	var base := world_to_cell(wp)
	var k := 0
	for u in us:
		if u.is_truck:
			continue
		var big: bool = float(u.def["radius"]) > 1.2
		var step: int = 2 if big else 1
		var goal := Vector2i(-1, -1)
		while k < spiral.size():
			var o: Vector2i = spiral[k]
			k += 1
			var c := base + o * step
			var blocked: bool = is_solid_big(c) if big else is_solid(c)
			if not blocked:
				goal = c
				break
		if goal.x < 0:
			goal = base
		u.tgt = null
		u.forced = false
		u.amove = am
		u.dest = goal
		u.goto_cell(goal)


func begin_place(type: String) -> void:
	if gold[0] < float(Data.BUILDINGS[type]["cost"]):
		hud.toast("الذهب غير كافٍ")
		Sfx.play("bad")
		return
	set_sel([])
	mode = "place"
	place_type = type
	if ghost != null:
		ghost.queue_free()
	ghost = MeshInstance3D.new()
	var bm := BoxMesh.new()
	var s: float = float(Data.BUILDINGS[type]["size"]) * Data.CELL
	bm.size = Vector3(s, 2.0, s)
	ghost.mesh = bm
	var gm := StandardMaterial3D.new()
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color = Color(0.3, 1, 0.45, 0.45)
	ghost.material_override = gm
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(ghost)
	hud.refresh(true)
	Sfx.play("click")


func cancel_place() -> void:
	clear_selection()


func _place_cell(gp: Vector3, type: String) -> Vector2i:
	var s: float = float(Data.BUILDINGS[type]["size"])
	return Vector2i(int(gp.x / Data.CELL - s / 2.0 + 0.5), int(gp.z / Data.CELL - s / 2.0 + 0.5))


func try_place(gp: Vector3) -> void:
	var cost: float = float(Data.BUILDINGS[place_type]["cost"])
	if gold[0] < cost:
		hud.toast("الذهب غير كافٍ")
		Sfx.play("bad")
		return
	var c := _place_cell(gp, place_type)
	if not can_place(0, place_type, c):
		hud.toast("لا يمكن البناء هنا (شجر أو حجر أو أرض غير مستوية)")
		Sfx.play("bad")
		return
	gold[0] -= cost
	add_building(place_type, 0, c, false)
	Sfx.play("place")
	clear_selection()


# ---------- الإدخال ----------
func ground_at(sp: Vector2):
	var cam: Camera3D = rig.cam
	var from: Vector3 = cam.project_ray_origin(sp)
	var to: Vector3 = from + cam.project_ray_normal(sp) * 900.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	var r: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return null
	return r["position"]


func _px_radius(p3: Vector3, r: float) -> float:
	var cam: Camera3D = rig.cam
	var s1: Vector2 = cam.unproject_position(p3)
	var s2: Vector2 = cam.unproject_position(p3 + cam.global_transform.basis.x * r)
	return s1.distance_to(s2)


func _pick(sp: Vector2):
	var cam: Camera3D = rig.cam
	var best = null
	var bd := 1e9
	for u in units:
		if u.dead or (not friendly(u.team) and not _explored_at(u.position)):
			continue
		var p3: Vector3 = u.position + Vector3(0, 1.0, 0)
		if cam.is_position_behind(p3):
			continue
		var d: float = cam.unproject_position(p3).distance_to(sp)
		var lim: float = maxf(_px_radius(p3, float(u.def["radius"]) + 0.5), 30.0)
		if d < lim and d < bd:
			bd = d
			best = u
	if best != null:
		return best
	for b in blds:
		if b.dead or (not friendly(b.team) and not _explored_at(b.position)):
			continue
		var p3b: Vector3 = b.position + Vector3(0, 1.0, 0)
		if cam.is_position_behind(p3b):
			continue
		var d2: float = cam.unproject_position(p3b).distance_to(sp)
		var lim2: float = maxf(_px_radius(p3b, b.radius_w()), 36.0)
		if d2 < lim2 and d2 < bd:
			bd = d2
			best = b
	return best


func _marker(pos: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.7
	tm.outer_radius = 0.95
	mi.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	mi.material_override = m
	mi.position = pos + Vector3(0, 0.3, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)
	var tw := create_tween()
	tw.tween_property(mi, "scale", Vector3(2.2, 1, 2.2), 0.45)
	tw.tween_callback(func(): if is_instance_valid(mi): mi.queue_free())


func _tap(sp: Vector2, btn: int) -> void:
	var gp = ground_at(sp)
	if mode == "place":
		if gp != null:
			try_place(gp)
		return
	var hit = _pick(sp)
	if btn != 2 and hit != null and hit.team == 0:
		set_sel([hit])
		Sfx.play("click")
		return
	var su: Array = sel.filter(func(e): return e.kind == "u" and not e.is_truck)
	if not su.is_empty():
		if hit != null and hostile(hit.team, 0):
			for u in su:
				u.tgt = hit
				u.forced = true
				u.path = []
				u.amove = false
			_marker(hit.position, Color(1, 0.4, 0.3))
			Sfx.play("click")
		elif gp != null:
			order_move(su, gp, amove_next)
			_marker(gp, Color(0.4, 1, 0.55))
			Sfx.play("click")
			if amove_next:
				toggle_amove()
	elif sel.size() == 1 and sel[0].kind == "b" and hit == null and gp != null:
		var d: Dictionary = sel[0].def
		if not (d["train"] as Array).is_empty():
			sel[0].rally = world_to_cell(gp)
			_marker(gp, Color(0.4, 0.8, 1))
			hud.toast("نقطة التجمع")
	elif hit == null or hit.team != 0:
		set_sel([])


func _box_select() -> void:
	var cam: Camera3D = rig.cam
	var a: Array = []
	for u in units:
		if u.team == 0 and not u.dead and not u.is_truck and not cam.is_position_behind(u.position):
			if box_rect.has_point(cam.unproject_position(u.position)):
				a.append(u)
	set_sel(a)
	if not a.is_empty():
		Sfx.play("click")
		hud.toast("%d وحدة محددة" % a.size())


func _ptr_down(id: int, pos: Vector2, btn: int) -> void:
	if hud.is_over_ui(pos):
		ignored[id] = true
		return
	pointers[id] = {"pos": pos, "start": pos, "moved": false, "btn": btn}
	if pointers.size() == 2:
		var ks: Array = pointers.keys()
		var a: Vector2 = pointers[ks[0]]["pos"]
		var b: Vector2 = pointers[ks[1]]["pos"]
		last_c = (a + b) / 2.0
		last_d = maxf(a.distance_to(b), 1.0)
		last_a = (b - a).angle()
		box_active = false
		hud.set_box(Rect2(), false)


func _ptr_move(id: int, pos: Vector2) -> void:
	if ignored.has(id) or not pointers.has(id):
		return
	var p: Dictionary = pointers[id]
	var dl: Vector2 = pos - p["pos"]
	p["pos"] = pos
	if pointers.size() >= 2:
		var ks: Array = pointers.keys()
		var a: Vector2 = pointers[ks[0]]["pos"]
		var b: Vector2 = pointers[ks[1]]["pos"]
		var c: Vector2 = (a + b) / 2.0
		var d: float = maxf(a.distance_to(b), 1.0)
		var ang: float = (b - a).angle()
		rig.zoom_by(last_d / d)
		rig.rotate_by(wrapf(ang - last_a, -PI, PI))
		rig.pan(c - last_c)
		last_c = c
		last_d = d
		last_a = ang
		p["moved"] = true
		return
	if not p["moved"] and pos.distance_to(p["start"]) > 14.0:
		p["moved"] = true
	if p["moved"]:
		if box_mode or Input.is_key_pressed(KEY_SHIFT):
			box_active = true
			box_rect = Rect2(p["start"], Vector2.ZERO).expand(pos)
			hud.set_box(box_rect, true)
		else:
			rig.pan(dl)


func _ptr_up(id: int, _pos: Vector2) -> void:
	if ignored.erase(id):
		return
	if not pointers.has(id):
		return
	var p: Dictionary = pointers[id]
	var was_single: bool = pointers.size() == 1
	pointers.erase(id)
	if pointers.size() == 1:
		for k in pointers:
			pointers[k]["moved"] = true
	if not was_single:
		return
	if box_active:
		_box_select()
		hud.set_box(Rect2(), false)
		box_active = false
		return
	if not p["moved"]:
		_tap(p["pos"], int(p["btn"]))


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventScreenTouch:
		last_pos = event.position
		if event.pressed:
			_ptr_down(event.index, event.position, 0)
		else:
			_ptr_up(event.index, event.position)
	elif event is InputEventScreenDrag:
		last_pos = event.position
		_ptr_move(event.index, event.position)
	elif event is InputEventMouseButton:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		last_pos = event.position
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			rig.zoom_by(0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			rig.zoom_by(1.1)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_ptr_down(100, event.position, 0)
			else:
				_ptr_up(100, event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_ptr_down(101, event.position, 2)
			else:
				_ptr_up(101, event.position)
	elif event is InputEventMouseMotion:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		last_pos = event.position
		if pointers.has(100):
			_ptr_move(100, event.position)


# ---------- الحلقة ----------
func _process(delta: float) -> void:
	if not running:
		return
	time += delta
	inc_t += delta
	if inc_t >= 1.0:
		inc_t = 0.0
		for o in players:
			income[o] = lerpf(income[o], gain_acc[o], 0.12)
			gain_acc[o] = 0.0
	loop_t -= delta
	if loop_t <= 0.0:
		loop_t = 0.3
		var cs := 0
		var ce := 0
		var ca := 0
		for u in units:
			if not u.moving or u.is_truck or (not friendly(u.team) and not u.visible):
				continue
			if u.is_air:
				ca += 1
			elif u.cls == "inf":
				cs += 1
			else:
				ce += 1
		Sfx.set_loops(cs, ce, ca)
	if not over:
		for a in ais:
			a.tick(delta)
	alert_cd -= delta
	alert_t -= delta
	sep_t -= delta
	if sep_t <= 0.0:
		sep_t = 0.04
		_separate()
	var spd: float = 22.0 * delta
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		rig.pan(Vector2(spd * 18.0, 0))
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		rig.pan(Vector2(-spd * 18.0, 0))
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		rig.pan(Vector2(0, spd * 18.0))
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		rig.pan(Vector2(0, -spd * 18.0))
	if Input.is_key_pressed(KEY_Q):
		rig.rotate_by(-delta * 1.4)
	if Input.is_key_pressed(KEY_E):
		rig.rotate_by(delta * 1.4)
	rig.focus.y = lerpf(rig.focus.y, terrain.height_at(rig.focus.x, rig.focus.z), 0.1)
	rig.apply()
	if mode == "place" and ghost != null:
		var gp = ground_at(last_pos)
		if gp != null:
			var c := _place_cell(gp, place_type)
			var s: int = int(Data.BUILDINGS[place_type]["size"])
			var cc := Vector2i(clampi(c.x, 1, Data.MAP - s - 2), clampi(c.y, 1, Data.MAP - s - 2))
			ghost.position = Vector3((cc.x + s / 2.0) * Data.CELL, terrain.footprint(cc, s).y + 1.0, (cc.y + s / 2.0) * Data.CELL)
			var ok: bool = can_place(0, place_type, c)
			(ghost.material_override as StandardMaterial3D).albedo_color = Color(0.3, 1, 0.45, 0.45) if ok else Color(1, 0.3, 0.25, 0.45)
	fog_t -= delta
	if fog_t <= 0.0:
		fog_t = 0.3
		update_fog()
	hud_t -= delta
	if hud_t <= 0.0:
		hud_t = 0.25
		hud.refresh()
	mini_t -= delta
	if mini_t <= 0.0:
		mini_t = 0.6
		_update_minimap()
	win_t -= delta
	if win_t <= 0.0 and not over:
		win_t = 0.5
		if not _team_has_hq(1):
			end_game(true)
		elif not _team_has_hq(0):
			end_game(false)


# ---------- المؤثرات ----------
func spawn_tracer(a: Vector3, b: Vector3, big: bool) -> void:
	var ln: float = a.distance_to(b)
	if ln < 0.2:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var w: float = 0.14 if big else 0.07
	bm.size = Vector3(w, w, ln)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.75, 0.3) if big else Color(1.0, 0.92, 0.55)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)
	mi.position = (a + b) / 2.0
	mi.look_at(b, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT)
	get_tree().create_timer(0.09).timeout.connect(func(): if is_instance_valid(mi): mi.queue_free())


func _fx_assets() -> void:
	if spark_mesh != null:
		return
	spark_mesh = SphereMesh.new()
	spark_mesh.radius = 0.09
	spark_mesh.height = 0.18
	spark_mesh.radial_segments = 4
	spark_mesh.rings = 2
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(1.0, 0.82, 0.35)
	spark_mesh.material = sm
	puff_mesh = SphereMesh.new()
	puff_mesh.radius = 0.5
	puff_mesh.height = 1.0
	puff_mesh.radial_segments = 8
	puff_mesh.rings = 4
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.vertex_color_use_as_albedo = true
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff_mesh.material = pm
	flame_mesh = SphereMesh.new()
	flame_mesh.radius = 0.5
	flame_mesh.height = 1.0
	flame_mesh.radial_segments = 8
	flame_mesh.rings = 4
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.vertex_color_use_as_albedo = true
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flame_mesh.material = fm
	debris_mesh = BoxMesh.new()
	debris_mesh.size = Vector3(0.45, 0.3, 0.4)
	var dm := StandardMaterial3D.new()
	dm.vertex_color_use_as_albedo = true
	dm.roughness = 0.95
	debris_mesh.material = dm
	smoke_ramp = Gradient.new()
	smoke_ramp.set_color(0, Color(0.16, 0.14, 0.12, 0.85))
	smoke_ramp.set_color(1, Color(0.55, 0.53, 0.5, 0.0))
	fire_ramp = Gradient.new()
	fire_ramp.set_color(0, Color(1.0, 0.85, 0.35, 0.95))
	fire_ramp.add_point(0.45, Color(1.0, 0.4, 0.1, 0.8))
	fire_ramp.set_color(fire_ramp.get_point_count() - 1, Color(0.3, 0.05, 0.0, 0.0))
	dust_ramp = Gradient.new()
	dust_ramp.set_color(0, Color(0.72, 0.62, 0.45, 0.7))
	dust_ramp.set_color(1, Color(0.72, 0.62, 0.45, 0.0))
	grow_curve = Curve.new()
	grow_curve.add_point(Vector2(0.0, 0.35))
	grow_curve.add_point(Vector2(1.0, 1.7))


func make_smoke(extents: Vector3, amount: int) -> CPUParticles3D:
	_fx_assets()
	var p := CPUParticles3D.new()
	p.mesh = puff_mesh
	p.amount = amount
	p.lifetime = 2.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.direction = Vector3.UP
	p.spread = 14.0
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 2.4
	p.gravity = Vector3(0.6, 0.8, 0.0)
	p.scale_amount_min = 1.2
	p.scale_amount_max = 2.2
	p.scale_amount_curve = grow_curve
	p.color_ramp = smoke_ramp
	p.emitting = false
	return p


func make_fire(extents: Vector3, amount: int) -> CPUParticles3D:
	_fx_assets()
	var p := CPUParticles3D.new()
	p.mesh = flame_mesh
	p.amount = amount
	p.lifetime = 0.8
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.direction = Vector3.UP
	p.spread = 18.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0, 1.5, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.1
	p.color_ramp = fire_ramp
	p.emitting = false
	return p


func _free_later(p: Node, secs: float, counted := 0) -> void:
	get_tree().create_timer(secs).timeout.connect(_expire.bind(p, counted))


func _expire(p: Node, counted: int) -> void:
	fx_count -= counted
	if is_instance_valid(p):
		p.queue_free()


func impact(pos: Vector3, heavy: bool) -> void:
	if fx_count > 36:
		return
	_fx_assets()
	fx_count += 2
	var sp := CPUParticles3D.new()
	sp.mesh = spark_mesh
	sp.amount = 12 if heavy else 7
	sp.lifetime = 0.5
	sp.one_shot = true
	sp.explosiveness = 1.0
	sp.direction = Vector3.UP
	sp.spread = 85.0
	sp.initial_velocity_min = 2.5
	sp.initial_velocity_max = 7.0
	sp.gravity = Vector3(0, -15.0, 0)
	sp.scale_amount_min = 0.5
	sp.scale_amount_max = 1.1
	sp.position = pos
	world.add_child(sp)
	sp.emitting = true
	var du := CPUParticles3D.new()
	du.mesh = puff_mesh
	du.amount = 5 if heavy else 3
	du.lifetime = 0.9
	du.one_shot = true
	du.explosiveness = 1.0
	du.direction = Vector3.UP
	du.spread = 180.0
	du.initial_velocity_min = 0.6
	du.initial_velocity_max = 1.8
	du.gravity = Vector3(0, 0.6, 0)
	du.scale_amount_min = 0.7
	du.scale_amount_max = 1.5
	du.scale_amount_curve = grow_curve
	du.color_ramp = dust_ramp
	du.position = pos
	world.add_child(du)
	du.emitting = true
	_free_later(sp, 1.0, 1)
	_free_later(du, 1.5, 1)


func muzzle_flash(pos: Vector3, big: bool) -> void:
	if fx_count > 40:
		return
	_fx_assets()
	fx_count += 1
	var p := CPUParticles3D.new()
	p.mesh = flame_mesh
	p.amount = 4
	p.lifetime = 0.12
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 2.0
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.35 if big else 0.18
	p.scale_amount_max = 0.7 if big else 0.32
	p.color_ramp = fire_ramp
	p.position = pos
	world.add_child(p)
	p.emitting = true
	_free_later(p, 0.4, 1)


func explosion(pos: Vector3, big: bool) -> void:
	_fx_assets()
	var p := CPUParticles3D.new()
	p.mesh = flame_mesh
	p.amount = 46 if big else 20
	p.lifetime = 1.2 if big else 0.7
	p.one_shot = true
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 75.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 12.0 if big else 7.0
	p.gravity = Vector3(0, -6.0, 0)
	p.scale_amount_min = 0.9
	p.scale_amount_max = 2.6 if big else 1.6
	p.color_ramp = fire_ramp
	p.position = pos
	world.add_child(p)
	p.emitting = true
	_free_later(p, 2.2)
	var sm := make_smoke(Vector3(1.5, 0.3, 1.5) if big else Vector3(0.5, 0.2, 0.5), 22 if big else 8)
	sm.position = pos
	world.add_child(sm)
	sm.emitting = true
	_free_later(sm, 7.0 if big else 4.0)
	var db := CPUParticles3D.new()
	db.mesh = debris_mesh
	db.amount = 34 if big else 10
	db.lifetime = 1.6
	db.one_shot = true
	db.explosiveness = 1.0
	db.direction = Vector3.UP
	db.spread = 70.0
	db.initial_velocity_min = 5.0
	db.initial_velocity_max = 15.0 if big else 9.0
	db.gravity = Vector3(0, -22.0, 0)
	db.scale_amount_min = 0.4
	db.scale_amount_max = 1.4
	db.color = Color(0.42, 0.36, 0.3)
	db.position = pos
	world.add_child(db)
	db.emitting = true
	_free_later(db, 2.4)
	if big:
		var dust := CPUParticles3D.new()
		dust.mesh = puff_mesh
		dust.amount = 18
		dust.lifetime = 2.2
		dust.one_shot = true
		dust.explosiveness = 0.9
		dust.direction = Vector3.UP
		dust.spread = 180.0
		dust.initial_velocity_min = 2.0
		dust.initial_velocity_max = 6.0
		dust.gravity = Vector3(0, 0.3, 0)
		dust.scale_amount_min = 2.0
		dust.scale_amount_max = 4.0
		dust.scale_amount_curve = grow_curve
		dust.color_ramp = dust_ramp
		dust.position = Vector3(pos.x, pos.y - 1.0, pos.z)
		world.add_child(dust)
		dust.emitting = true
		_free_later(dust, 3.0)
