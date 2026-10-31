class_name MainEx
extends Main
## نسخة محسّنة من المتحكم الرئيسي:
## - فصل أقوى بين الآليات والجنود والطائرات (لا تداخل ولا عبور من خلال بعضها)
## - توزيع نقاط الوصول بحيث لا تتزاحم المجموعة على نفس المكان
## - تنبيه منفصل لهجوم على مدينتك وهجوم على مدينة حليفك
## - تسجيل الهجمات ليدافع الحلفاء (وقاذفاتك) تلقائياً
## - تطبيق إعدادات الجودة والإطارات فعلياً، وهدية بداية المباراة: 5 جنود وشاحنة ذهب (مع حارس احتياطي)
## - مؤثرات أخف على الجودة المنخفضة، وإضاءة صحراوية أوضح للأرضية
## - حماية الوحدات: نموذج احتياطي مرئي إن فشل بناء النموذج، وطباعة تقرير الهدية في سجل التشغيل
## - منع البناء قرب الأشجار أو في مناطق لم تُكشف بعد (مع هامش خلية)

var alert_cd_ally := 0.0
var gift_t := 0.0


func _ready() -> void:
	randomize()
	get_tree().auto_accept_quit = false
	DisplayServer.screen_set_keep_on(true)
	_build_environment()
	world = Node3D.new()
	add_child(world)
	rig = RtsCamera.new()
	add_child(rig)
	hud = HudEx.new()
	add_child(hud)
	hud.setup(self)
	for y in range(-14, 15):
		for x in range(-14, 15):
			spiral.append(Vector2i(x, y))
	spiral.sort_custom(func(a, b): return a.length_squared() < b.length_squared())
	GameSettings.apply(self)


# إضاءة صحراوية: ضوء محيط أقوى وضباب أخف ليظهر سطح الأرض بوضوح
func _build_environment() -> void:
	super._build_environment()
	for c in get_children():
		if c is WorldEnvironment:
			var env: Environment = (c as WorldEnvironment).environment
			if env != null:
				env.ambient_light_energy = 1.2
				env.fog_density = 0.0008
				env.fog_light_color = Color(0.9, 0.82, 0.64)


# يضمن أن كل وحدة ظاهرة: إن فشل بناء نموذجها نضع مجسّماً بسيطاً بلون جيشها
func spawn_unit(type: String, team: int, pos: Vector3) -> Unit:
	var u: Unit = super.spawn_unit(type, team, pos)
	if u == null:
		push_error("فشل إنشاء وحدة من نوع " + type)
		return u
	if u.model == null or u.get_child_count() == 0:
		push_error("وحدة بلا نموذج: " + type + " (أُضيف مجسّم احتياطي)")
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(2.2, 1.6, 3.4) if type == "truck" else Vector3(0.7, 1.7, 0.7)
		mi.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Data.ARMIES[army_of[team]]["color"]
		mi.material_override = mat
		mi.position = Vector3(0, bm.size.y * 0.5, 0)
		u.add_child(mi)
		u.model = mi
	return u


# تُستدعى بعد توليد التضاريس: نطبّق الجودة على الأشجار والماء أيضاً
func _setup_fog() -> void:
	super._setup_fog()
	GameSettings.apply(self)


# بداية المباراة: مقر ومقر ذهب وثكنة، وهدية: 5 جنود وشاحنة ذهب واحدة لكل جيش
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
		_spawn_gift(o)


func _spawn_gift(o: int) -> void:
	var hq = find_hq(o)
	if hq == null:
		push_error("الهدية: لا يوجد مقر للجيش " + str(o))
		return
	var p: Vector3 = free_spot(hq)
	var soldiers := 0
	for i in 5:
		var u: Unit = spawn_unit("inf", o, _safe_pos(spawn_pos_near(p, "inf"), hq, i))
		if u != null:
			soldiers += 1
	var truck_ok := false
	for bd in blds:
		if bd.team == o and bd.type == "dep" and not bd.dead:
			var t1: Unit = spawn_unit("truck", o, _safe_pos(spawn_pos_near(free_spot(bd), "truck"), bd, 7))
			truck_ok = t1 != null
			break
	if not truck_ok:
		var t2: Unit = spawn_unit("truck", o, _safe_pos(spawn_pos_near(p, "truck"), hq, 7))
		truck_ok = t2 != null
	print("الهدية: جيش %d | جنود %d | شاحنة %s | عند %s" % [o, soldiers, str(truck_ok), str(p)])


# موضع آمن قرب المبنى: إن كان الموضع المقترح بعيداً أو غير صالح نستخدم حلقة حول المبنى
func _safe_pos(pos: Vector3, near, idx: int) -> Vector3:
	var ok: bool = is_finite(pos.x) and is_finite(pos.z) and Vector2(pos.x - near.position.x, pos.z - near.position.z).length() < 40.0
	if ok:
		return pos
	var ang: float = TAU * float(idx) / 8.0
	var rr: float = (float(near.size) + 3.0) * Data.CELL
	var px: float = near.position.x + cos(ang) * rr
	var pz: float = near.position.z + sin(ang) * rr
	return Vector3(px, terrain.height_at(px, pz), pz)


# حارس احتياطي: إن بدأت المباراة دون أي وحدة للاعب (حفظ تالف مثلاً) تُمنح الهدية
func _ensure_gift() -> void:
	if not running or loading_now or find_hq(0) == null:
		return
	for u in units:
		if u.team == 0 and not u.dead:
			return
	_spawn_gift(0)


# حفظ قديم أو من خريطة بحجم مختلف: نبدأ مباراة جديدة بدل تحميل حالة غير متوافقة
func _restore(d: Dictionary) -> void:
	var ok := false
	for bd in d.get("buildings", []):
		if str(bd["t"]) == "hq" and int(bd["o"]) == 0:
			if Vector2i(int(bd["cx"]), int(bd["cy"])) == Data.BASES[0]:
				ok = true
	if not ok:
		_spawn_initial()
		return
	super._restore(d)


# ---------- البناء: لا أشجار ولا مناطق غير مكتشفة ----------
func can_place(owner_slot: int, type: String, c: Vector2i) -> bool:
	if not super.can_place(owner_slot, type, c):
		return false
	if owner_slot != 0:
		return true
	var s: int = int(Data.BUILDINGS[type]["size"])
	var n: int = Data.MAP
	for y in range(c.y - 1, c.y + s + 1):
		for x in range(c.x - 1, c.x + s + 1):
			if x < 0 or y < 0 or x >= n or y >= n:
				continue
			if explored[y * n + x] == 0:
				return false
	return true


func _no_build_reason(c: Vector2i) -> String:
	var s: int = int(Data.BUILDINGS[place_type]["size"])
	var n: int = Data.MAP
	for y in range(c.y - 1, c.y + s + 1):
		for x in range(c.x - 1, c.x + s + 1):
			if x >= 0 and y >= 0 and x < n and y < n and explored[y * n + x] == 0:
				return "لا يمكن البناء في منطقة لم تُكشف بعد"
	for y in range(c.y, c.y + s):
		for x in range(c.x, c.x + s):
			if x < 0 or y < 0 or x >= n or y >= n:
				return "خارج حدود الخريطة"
			var t: int = terrain.types[y * n + x]
			if t == 3 or t == 4:
				return "لا يمكن البناء على الماء أو الجسور"
			if t == 5 or terrain.build_block[y * n + x] == 1:
				return "لا يمكن البناء قرب الأشجار"
	return "لا يمكن البناء هنا، ابنِ بالقرب من مبانيك على أرض خالية"


func try_place(gp: Vector3) -> void:
	var cost: float = float(Data.BUILDINGS[place_type]["cost"])
	if gold[0] < cost:
		hud.toast("الذهب غير كافٍ")
		Sfx.play("bad")
		return
	var c := _place_cell(gp, place_type)
	if not can_place(0, place_type, c):
		hud.toast(_no_build_reason(c))
		Sfx.play("bad")
		return
	gold[0] -= cost
	add_building(place_type, 0, c, false)
	Sfx.play("place")
	clear_selection()


func _clear_world() -> void:
	Threats.list.clear()
	alert_cd_ally = 0.0
	gift_t = 0.0
	super._clear_world()


func _process(delta: float) -> void:
	alert_cd_ally -= delta
	super._process(delta)
	GameSettings.tick(self, delta)
	if running and gift_t >= 0.0:
		gift_t += delta
		if gift_t > 1.5:
			gift_t = -1.0
			_ensure_gift()


# ---------- مؤثرات أخف على الجودة المنخفضة ----------
func make_smoke(extents: Vector3, amount: int) -> CPUParticles3D:
	return super.make_smoke(extents, maxi(2, int(float(amount) * GameSettings.fx_scale())))


func make_fire(extents: Vector3, amount: int) -> CPUParticles3D:
	return super.make_fire(extents, maxi(2, int(float(amount) * GameSettings.fx_scale())))


func impact(pos: Vector3, heavy: bool) -> void:
	if GameSettings.preset() == 0 and randf() < 0.5:
		return
	super.impact(pos, heavy)


# ---------- التنبيهات ----------
func notify_attack(b) -> void:
	var msg: String
	if b.team == 0:
		if alert_cd > 0.0:
			return
		alert_cd = 7.0
		msg = "تنبيه! مدينتك تتعرض للهجوم"
	else:
		if alert_cd_ally > 0.0:
			return
		alert_cd_ally = 10.0
		msg = "تنبيه! مدينة حليفك تتعرض للهجوم"
	alert_pos = b.position
	alert_cell = world_to_cell(b.position)
	alert_t = 6.0
	hud.show_alert(msg, b.position)
	Sfx.play("alert")


# ---------- نقاط الوصول: لا تزاحم ----------
func order_move(us: Array, wp: Vector3, am: bool) -> void:
	var base := world_to_cell(wp)
	var list: Array = us.filter(func(u): return not u.is_truck and not u.dead)
	list.sort_custom(func(a, b): return float(a.def["radius"]) > float(b.def["radius"]))
	var taken: Array = []
	for u in list:
		var r: float = float(u.def["radius"])
		var big: bool = r > 1.2
		var goal := Vector2i(-1, -1)
		for o in spiral:
			var c: Vector2i = base + o
			if not u.is_air:
				var blocked: bool = is_solid_big(c) if big else is_solid(c)
				if blocked:
					continue
			var p := Vector2((c.x + 0.5) * Data.CELL, (c.y + 0.5) * Data.CELL)
			var ok := true
			for t in taken:
				if t["air"] != u.is_air:
					continue
				if p.distance_to(t["p"]) < r + float(t["r"]) + 0.6:
					ok = false
					break
			if ok:
				goal = c
				taken.append({"p": p, "r": r, "air": u.is_air})
				break
		if goal.x < 0:
			goal = base
		u.tgt = null
		u.forced = false
		u.amove = am
		u.dest = goal
		u.goto_cell(goal)


# ---------- الولادة دون تداخل ----------
func spawn_pos_near(center: Vector3, type: String) -> Vector3:
	var d: Dictionary = Data.UNITS[type]
	if bool(d["air"]):
		return center + Vector3(randf_range(-3.0, 3.0), 0.0, randf_range(-3.0, 3.0))
	var r_new: float = float(d["radius"])
	var big: bool = r_new > 1.2
	for ring in range(0, 15):
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
			if _spot_clear(px, pz, r_new + 0.3):
				return Vector3(px, terrain.height_at(px, pz), pz)
	return center


# ---------- الفصل بين الوحدات ----------
func _separate() -> void:
	for _i in range(3):
		_separate_once()


# يحرّك وحدة بمقدار (mx, mz) مع احترام العوائق. يرجع نسبة ما تحرّكته فعلاً (0 إلى 1)
func _nudge(u: Unit, mx: float, mz: float) -> float:
	var nx: float = u.position.x + mx
	var nz: float = u.position.z + mz
	if u.is_air or not blocked_for(u, nx, nz):
		u.position.x = nx
		u.position.z = nz
		return 1.0
	if not blocked_for(u, nx, u.position.z):
		u.position.x = nx
		return 0.5
	if not blocked_for(u, u.position.x, nz):
		u.position.z = nz
		return 0.5
	return 0.0


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
	# الواقف يفسح الطريق للمتحرك
	if a.moving and not b.moving:
		fa *= 0.5
		fb = 1.0 - fa
	elif b.moving and not a.moving:
		fb *= 0.5
		fa = 1.0 - fb
	var got_a: float = _nudge(a, -ux * p * fa, -uz * p * fa)
	# إن كانت الأولى محجوبة تأخذ الثانية حصتها أيضاً، والعكس
	var got_b: float = _nudge(b, ux * p * (fb + fa * (1.0 - got_a)), uz * p * (fb + fa * (1.0 - got_a)))
	if got_b < 1.0 and got_a < 1.0:
		var k: float = (1.0 - got_b) * fb
		_nudge(a, -ux * p * k, -uz * p * k)
