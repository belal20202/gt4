class_name Models
extends RefCounted
## نماذج 3D مبنية بالكود. لون الجيش يظهر على الأعلام والأسقف والأشرطة، أما باقي الشكل فبألوان طبيعية.
## لاستبدال أي نموذج بنموذج احترافي ضع ملف .glb في assets/models
## باسم الوحدة: inf tank art heli jet truck  أو المبنى: hq dep bar fac air twr
## (عقد خاصة تدور تلقائياً: Turret للبرج، Rotor للمروحة، TailRotor للذيل، LegL وLegR لأرجل الجندي، Cargo لحمولة الذهب)
##
## الأداء: كل نموذج يُبنى مرة واحدة لكل (نوع + لون) ثم تُدمج قطعه في شبكة واحدة لكل جزء متحرك،
## وبعدها تشترك كل الوحدات من نفس النوع في نفس الشبكة. هذا يقلل مئات الرسمات لكل وحدة إلى 2-4 فقط.

const GLASS := Color(0.5, 0.72, 0.85)
const DARK := Color(0.13, 0.12, 0.12)
const SAND := Color(0.82, 0.69, 0.48)
const SAND_D := Color(0.68, 0.54, 0.37)
const BRICK := Color(0.66, 0.43, 0.30)
const STONE := Color(0.66, 0.61, 0.52)
const WOOD := Color(0.45, 0.31, 0.19)
const IRON := Color(0.42, 0.43, 0.45)
const CANVAS := Color(0.88, 0.81, 0.64)
const GOLD := Color(0.95, 0.76, 0.24)
const KHAKI := Color(0.64, 0.55, 0.38)
const OLIVE := Color(0.42, 0.45, 0.28)
const GROUPS := ["Turret", "Rotor", "TailRotor", "LegL", "LegR", "Cargo"]

static var _tpl := {}
static var _vm := {}


static func mat(col: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	return m


static func glow_mat(col: Color) -> StandardMaterial3D:
	var m := mat(col, 0.4, 0.0)
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 1.4
	return m


static func node(parent: Node3D, pos: Vector3, nm := "") -> Node3D:
	var n := Node3D.new()
	n.position = pos
	if nm != "":
		n.name = nm
	parent.add_child(n)
	return n


static func box(parent: Node3D, size: Vector3, pos: Vector3, col: Color, rough := 0.8, metal := 0.0, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat(col, rough, metal)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func cyl(parent: Node3D, r_top: float, r_bot: float, h: float, pos: Vector3, col: Color, rough := 0.8, metal := 0.0, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = 10
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat(col, rough, metal)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func sph(parent: Node3D, radius: float, pos: Vector3, col: Color, sc := Vector3.ONE, rough := 0.7, metal := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = mat(col, rough, metal)
	mi.position = pos
	mi.scale = sc
	parent.add_child(mi)
	return mi


# كبسولة (أطراف مدورة): تعطي مظهراً أقرب للجسم البشري
static func cap(parent: Node3D, radius: float, height: float, pos: Vector3, col: Color, rough := 0.9, rot := Vector3.ZERO, sc := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = radius
	cm.height = maxf(height, radius * 2.0 + 0.01)
	cm.radial_segments = 8
	cm.rings = 3
	mi.mesh = cm
	mi.material_override = mat(col, rough, 0.0)
	mi.position = pos
	mi.rotation = rot
	mi.scale = sc
	parent.add_child(mi)
	return mi


# أسطوانة تصل بين نقطتين (للأذرع والأنابيب)
static func limb(parent: Node3D, a: Vector3, b: Vector3, r0: float, r1: float, col: Color, rough := 0.9, metal := 0.0) -> MeshInstance3D:
	var d: Vector3 = b - a
	var ln: float = maxf(d.length(), 0.001)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r1
	cm.bottom_radius = r0
	cm.height = ln
	cm.radial_segments = 8
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat(col, rough, metal)
	var y: Vector3 = d / ln
	var up: Vector3 = Vector3.UP if absf(y.y) < 0.98 else Vector3.RIGHT
	var x: Vector3 = up.cross(y).normalized()
	var z: Vector3 = x.cross(y).normalized()
	mi.transform = Transform3D(Basis(x, y, z), (a + b) * 0.5)
	parent.add_child(mi)
	return mi


static func wheel(parent: Node3D, pos: Vector3, r: float, w: float) -> void:
	cyl(parent, r, r, w, pos, Color(0.14, 0.14, 0.15), 0.95, 0.0, Vector3(0, 0, PI / 2.0))
	cyl(parent, r * 0.5, r * 0.5, w + 0.04, pos, Color(0.55, 0.52, 0.45), 0.6, 0.15, Vector3(0, 0, PI / 2.0))


static func banner(parent: Node3D, pos: Vector3, h: float, col: Color, w := 1.4) -> void:
	cyl(parent, 0.05, 0.06, h, pos + Vector3(0, h / 2.0, 0), WOOD, 0.8)
	var f := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(w, w * 0.62)
	f.mesh = qm
	var fm := mat(col, 0.7)
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	f.material_override = fm
	f.position = pos + Vector3(w * 0.5 + 0.05, h - w * 0.35, 0)
	parent.add_child(f)


static func merlons(parent: Node3D, w: float, d: float, y: float, col: Color, h := 0.5) -> void:
	var step := 0.95
	var nx: int = int(w / step)
	for i in range(nx):
		if i % 2 == 0:
			var x: float = -w / 2.0 + step * (i + 0.5)
			box(parent, Vector3(0.5, h, 0.4), Vector3(x, y, -d / 2.0), col)
			box(parent, Vector3(0.5, h, 0.4), Vector3(x, y, d / 2.0), col)
	var nz: int = int(d / step)
	for k in range(nz):
		if k % 2 == 0:
			var z: float = -d / 2.0 + step * (k + 0.5)
			box(parent, Vector3(0.4, h, 0.5), Vector3(-w / 2.0, y, z), col)
			box(parent, Vector3(0.4, h, 0.5), Vector3(w / 2.0, y, z), col)


static func sandbags(root: Node3D, pos: Vector3, count: int, along_x := true) -> void:
	for k in range(count):
		var off: float = k * 0.55
		var p := pos + (Vector3(off, 0, 0) if along_x else Vector3(0, 0, off))
		box(root, Vector3(0.55, 0.28, 0.34), p, Color(0.72, 0.62, 0.42), 0.95)
		if k % 2 == 0 and k > 0:
			box(root, Vector3(0.5, 0.26, 0.32), p + Vector3(0, 0.26, 0), Color(0.68, 0.58, 0.4), 0.95)


static func barrel(root: Node3D, pos: Vector3, col := Color(0.35, 0.4, 0.3)) -> void:
	cyl(root, 0.28, 0.28, 0.7, pos + Vector3(0, 0.35, 0), col, 0.7, 0.1)
	cyl(root, 0.29, 0.29, 0.05, pos + Vector3(0, 0.5, 0), col.darkened(0.3), 0.7, 0.1)


static func lamp(root: Node3D, pos: Vector3) -> void:
	cyl(root, 0.04, 0.05, 2.2, pos + Vector3(0, 1.1, 0), IRON, 0.6, 0.1)
	var bulb := sph(root, 0.12, pos + Vector3(0, 2.25, 0), Color(1, 0.9, 0.6), Vector3.ONE, 0.3)
	bulb.material_override = glow_mat(Color(1, 0.88, 0.55))


static func foundation(root: Node3D, s: float) -> void:
	box(root, Vector3(s, 2.2, s), Vector3(0, -0.8, 0), STONE.darkened(0.2), 0.95)


# نافذة مقوّسة بإطار وعتبة. الاتجاه المحلي +z هو وجه النافذة.
static func win(root: Node3D, pos: Vector3, ry: float, w := 0.5, h := 0.9, frame := SAND_D) -> void:
	var n := node(root, pos)
	n.rotation.y = ry
	var glass := Color(0.14, 0.24, 0.34)
	box(n, Vector3(w + 0.18, h + 0.16, 0.06), Vector3.ZERO, frame, 0.9)
	box(n, Vector3(w, h, 0.1), Vector3(0, 0, 0.02), glass, 0.25, 0.3)
	cyl(n, w * 0.5 + 0.09, w * 0.5 + 0.09, 0.06, Vector3(0, h * 0.5, 0), frame, 0.9, 0.0, Vector3(PI / 2.0, 0, 0))
	cyl(n, w * 0.5, w * 0.5, 0.1, Vector3(0, h * 0.5, 0.02), glass, 0.25, 0.3, Vector3(PI / 2.0, 0, 0))
	box(n, Vector3(0.04, h + w * 0.5, 0.12), Vector3(0, w * 0.25, 0.03), frame.darkened(0.25), 0.9)
	box(n, Vector3(w + 0.26, 0.07, 0.18), Vector3(0, -h * 0.5 - 0.1, 0.05), STONE, 0.9)


# صف نوافذ على الواجهات الأربع لمبنى مستطيل
static func facade(root: Node3D, hw: float, hd: float, y: float, nf: int, ns: int, w: float, h: float, frame := SAND_D, skip_front_mid := false) -> void:
	for i in range(nf):
		var x: float = -hw + (float(i) + 0.5) * (2.0 * hw / float(nf))
		if not (skip_front_mid and absf(x) < 0.7):
			win(root, Vector3(x, y, hd + 0.02), 0.0, w, h, frame)
		win(root, Vector3(x, y, -hd - 0.02), PI, w, h, frame)
	for k in range(ns):
		var z: float = -hd + (float(k) + 0.5) * (2.0 * hd / float(ns))
		win(root, Vector3(hw + 0.02, y, z), PI * 0.5, w, h, frame)
		win(root, Vector3(-hw - 0.02, y, z), -PI * 0.5, w, h, frame)


# عمود مع تاج وقاعدة
static func column(root: Node3D, pos: Vector3, h: float, r: float, col := STONE) -> void:
	cyl(root, r, r * 1.08, h, pos + Vector3(0, h * 0.5, 0), col, 0.85)
	box(root, Vector3(r * 3.0, 0.14, r * 3.0), pos + Vector3(0, 0.07, 0), col.darkened(0.08), 0.9)
	box(root, Vector3(r * 3.1, 0.16, r * 3.1), pos + Vector3(0, h + 0.08, 0), col.lightened(0.05), 0.9)


static func ac_unit(root: Node3D, pos: Vector3) -> void:
	box(root, Vector3(0.7, 0.45, 0.5), pos + Vector3(0, 0.22, 0), Color(0.78, 0.78, 0.76), 0.6, 0.15)
	cyl(root, 0.17, 0.17, 0.05, pos + Vector3(0, 0.47, 0), DARK, 0.7)


static func dish(root: Node3D, pos: Vector3, r: float, ry: float) -> void:
	var n := node(root, pos)
	n.rotation.y = ry
	cyl(n, 0.05, 0.07, r * 1.2, Vector3(0, r * 0.6, 0), IRON, 0.6, 0.2)
	var d := cyl(n, r, r * 0.15, r * 0.35, Vector3(0, r * 1.3, r * 0.1), Color(0.85, 0.85, 0.82), 0.5, 0.3, Vector3(deg_to_rad(-60.0), 0, 0))
	d.scale = Vector3(1, 1, 1)


static func crate(root: Node3D, pos: Vector3, s: float, col := WOOD) -> void:
	box(root, Vector3(s, s, s), pos + Vector3(0, s * 0.5, 0), col, 0.9)
	box(root, Vector3(s + 0.02, 0.06, s + 0.02), pos + Vector3(0, s * 0.2, 0), col.darkened(0.25), 0.9)
	box(root, Vector3(s + 0.02, 0.06, s + 0.02), pos + Vector3(0, s * 0.8, 0), col.darkened(0.25), 0.9)


static func _glb(key: String) -> Node3D:
	var path := "res://assets/models/%s.glb" % key
	if ResourceLoader.exists(path):
		var ps = load(path)
		if ps is PackedScene:
			return ps.instantiate()
	return null


# ================= دمج الشبكات (الأداء) =================
static func _vmat(kind: int) -> StandardMaterial3D:
	if _vm.has(kind):
		return _vm[kind]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.85
	if kind == 1:
		m.roughness = 0.42
		m.metallic = 0.25
	elif kind == 2:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_vm[kind] = m
	return m


static func _acc_new() -> Dictionary:
	return {"v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray(), "i": PackedInt32Array()}


static func _merge(acc: Dictionary, mesh: Mesh, xf: Transform3D, col: Color) -> void:
	if mesh == null or mesh.get_surface_count() == 0:
		return
	var arr: Array = mesh.surface_get_arrays(0)
	if arr[Mesh.ARRAY_VERTEX] == null or arr[Mesh.ARRAY_INDEX] == null or arr[Mesh.ARRAY_NORMAL] == null:
		return
	var sv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var sn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var si: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var vs: PackedVector3Array = acc["v"]
	var ns: PackedVector3Array = acc["n"]
	var cs: PackedColorArray = acc["c"]
	var ids: PackedInt32Array = acc["i"]
	var base: int = vs.size()
	var nb: Basis = xf.basis.inverse().transposed()
	for k in range(sv.size()):
		vs.append(xf * sv[k])
		ns.append((nb * sn[k]).normalized())
		cs.append(col)
	for k in range(si.size()):
		ids.append(si[k] + base)


static func _collect(n: Node, xf: Transform3D, am: Dictionary, asn: Dictionary, ad: Dictionary, dead: Array, force_all: bool) -> void:
	for c in n.get_children():
		if c is MeshInstance3D:
			var mi: MeshInstance3D = c
			var sm := mi.material_override as StandardMaterial3D
			var col := Color(0.7, 0.7, 0.7)
			var kind := 0
			if sm != null:
				col = sm.albedo_color
				if sm.emission_enabled and not force_all:
					continue
				if sm.cull_mode == BaseMaterial3D.CULL_DISABLED:
					kind = 2
				elif sm.metallic > 0.05 or sm.roughness < 0.5:
					kind = 1
			var acc: Dictionary = am
			if kind == 1:
				acc = asn
			elif kind == 2:
				acc = ad
			_merge(acc, mi.mesh, xf * mi.transform, col)
			dead.append(mi)
		elif c is Node3D:
			var cn: Node3D = c
			if GROUPS.has(str(cn.name)):
				_bake(cn)
			else:
				_collect(cn, xf * cn.transform, am, asn, ad, dead, force_all)


static func _bake(group: Node3D) -> void:
	var am := _acc_new()
	var asn := _acc_new()
	var ad := _acc_new()
	var dead: Array = []
	_collect(group, Transform3D.IDENTITY, am, asn, ad, dead, str(group.name) == "Cargo")
	for d in dead:
		d.free()
	var kinds: Array = [[am, 0], [asn, 1], [ad, 2]]
	for e in kinds:
		var acc: Dictionary = e[0]
		var vs: PackedVector3Array = acc["v"]
		if vs.is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vs
		arrays[Mesh.ARRAY_NORMAL] = acc["n"]
		arrays[Mesh.ARRAY_COLOR] = acc["c"]
		arrays[Mesh.ARRAY_INDEX] = acc["i"]
		var am_mesh := ArrayMesh.new()
		am_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mi := MeshInstance3D.new()
		mi.mesh = am_mesh
		mi.material_override = _vmat(int(e[1]))
		mi.name = "Baked%d" % int(e[1])
		group.add_child(mi)


# ================= الوحدات =================
static func unit_model(type: String, team_col: Color) -> Node3D:
	var ext := _glb(type)
	if ext != null:
		return ext
	var key: String = "u:" + type + ":" + team_col.to_html(false)
	if not _tpl.has(key):
		_tpl[key] = _build_unit(type, team_col)
	var tpl: Node3D = _tpl[key]
	return tpl.duplicate() as Node3D


static func _build_unit(type: String, team_col: Color) -> Node3D:
	var root := Node3D.new()
	match type:
		"inf", "rpg", "sniper":
			_infantry(root, team_col, type)
			root.scale = Vector3(1.1, 1.1, 1.1)
		"tank":
			_tank(root, team_col, "tank")
		"art":
			_tank(root, team_col, "art")
		"lt":
			_tank(root, team_col, "lt")
			root.scale = Vector3(0.8, 0.8, 0.8)
		"heavy":
			_tank(root, team_col, "heavy")
			root.scale = Vector3(1.22, 1.22, 1.22)
		"aa":
			_tank(root, team_col, "aa")
		"bomber":
			_bomber(root, team_col)
		"truck":
			_truck(root, team_col)
		"heli":
			_heli(root, team_col)
		"jet":
			_jet(root, team_col)
		_:
			box(root, Vector3(1, 1, 1), Vector3(0, 0.5, 0), team_col)
	_bake(root)
	return root


# جندي بتفاصيل أقرب للواقع: زي صحراوي مموّه، سترة تكتيكية، خوذة، حقيبة، وبندقية بذراعين ممسكتين بها.
static func _infantry(root: Node3D, team_col: Color, kind := "inf") -> void:
	var uni := Color(0.55, 0.50, 0.34)
	var uni2 := Color(0.40, 0.37, 0.24)
	var uni3 := Color(0.68, 0.61, 0.44)
	var vest := Color(0.29, 0.31, 0.22)
	var skin := Color(0.74, 0.55, 0.42)
	var boot := Color(0.17, 0.12, 0.09)
	var steel := Color(0.14, 0.14, 0.15)
	var wood := Color(0.40, 0.26, 0.14)
	var ghillie: bool = kind == "sniper"
	if ghillie:
		uni = Color(0.40, 0.44, 0.27)
		uni2 = Color(0.30, 0.34, 0.20)
		uni3 = Color(0.50, 0.53, 0.32)
	# الساقان (تتحركان عند المشي)
	for sx in [-1, 1]:
		var leg := node(root, Vector3(0.125 * sx, 1.0, 0), "LegL" if sx < 0 else "LegR")
		cap(leg, 0.105, 0.52, Vector3(0, -0.25, 0), uni)
		cap(leg, 0.082, 0.5, Vector3(0, -0.68, 0.01), uni.darkened(0.04))
		box(leg, Vector3(0.07, 0.12, 0.05), Vector3(0.03 * sx, -0.2, 0.1), uni2, 0.9)
		box(leg, Vector3(0.06, 0.1, 0.05), Vector3(-0.04 * sx, -0.62, 0.075), uni3, 0.9)
		box(leg, Vector3(0.15, 0.12, 0.07), Vector3(0, -0.47, 0.085), vest, 0.85)
		box(leg, Vector3(0.12, 0.14, 0.1), Vector3(0.1 * sx, -0.32, 0.0), vest.lightened(0.05), 0.9)
		box(leg, Vector3(0.15, 0.13, 0.31), Vector3(0, -0.93, 0.05), boot, 0.9)
		box(leg, Vector3(0.16, 0.035, 0.32), Vector3(0, -0.985, 0.05), steel, 0.95)
	# الحوض والحزام
	box(root, Vector3(0.40, 0.2, 0.26), Vector3(0, 1.06, 0), uni, 0.9)
	box(root, Vector3(0.43, 0.07, 0.29), Vector3(0, 1.13, 0), steel, 0.7)
	box(root, Vector3(0.07, 0.06, 0.02), Vector3(0, 1.13, 0.15), Color(0.8, 0.65, 0.25), 0.4, 0.5)
	# الصدر والسترة التكتيكية
	var tor := cap(root, 0.22, 0.56, Vector3(0, 1.34, 0), uni, 0.9, Vector3.ZERO, Vector3(1.0, 1.0, 0.72))
	tor.name = "Torso"
	box(root, Vector3(0.5, 0.42, 0.27), Vector3(0, 1.33, 0.02), vest, 0.88)
	for k in range(3):
		box(root, Vector3(0.11, 0.15, 0.07), Vector3(-0.16 + k * 0.16, 1.2, 0.17), vest.darkened(0.25), 0.9)
		box(root, Vector3(0.1, 0.04, 0.075), Vector3(-0.16 + k * 0.16, 1.28, 0.17), vest.darkened(0.4), 0.9)
	box(root, Vector3(0.2, 0.12, 0.06), Vector3(0, 1.43, 0.17), vest.darkened(0.15), 0.9)
	box(root, Vector3(0.46, 0.06, 0.3), Vector3(0, 1.56, 0), uni, 0.9)
	# رقع التمويه على الصدر
	box(root, Vector3(0.14, 0.1, 0.02), Vector3(-0.15, 1.48, 0.15), uni2, 0.95)
	box(root, Vector3(0.1, 0.12, 0.02), Vector3(0.17, 1.38, 0.155), uni3, 0.95)
	# الحقيبة
	box(root, Vector3(0.36, 0.44, 0.17), Vector3(0, 1.32, -0.24), uni2, 0.9)
	box(root, Vector3(0.3, 0.14, 0.04), Vector3(0, 1.42, -0.335), team_col, 0.7)
	cyl(root, 0.075, 0.075, 0.4, Vector3(0, 1.58, -0.24), KHAKI, 0.9, 0.0, Vector3(0, 0, PI / 2.0))
	cyl(root, 0.06, 0.06, 0.16, Vector3(-0.2, 1.06, -0.16), Color(0.3, 0.34, 0.24), 0.7, 0.1)
	# الرقبة والرأس
	cyl(root, 0.07, 0.08, 0.1, Vector3(0, 1.6, 0), skin, 0.9)
	sph(root, 0.118, Vector3(0, 1.71, 0.01), skin, Vector3(0.92, 1.08, 1.0), 0.85)
	box(root, Vector3(0.03, 0.04, 0.04), Vector3(0, 1.7, 0.125), skin.darkened(0.08), 0.9)
	box(root, Vector3(0.04, 0.018, 0.02), Vector3(-0.05, 1.735, 0.112), Color(0.08, 0.06, 0.05), 0.5)
	box(root, Vector3(0.04, 0.018, 0.02), Vector3(0.05, 1.735, 0.112), Color(0.08, 0.06, 0.05), 0.5)
	sph(root, 0.03, Vector3(-0.115, 1.71, 0.0), skin, Vector3(0.5, 1.0, 0.8), 0.9)
	sph(root, 0.03, Vector3(0.115, 1.71, 0.0), skin, Vector3(0.5, 1.0, 0.8), 0.9)
	if ghillie:
		# قبعة قناص مع تمويه
		cyl(root, 0.24, 0.24, 0.025, Vector3(0, 1.8, 0.0), uni2, 0.95)
		cyl(root, 0.13, 0.15, 0.1, Vector3(0, 1.85, 0.0), uni, 0.95)
		for k in range(10):
			var a: float = float(k) * 0.63
			box(root, Vector3(0.08, 0.05, 0.12), Vector3(cos(a) * 0.17, 1.8, sin(a) * 0.17), uni3 if k % 2 == 0 else uni2, 0.95, 0.0, Vector3(0, -a, 0))
		for k in range(8):
			var b: float = float(k) * 0.8
			box(root, Vector3(0.1, 0.14, 0.08), Vector3(cos(b) * 0.22, 1.36 + sin(b * 2.0) * 0.12, sin(b) * 0.13 - 0.02), uni3 if k % 2 == 0 else uni2, 0.97, 0.0, Vector3(0.2, b, 0.3))
	else:
		# الخوذة مع غطاء تمويه وشريط بلون الجيش
		sph(root, 0.158, Vector3(0, 1.77, 0.0), uni2, Vector3(1.0, 0.82, 1.12), 0.85)
		cyl(root, 0.168, 0.172, 0.04, Vector3(0, 1.725, 0.0), team_col, 0.6)
		box(root, Vector3(0.1, 0.05, 0.1), Vector3(-0.07, 1.84, 0.05), uni3, 0.95)
		box(root, Vector3(0.09, 0.05, 0.09), Vector3(0.08, 1.82, -0.04), uni, 0.95)
		box(root, Vector3(0.2, 0.025, 0.08), Vector3(0, 1.73, 0.15), steel, 0.7)
		box(root, Vector3(0.012, 0.09, 0.012), Vector3(-0.08, 1.67, 0.09), steel, 0.7)
		box(root, Vector3(0.012, 0.09, 0.012), Vector3(0.08, 1.67, 0.09), steel, 0.7)
	# الأذرع وهي ممسكة بالسلاح
	var sh_l := Vector3(-0.28, 1.5, 0.0)
	var sh_r := Vector3(0.28, 1.5, 0.0)
	var long_arm: bool = kind == "rpg"
	var hand_r := Vector3(0.1, 1.2, 0.2)
	var hand_l := Vector3(-0.02, 1.26, 0.52)
	var el_r := Vector3(0.33, 1.28, 0.1)
	var el_l := Vector3(-0.3, 1.3, 0.24)
	if long_arm:
		hand_r = Vector3(0.2, 1.36, 0.1)
		hand_l = Vector3(0.14, 1.62, 0.12)
		el_r = Vector3(0.32, 1.26, 0.04)
		el_l = Vector3(0.1, 1.5, -0.04)
	sph(root, 0.075, sh_l, uni, Vector3.ONE, 0.9)
	sph(root, 0.075, sh_r, uni, Vector3.ONE, 0.9)
	limb(root, sh_l, el_l, 0.075, 0.062, uni)
	limb(root, el_l, hand_l, 0.062, 0.052, uni.darkened(0.05))
	limb(root, sh_r, el_r, 0.075, 0.062, uni)
	limb(root, el_r, hand_r, 0.062, 0.052, uni.darkened(0.05))
	sph(root, 0.05, hand_l, skin, Vector3.ONE, 0.85)
	sph(root, 0.05, hand_r, skin, Vector3.ONE, 0.85)
	box(root, Vector3(0.07, 0.11, 0.15), sh_l + Vector3(-0.04, -0.02, 0.0), team_col, 0.7)
	box(root, Vector3(0.07, 0.11, 0.15), sh_r + Vector3(0.04, -0.02, 0.0), team_col, 0.7)
	# السلاح
	if kind == "rpg":
		limb(root, Vector3(0.16, 1.58, -0.55), Vector3(0.16, 1.6, 0.85), 0.085, 0.09, OLIVE, 0.7, 0.1)
		limb(root, Vector3(0.16, 1.6, 0.85), Vector3(0.16, 1.6, 1.0), 0.09, 0.14, IRON, 0.5, 0.2)
		limb(root, Vector3(0.16, 1.6, -0.55), Vector3(0.16, 1.58, -0.7), 0.085, 0.115, IRON, 0.5, 0.2)
		box(root, Vector3(0.07, 0.12, 0.2), Vector3(0.16, 1.5, 0.18), DARK, 0.6)
		box(root, Vector3(0.05, 0.06, 0.12), Vector3(0.16, 1.7, 0.3), DARK, 0.5, 0.3)
		for k in range(2):
			limb(root, Vector3(-0.1 + k * 0.16, 1.5, -0.33), Vector3(-0.1 + k * 0.16, 1.52, -0.55), 0.05, 0.06, OLIVE, 0.7)
	else:
		var rx := 0.1
		var ry := 1.22
		box(root, Vector3(0.06, 0.1, 0.42), Vector3(rx, ry, 0.2), steel, 0.4, 0.4)
		limb(root, Vector3(rx, ry + 0.01, 0.38), Vector3(rx, ry + 0.01, 0.95 if not ghillie else 1.2), 0.016, 0.014, steel, 0.4, 0.4)
		box(root, Vector3(0.075, 0.075, 0.3), Vector3(rx, ry - 0.005, 0.52), wood, 0.8)
		box(root, Vector3(0.055, 0.12, 0.3), Vector3(rx, ry - 0.03, -0.14), wood, 0.8, 0.0, Vector3(deg_to_rad(8.0), 0, 0))
		box(root, Vector3(0.05, 0.2, 0.07), Vector3(rx, ry - 0.14, 0.26), steel, 0.5, 0.3, Vector3(deg_to_rad(-14.0), 0, 0))
		box(root, Vector3(0.02, 0.06, 0.02), Vector3(rx, ry + 0.08, 0.9 if not ghillie else 1.15), steel, 0.5)
		if ghillie:
			cyl(root, 0.035, 0.035, 0.34, Vector3(rx, ry + 0.1, 0.34), steel, 0.4, 0.3, Vector3(PI / 2.0, 0, 0))
			cyl(root, 0.045, 0.045, 0.05, Vector3(rx, ry + 0.1, 0.52), Color(0.3, 0.5, 0.7), 0.2, 0.3, Vector3(PI / 2.0, 0, 0))
			limb(root, Vector3(rx, ry - 0.02, 0.85), Vector3(rx - 0.1, ry - 0.34, 0.95), 0.012, 0.012, steel, 0.5)
			limb(root, Vector3(rx, ry - 0.02, 0.85), Vector3(rx + 0.1, ry - 0.34, 0.95), 0.012, 0.012, steel, 0.5)


static func uni_ghillie() -> Color:
	return Color(0.45, 0.47, 0.3)


static func _tracked_hull(root: Node3D, hull: Color, team_col: Color) -> void:
	box(root, Vector3(2.0, 0.55, 3.5), Vector3(0, 0.6, 0), hull, 0.8)
	box(root, Vector3(2.0, 0.12, 1.1), Vector3(0, 0.9, 1.55), hull, 0.8, 0.0, Vector3(deg_to_rad(-24.0), 0, 0))
	box(root, Vector3(1.9, 0.2, 1.1), Vector3(0, 0.95, -1.3), hull.darkened(0.1), 0.8)
	box(root, Vector3(0.9, 0.34, 0.06), Vector3(0, 0.85, 2.09), team_col, 0.6, 0.0, Vector3(deg_to_rad(-24.0), 0, 0))
	box(root, Vector3(0.5, 0.05, 0.9), Vector3(-0.6, 1.02, -1.3), OLIVE, 0.9)
	box(root, Vector3(0.6, 0.05, 0.6), Vector3(0.5, 1.02, -1.2), OLIVE, 0.9)
	for sx in [-1, 1]:
		box(root, Vector3(0.55, 0.62, 3.9), Vector3(1.22 * sx, 0.42, 0), Color(0.15, 0.14, 0.14), 0.95)
		box(root, Vector3(0.08, 0.42, 3.3), Vector3(1.55 * sx, 0.7, -0.05), hull.darkened(0.06), 0.8)
		box(root, Vector3(0.1, 0.34, 1.3), Vector3(1.56 * sx, 0.72, 1.0), team_col, 0.6)
		for k in range(7):
			wheel(root, Vector3(1.22 * sx, 0.34, -1.6 + k * 0.53), 0.3, 0.45)
	box(root, Vector3(0.7, 0.18, 0.5), Vector3(0.6, 1.1, -1.3), IRON, 0.6, 0.1)


static func _tank(root: Node3D, team_col: Color, kind: String) -> void:
	var hull := Color(0.70, 0.60, 0.41)
	_tracked_hull(root, hull, team_col)
	if kind == "tank" or kind == "lt" or kind == "heavy":
		var t := node(root, Vector3(0, 1.0, -0.1), "Turret")
		cyl(t, 0.95, 1.05, 0.3, Vector3(0, 0.05, 0), hull.darkened(0.12), 0.8)
		box(t, Vector3(1.6, 0.55, 2.0), Vector3(0, 0.45, 0), hull, 0.8)
		box(t, Vector3(1.5, 0.3, 0.7), Vector3(0, 0.5, 0.95), hull.darkened(0.06), 0.8, 0.0, Vector3(deg_to_rad(-18.0), 0, 0))
		box(t, Vector3(0.75, 0.5, 0.45), Vector3(0, 0.5, 1.2), hull.darkened(0.2), 0.7)
		cyl(t, 0.075, 0.09, 3.4, Vector3(0, 0.5, 2.7), DARK, 0.4, 0.25, Vector3(PI / 2.0, 0, 0))
		cyl(t, 0.12, 0.12, 0.35, Vector3(0, 0.5, 4.3), DARK, 0.4, 0.25, Vector3(PI / 2.0, 0, 0))
		cyl(t, 0.28, 0.28, 0.12, Vector3(-0.4, 0.78, -0.4), hull.darkened(0.15), 0.7)
		box(t, Vector3(0.08, 0.08, 0.6), Vector3(0.45, 0.88, 0.0), DARK, 0.4, 0.3)
		box(t, Vector3(1.2, 0.35, 0.5), Vector3(0, 0.4, -1.2), hull.darkened(0.18), 0.8)
		box(t, Vector3(1.64, 0.14, 0.6), Vector3(0, 0.74, 0.35), team_col, 0.6)
		box(t, Vector3(0.6, 0.05, 0.9), Vector3(0.5, 0.74, -0.45), OLIVE, 0.9)
		for sx in [-1, 1]:
			cyl(t, 0.07, 0.07, 0.35, Vector3(0.85 * sx, 0.55, 0.55), DARK, 0.6)
		cyl(t, 0.015, 0.02, 2.2, Vector3(0.7, 1.6, -0.9), DARK, 0.5)
		box(t, Vector3(0.5, 0.3, 0.02), Vector3(0.95, 2.55, -0.9), team_col, 0.6)
	elif kind == "art":
		var t2 := node(root, Vector3(0, 1.0, -0.5), "Turret")
		box(t2, Vector3(1.9, 1.0, 2.1), Vector3(0, 0.6, 0), hull, 0.8)
		box(t2, Vector3(1.95, 0.14, 2.15), Vector3(0, 1.15, 0), team_col, 0.6)
		box(t2, Vector3(0.9, 0.7, 0.5), Vector3(0, 0.7, 1.2), hull.darkened(0.2), 0.7)
		cyl(t2, 0.12, 0.16, 4.2, Vector3(0, 1.3, 2.1), DARK, 0.4, 0.25, Vector3(deg_to_rad(72.0), 0, 0))
		cyl(t2, 0.2, 0.2, 0.5, Vector3(0, 1.75, 3.6), DARK, 0.4, 0.25, Vector3(deg_to_rad(72.0), 0, 0))
		cyl(t2, 0.28, 0.28, 0.12, Vector3(-0.5, 1.2, -0.6), hull.darkened(0.15), 0.7)
		box(t2, Vector3(0.7, 0.05, 1.0), Vector3(-0.5, 1.2, 0.2), OLIVE, 0.9)
	else:
		var t3 := node(root, Vector3(0, 1.0, -0.2), "Turret")
		box(t3, Vector3(1.5, 0.6, 1.6), Vector3(0, 0.4, 0), hull, 0.8)
		box(t3, Vector3(1.55, 0.12, 1.6), Vector3(0, 0.75, 0), team_col, 0.6)
		for sx in [-1, 1]:
			cyl(t3, 0.06, 0.07, 2.2, Vector3(0.45 * sx, 1.0, 1.0), DARK, 0.4, 0.25, Vector3(deg_to_rad(40.0), 0, 0))
			box(t3, Vector3(0.3, 0.3, 0.6), Vector3(0.45 * sx, 0.7, 0.4), hull.darkened(0.2), 0.7)
		cyl(t3, 0.6, 0.6, 0.06, Vector3(-0.2, 1.3, -0.5), IRON, 0.6, 0.1, Vector3(deg_to_rad(-30.0), 0, 0))
		cyl(t3, 0.03, 0.03, 0.6, Vector3(-0.2, 1.0, -0.5), DARK, 0.5)
	if kind == "heavy":
		for sx in [-1, 1]:
			box(root, Vector3(0.3, 0.7, 2.6), Vector3(1.9 * sx, 0.8, 0.0), hull.darkened(0.15), 0.8)
		var ht: Node3D = root.get_node("Turret")
		cyl(ht, 0.06, 0.07, 2.6, Vector3(0.45, 0.85, 2.2), DARK, 0.4, 0.25, Vector3(PI / 2.0, 0, 0))
	elif kind == "lt":
		for sx in [-1, 1]:
			box(root, Vector3(0.25, 0.5, 2.2), Vector3(1.8 * sx, 0.9, 0.0), OLIVE, 0.9)


static func _bomber(root: Node3D, team_col: Color) -> void:
	var jb := Color(0.62, 0.58, 0.48)
	sph(root, 0.8, Vector3(0, 0.8, 0), jb, Vector3(0.9, 0.85, 4.6), 0.5)
	sph(root, 0.55, Vector3(0, 0.95, 2.9), GLASS, Vector3(0.8, 0.7, 1.2), 0.05, 0.3)
	box(root, Vector3(10.0, 0.16, 2.6), Vector3(0, 0.7, 0.2), jb, 0.5)
	for sx in [-1, 1]:
		box(root, Vector3(1.4, 0.18, 2.65), Vector3(4.6 * sx, 0.7, 0.2), team_col, 0.5)
		cyl(root, 0.5, 0.5, 0.03, Vector3(2.4 * sx, 0.8, 0.2), team_col, 0.6)
	for ex in [-3.4, -1.7, 1.7, 3.4]:
		cyl(root, 0.32, 0.34, 1.7, Vector3(ex, 0.55, 0.9), jb.darkened(0.1), 0.6, 0.0, Vector3(PI / 2.0, 0, 0))
		cyl(root, 0.85, 0.85, 0.03, Vector3(ex, 0.55, 1.8), Color(0.15, 0.15, 0.16), 0.7)
	box(root, Vector3(0.12, 1.8, 1.3), Vector3(0, 1.7, -3.7), team_col, 0.5)
	box(root, Vector3(4.0, 0.12, 1.0), Vector3(0, 0.95, -3.5), jb, 0.5)
	box(root, Vector3(1.2, 0.3, 3.0), Vector3(0, 0.2, 0), DARK, 0.7)


static func _truck(root: Node3D, team_col: Color) -> void:
	box(root, Vector3(1.8, 0.45, 4.2), Vector3(0, 0.8, 0), DARK, 0.8)
	box(root, Vector3(1.7, 1.25, 1.35), Vector3(0, 1.6, 1.45), team_col, 0.55)
	box(root, Vector3(1.5, 0.5, 0.06), Vector3(0, 1.85, 2.14), GLASS, 0.05, 0.2, Vector3(deg_to_rad(-10.0), 0, 0))
	box(root, Vector3(1.8, 0.2, 0.2), Vector3(0, 0.75, 2.2), Color(0.6, 0.58, 0.52), 0.6)
	box(root, Vector3(0.3, 0.14, 0.06), Vector3(0.55, 1.1, 2.15), Color(1, 0.95, 0.7), 0.3)
	box(root, Vector3(0.3, 0.14, 0.06), Vector3(-0.55, 1.1, 2.15), Color(1, 0.95, 0.7), 0.3)
	box(root, Vector3(1.75, 0.22, 2.5), Vector3(0, 1.1, -0.8), WOOD, 0.85)
	box(root, Vector3(0.1, 0.8, 2.5), Vector3(0.9, 1.5, -0.8), KHAKI, 0.85)
	box(root, Vector3(0.1, 0.8, 2.5), Vector3(-0.9, 1.5, -0.8), KHAKI, 0.85)
	box(root, Vector3(1.7, 0.8, 0.1), Vector3(0, 1.5, -2.05), KHAKI, 0.85)
	box(root, Vector3(1.7, 0.8, 0.1), Vector3(0, 1.5, 0.4), KHAKI, 0.85)
	box(root, Vector3(1.82, 0.12, 0.5), Vector3(0, 1.95, -0.8), team_col, 0.6)
	for z in [1.5, -0.4, -1.6]:
		for sx in [-1, 1]:
			wheel(root, Vector3(0.95 * sx, 0.5, z), 0.5, 0.4)
	var cargo := node(root, Vector3(0, 1.3, -0.8), "Cargo")
	var gm := glow_mat(GOLD)
	gm.emission_energy_multiplier = 0.5
	for k in range(6):
		var gb := MeshInstance3D.new()
		var gbm := BoxMesh.new()
		gbm.size = Vector3(0.6, 0.3, 0.9)
		gb.mesh = gbm
		gb.material_override = gm
		gb.position = Vector3(-0.35 + (k % 2) * 0.7, 0.12 + (k / 4) * 0.3, -0.5 + (k % 3) * 0.55)
		cargo.add_child(gb)


static func _heli(root: Node3D, team_col: Color) -> void:
	var hb := Color(0.43, 0.47, 0.31)
	sph(root, 0.8, Vector3(0, 0.9, 0.2), hb, Vector3(0.75, 0.85, 1.9), 0.6)
	sph(root, 0.5, Vector3(0, 1.05, 1.15), GLASS, Vector3(0.8, 0.75, 1.3), 0.05, 0.3)
	cyl(root, 0.1, 0.26, 3.2, Vector3(0, 1.0, -2.4), hb, 0.6, 0.0, Vector3(-PI / 2.0, 0, 0))
	box(root, Vector3(0.1, 1.0, 0.7), Vector3(0, 1.5, -3.7), team_col, 0.6)
	box(root, Vector3(1.4, 0.06, 0.45), Vector3(0, 1.1, -3.6), hb.darkened(0.1), 0.6)
	box(root, Vector3(3.2, 0.1, 0.7), Vector3(0, 0.85, 0.1), hb.darkened(0.12), 0.6)
	for sx in [-1, 1]:
		cyl(root, 0.18, 0.18, 1.2, Vector3(1.35 * sx, 0.72, 0.3), DARK, 0.6, 0.1, Vector3(PI / 2.0, 0, 0))
		box(root, Vector3(0.09, 0.09, 2.5), Vector3(0.75 * sx, 0.12, 0.2), DARK, 0.7)
		box(root, Vector3(0.07, 0.6, 0.07), Vector3(0.7 * sx, 0.4, 0.8), DARK, 0.7)
		box(root, Vector3(0.07, 0.6, 0.07), Vector3(0.7 * sx, 0.4, -0.5), DARK, 0.7)
		cyl(root, 0.3, 0.3, 0.03, Vector3(0.8 * sx, 1.3, 0.3), team_col, 0.6, 0.0, Vector3(0, 0, PI / 2.0))
	cyl(root, 0.05, 0.05, 0.8, Vector3(0, 0.55, 1.95), DARK, 0.5, 0.2, Vector3(PI / 2.0, 0, 0))
	cyl(root, 0.1, 0.1, 0.4, Vector3(0, 1.75, 0.1), DARK, 0.6)
	var r := node(root, Vector3(0, 1.95, 0.1), "Rotor")
	box(r, Vector3(5.8, 0.04, 0.22), Vector3.ZERO, Color(0.1, 0.1, 0.1), 0.6)
	box(r, Vector3(0.22, 0.04, 5.8), Vector3.ZERO, Color(0.1, 0.1, 0.1), 0.6)
	box(r, Vector3(0.6, 0.05, 0.24), Vector3(2.6, 0, 0), team_col, 0.6)
	box(r, Vector3(0.6, 0.05, 0.24), Vector3(-2.6, 0, 0), team_col, 0.6)
	var tr := node(root, Vector3(0.18, 1.6, -3.65), "TailRotor")
	box(tr, Vector3(0.04, 1.1, 0.1), Vector3.ZERO, Color(0.1, 0.1, 0.1), 0.6)
	box(tr, Vector3(0.04, 0.1, 1.1), Vector3.ZERO, Color(0.1, 0.1, 0.1), 0.6)


static func _jet(root: Node3D, team_col: Color) -> void:
	var jb := Color(0.74, 0.70, 0.60)
	sph(root, 0.55, Vector3(0, 0.6, 0), jb, Vector3(0.85, 0.7, 4.2), 0.5)
	cyl(root, 0.02, 0.38, 1.7, Vector3(0, 0.6, 2.9), jb, 0.5, 0.0, Vector3(PI / 2.0, 0, 0))
	sph(root, 0.35, Vector3(0, 0.92, 1.0), GLASS, Vector3(0.8, 0.7, 1.7), 0.05, 0.3)
	for sx in [-1, 1]:
		box(root, Vector3(2.7, 0.08, 1.9), Vector3(1.7 * sx, 0.55, -0.5), jb, 0.5, 0.0, Vector3(0, deg_to_rad(-22.0) * sx, 0))
		box(root, Vector3(0.45, 0.09, 0.9), Vector3(3.0 * sx, 0.55, -1.2), team_col, 0.5, 0.0, Vector3(0, deg_to_rad(-22.0) * sx, 0))
		cyl(root, 0.4, 0.4, 0.03, Vector3(1.8 * sx, 0.62, -0.5), team_col, 0.6)
		box(root, Vector3(0.08, 1.0, 1.0), Vector3(0.5 * sx, 1.1, -2.0), jb.darkened(0.06), 0.5, 0.0, Vector3(0, 0, deg_to_rad(14.0) * sx))
		box(root, Vector3(0.09, 0.5, 0.5), Vector3(0.6 * sx, 1.5, -2.2), team_col, 0.5, 0.0, Vector3(0, 0, deg_to_rad(14.0) * sx))
		box(root, Vector3(0.36, 0.36, 1.3), Vector3(0.55 * sx, 0.42, 0.6), DARK, 0.6)
		cyl(root, 0.26, 0.3, 0.5, Vector3(0.28 * sx, 0.6, -2.6), DARK, 0.5, 0.2, Vector3(PI / 2.0, 0, 0))
		var gl := cyl(root, 0.18, 0.2, 0.1, Vector3(0.28 * sx, 0.6, -2.88), Color(1, 0.55, 0.2), 0.4, 0.0, Vector3(PI / 2.0, 0, 0))
		gl.material_override = glow_mat(Color(1.0, 0.5, 0.15))
	box(root, Vector3(3.0, 0.07, 0.9), Vector3(0, 0.55, -2.4), jb.darkened(0.04), 0.5)


# ================= المباني (بأرضية مدفونة لتلتصق بالأرض) =================
static func building_model(type: String, team_col: Color) -> Node3D:
	var ext := _glb(type)
	if ext != null:
		return ext
	var key: String = "b:" + type + ":" + team_col.to_html(false)
	if not _tpl.has(key):
		_tpl[key] = _build_building(type, team_col)
	var tpl: Node3D = _tpl[key]
	return tpl.duplicate() as Node3D


static func _build_building(type: String, team_col: Color) -> Node3D:
	var root := Node3D.new()
	match type:
		"hq":
			_hq(root, team_col)
		"dep":
			_depot(root, team_col)
		"bar":
			_barracks(root, team_col)
		"fac":
			_factory(root, team_col)
		"air":
			_airfield(root, team_col)
		"twr":
			_tower(root, team_col)
	_bake(root)
	return root


# مقر القيادة: قصر حكومي بإيوان مقوّس وقبة ذهبية وأربع مآذن زاوية
static func _hq(root: Node3D, team_col: Color) -> void:
	foundation(root, 6.8)
	box(root, Vector3(6.5, 0.5, 6.5), Vector3(0, 0.25, 0), STONE, 0.9)
	box(root, Vector3(6.2, 0.12, 6.2), Vector3(0, 0.56, 0), STONE.lightened(0.06), 0.9)
	# الكتلة المركزية وجناحان
	var cb := node(root, Vector3(0, 0, -0.2))
	box(cb, Vector3(3.8, 3.28, 4.2), Vector3(0, 2.26, 0), SAND, 0.9)
	box(cb, Vector3(3.95, 0.12, 4.35), Vector3(0, 2.4, 0), SAND_D, 0.9)
	box(cb, Vector3(4.15, 0.28, 4.55), Vector3(0, 4.02, 0), STONE.lightened(0.04), 0.9)
	box(cb, Vector3(4.2, 0.08, 4.6), Vector3(0, 3.86, 0), SAND_D.darkened(0.1), 0.9)
	for sx in [-1, 1]:
		box(cb, Vector3(0.3, 3.28, 0.3), Vector3(1.9 * sx, 2.26, 2.1), STONE, 0.9)
		box(cb, Vector3(0.3, 3.28, 0.3), Vector3(1.9 * sx, 2.26, -2.1), STONE, 0.9)
		var wn := node(root, Vector3(2.65 * sx, 0, -0.2))
		box(wn, Vector3(1.55, 2.4, 3.7), Vector3(0, 1.82, 0), SAND.darkened(0.03), 0.9)
		box(wn, Vector3(1.75, 0.24, 3.9), Vector3(0, 3.1, 0), STONE.lightened(0.03), 0.9)
		box(wn, Vector3(1.6, 0.1, 3.75), Vector3(0, 1.45, 0), SAND_D, 0.9)
		merlons(wn, 1.6, 3.8, 3.45, SAND_D, 0.4)
		facade(wn, 0.78, 1.85, 1.0, 1, 3, 0.36, 0.7)
		facade(wn, 0.78, 1.85, 2.25, 1, 3, 0.36, 0.7)
		ac_unit(wn, Vector3(0.2, 3.22, -0.9))
		ac_unit(wn, Vector3(-0.2, 3.22, 0.9))
	facade(cb, 1.9, 2.1, 1.35, 3, 3, 0.46, 0.8, SAND_D, true)
	facade(cb, 1.9, 2.1, 3.0, 3, 3, 0.46, 0.8)
	merlons(cb, 4.2, 4.6, 4.4, SAND_D, 0.4)
	# القبة الذهبية
	cyl(root, 1.25, 1.3, 0.75, Vector3(0, 4.62, -0.2), SAND_D, 0.85)
	for k in range(8):
		var a: float = TAU * float(k) / 8.0
		box(root, Vector3(0.16, 0.34, 0.1), Vector3(cos(a) * 1.27, 4.64, -0.2 + sin(a) * 1.27), Color(0.15, 0.24, 0.34), 0.3, 0.3, Vector3(0, -a + PI / 2.0, 0))
	cyl(root, 1.34, 1.34, 0.1, Vector3(0, 5.02, -0.2), STONE, 0.8)
	sph(root, 1.3, Vector3(0, 5.0, -0.2), GOLD, Vector3(1, 0.95, 1), 0.3, 0.55)
	for k in range(8):
		var b: float = TAU * float(k) / 8.0
		box(root, Vector3(0.05, 1.1, 0.05), Vector3(cos(b) * 0.9, 5.65, -0.2 + sin(b) * 0.9), GOLD.darkened(0.2), 0.3, 0.5, Vector3(sin(b) * 0.7, 0, -cos(b) * 0.7))
	cyl(root, 0.04, 0.12, 1.0, Vector3(0, 6.7, -0.2), GOLD, 0.3, 0.5)
	sph(root, 0.14, Vector3(0, 7.2, -0.2), GOLD, Vector3.ONE, 0.3, 0.5)
	# المآذن الزاوية
	for p in [Vector3(-3.0, 0, -2.95), Vector3(3.0, 0, -2.95), Vector3(-3.0, 0, 2.95), Vector3(3.0, 0, 2.95)]:
		cyl(root, 0.48, 0.58, 4.3, p + Vector3(0, 2.75, 0), SAND, 0.9)
		cyl(root, 0.72, 0.72, 0.16, p + Vector3(0, 4.35, 0), STONE, 0.9)
		cyl(root, 0.5, 0.5, 0.5, p + Vector3(0, 4.7, 0), SAND_D, 0.9)
		cyl(root, 0.0, 0.62, 1.1, p + Vector3(0, 5.5, 0), team_col, 0.6)
		cyl(root, 0.02, 0.02, 0.5, p + Vector3(0, 6.3, 0), GOLD, 0.3, 0.5)
		for k in range(3):
			box(root, Vector3(0.1, 0.45, 0.1), p + Vector3(0, 1.7 + k * 0.8, 0.5), Color(0.15, 0.24, 0.34), 0.3)
	# الإيوان المقوّس (المدخل)
	box(root, Vector3(2.0, 2.55, 0.3), Vector3(0, 1.9, 1.98), STONE.lightened(0.05), 0.9)
	cyl(root, 1.0, 1.0, 0.3, Vector3(0, 3.18, 1.98), STONE.lightened(0.05), 0.9, 0.0, Vector3(PI / 2.0, 0, 0))
	box(root, Vector3(1.4, 2.05, 0.34), Vector3(0, 1.66, 2.0), DARK, 0.8)
	cyl(root, 0.7, 0.7, 0.34, Vector3(0, 2.68, 2.0), DARK, 0.8, 0.0, Vector3(PI / 2.0, 0, 0))
	for sx in [-1, 1]:
		box(root, Vector3(0.62, 1.6, 0.06), Vector3(0.33 * sx, 1.45, 2.2), WOOD, 0.8)
		box(root, Vector3(0.6, 0.06, 0.08), Vector3(0.33 * sx, 1.6, 2.22), GOLD.darkened(0.2), 0.4, 0.5)
		column(root, Vector3(1.2 * sx, 0.62, 2.45), 2.6, 0.16, STONE.lightened(0.04))
	box(root, Vector3(3.0, 0.2, 0.8), Vector3(0, 3.35, 2.4), STONE, 0.9)
	box(root, Vector3(2.6, 0.55, 0.06), Vector3(0, 3.75, 2.12), team_col, 0.6)
	for k in range(3):
		box(root, Vector3(2.5 + k * 0.5, 0.18, 0.55), Vector3(0, 0.56 + k * 0.17, 3.2 - 0.28 * float(k)), STONE, 0.9)
	banner(root, Vector3(-2.2, 0.6, 3.0), 3.6, team_col, 1.5)
	banner(root, Vector3(2.2, 0.6, 3.0), 3.6, team_col, 1.5)
	# السطح: هوائيات
	cyl(root, 0.03, 0.04, 2.0, Vector3(-1.2, 5.1, -1.4), IRON, 0.5, 0.3)
	dish(root, Vector3(1.3, 4.15, -1.5), 0.45, 0.6)
	sandbags(root, Vector3(-2.3, 0.62, 3.9), 5)
	sandbags(root, Vector3(0.7, 0.62, 3.9), 5)
	lamp(root, Vector3(-3.1, 0.6, 3.5))
	lamp(root, Vector3(3.1, 0.6, 3.5))


# مقر تجميع الذهب: مستودع بسقف جملوني، صوامع، سقالات، وأكوام سبائك
static func _depot(root: Node3D, team_col: Color) -> void:
	foundation(root, 6.8)
	box(root, Vector3(6.5, 0.4, 6.5), Vector3(0, 0.2, 0), STONE.darkened(0.1), 0.9)
	var h := node(root, Vector3(-0.9, 0, -0.9))
	box(h, Vector3(3.7, 2.3, 3.5), Vector3(0, 1.55, 0), BRICK, 0.9)
	for k in range(5):
		box(h, Vector3(3.74, 0.05, 3.54), Vector3(0, 0.75 + k * 0.4, 0), BRICK.darkened(0.15), 0.95)
	box(h, Vector3(3.9, 0.22, 3.7), Vector3(0, 2.76, 0), SAND_D, 0.9)
	box(h, Vector3(3.95, 0.14, 1.95), Vector3(0, 3.22, -0.82), team_col, 0.6, 0.0, Vector3(deg_to_rad(28.0), 0, 0))
	box(h, Vector3(3.95, 0.14, 1.95), Vector3(0, 3.22, 0.82), team_col, 0.6, 0.0, Vector3(deg_to_rad(-28.0), 0, 0))
	for k in range(6):
		box(h, Vector3(0.05, 0.1, 1.95), Vector3(-1.7 + k * 0.68, 3.3, -0.82), team_col.darkened(0.25), 0.6, 0.0, Vector3(deg_to_rad(28.0), 0, 0))
		box(h, Vector3(0.05, 0.1, 1.95), Vector3(-1.7 + k * 0.68, 3.3, 0.82), team_col.darkened(0.25), 0.6, 0.0, Vector3(deg_to_rad(-28.0), 0, 0))
	box(h, Vector3(2.0, 1.7, 0.12), Vector3(0, 1.35, 1.78), Color(0.3, 0.3, 0.3), 0.6, 0.2)
	for k in range(7):
		box(h, Vector3(2.0, 0.04, 0.16), Vector3(0, 0.6 + k * 0.23, 1.82), IRON, 0.5, 0.3)
	box(h, Vector3(2.2, 0.2, 0.3), Vector3(0, 2.3, 1.82), GOLD.darkened(0.1), 0.35, 0.4)
	facade(h, 1.75, 1.7, 2.0, 3, 3, 0.36, 0.5)
	# صوامع
	for k in range(2):
		var sp := Vector3(2.1, 0, -1.9 + k * 2.3)
		cyl(root, 0.85, 0.9, 3.4, sp + Vector3(0, 2.1, 0), Color(0.74, 0.72, 0.66), 0.65, 0.12)
		for r in range(4):
			cyl(root, 0.87, 0.87, 0.06, sp + Vector3(0, 0.9 + r * 0.8, 0), Color(0.5, 0.48, 0.44), 0.7, 0.2)
		cyl(root, 0.0, 0.9, 0.8, sp + Vector3(0, 4.2, 0), team_col, 0.6)
		box(root, Vector3(0.08, 3.4, 0.3), sp + Vector3(0.88, 2.0, 0), IRON, 0.6, 0.2)
	cyl(root, 0.12, 0.12, 2.3, Vector3(2.1, 3.0, -0.75), IRON, 0.6, 0.15, Vector3(PI / 2.0, 0, 0))
	# سبائك الذهب
	var ingot_c := Color(0.96, 0.78, 0.26)
	for base in [Vector3(1.0, 0.4, 2.2), Vector3(-2.5, 0.4, 2.3)]:
		for row in range(3):
			for col in range(3 - row):
				box(root, Vector3(0.62, 0.2, 0.34), base + Vector3((col - (2 - row) * 0.5) * 0.66, row * 0.21, 0), ingot_c, 0.3, 0.6)
	crate(root, Vector3(2.4, 0.4, 2.3), 0.8, WOOD)
	crate(root, Vector3(-1.3, 0.4, 2.6), 0.7, WOOD.darkened(0.1))
	# بوابة ولافتة
	box(root, Vector3(0.3, 4.0, 0.3), Vector3(-2.8, 2.4, 2.7), WOOD, 0.8)
	box(root, Vector3(3.0, 0.3, 0.3), Vector3(-1.45, 4.3, 2.7), WOOD, 0.8)
	box(root, Vector3(1.6, 0.5, 0.06), Vector3(-1.4, 3.8, 2.72), GOLD, 0.35, 0.4)
	banner(root, Vector3(2.8, 0.4, 2.7), 3.4, team_col, 1.3)
	barrel(root, Vector3(-0.2, 0.4, 3.0), Color(0.5, 0.3, 0.2))
	lamp(root, Vector3(0.5, 0.4, 3.0))


# الثكنة: حصن صغير بسور وأبراج زاوية وخيمة وساحة تدريب
static func _barracks(root: Node3D, team_col: Color) -> void:
	foundation(root, 4.8)
	box(root, Vector3(4.5, 0.36, 4.5), Vector3(0, 0.18, 0), STONE, 0.9)
	var b := node(root, Vector3(0, 0, -0.75))
	box(b, Vector3(2.7, 1.7, 2.1), Vector3(0, 1.2, 0), SAND, 0.9)
	box(b, Vector3(2.8, 0.1, 2.2), Vector3(0, 1.25, 0), SAND_D, 0.9)
	box(b, Vector3(3.0, 0.14, 1.4), Vector3(0, 2.5, -0.58), team_col, 0.6, 0.0, Vector3(deg_to_rad(26.0), 0, 0))
	box(b, Vector3(3.0, 0.14, 1.4), Vector3(0, 2.5, 0.58), team_col, 0.6, 0.0, Vector3(deg_to_rad(-26.0), 0, 0))
	box(b, Vector3(3.05, 0.1, 0.12), Vector3(0, 2.85, 0), team_col.darkened(0.3), 0.6)
	facade(b, 1.3, 1.05, 1.3, 3, 2, 0.3, 0.5, SAND_D)
	box(b, Vector3(0.7, 1.1, 0.1), Vector3(0, 0.95, 1.08), WOOD, 0.8)
	# السور
	box(root, Vector3(4.3, 1.3, 0.35), Vector3(0, 1.0, -2.0), SAND_D, 0.9)
	box(root, Vector3(0.35, 1.3, 4.0), Vector3(-2.0, 1.0, 0), SAND_D, 0.9)
	box(root, Vector3(0.35, 1.3, 4.0), Vector3(2.0, 1.0, 0), SAND_D, 0.9)
	box(root, Vector3(1.4, 1.3, 0.35), Vector3(-1.4, 1.0, 2.0), SAND_D, 0.9)
	box(root, Vector3(1.4, 1.3, 0.35), Vector3(1.4, 1.0, 2.0), SAND_D, 0.9)
	box(root, Vector3(4.3, 0.12, 0.45), Vector3(0, 1.7, -2.0), STONE, 0.9)
	merlons(root, 4.2, 4.2, 1.9, SAND_D, 0.4)
	# البوابة المقوسة
	box(root, Vector3(1.5, 0.4, 0.4), Vector3(0, 1.55, 2.0), STONE, 0.9)
	box(root, Vector3(1.2, 1.1, 0.12), Vector3(0, 0.9, 2.05), Color(0.2, 0.15, 0.1), 0.8)
	cyl(root, 0.6, 0.6, 0.12, Vector3(0, 1.45, 2.05), Color(0.2, 0.15, 0.1), 0.8, 0.0, Vector3(PI / 2.0, 0, 0))
	# أبراج الزوايا
	for p in [Vector3(-2.05, 0, -2.05), Vector3(2.05, 0, -2.05), Vector3(-2.05, 0, 2.05), Vector3(2.05, 0, 2.05)]:
		cyl(root, 0.4, 0.46, 2.5, p + Vector3(0, 1.5, 0), SAND, 0.9)
		cyl(root, 0.52, 0.52, 0.14, p + Vector3(0, 2.8, 0), STONE, 0.9)
		cyl(root, 0.0, 0.54, 0.8, p + Vector3(0, 3.3, 0), team_col, 0.6)
		box(root, Vector3(0.08, 0.35, 0.08), p + Vector3(0, 2.0, 0.42), Color(0.12, 0.12, 0.12), 0.5)
	# الساحة: خيمة ونموذج تدريب وحامل بنادق
	box(root, Vector3(0.9, 0.06, 0.9), Vector3(1.0, 0.4, 0.9), CANVAS.darkened(0.1), 0.95)
	box(root, Vector3(0.95, 0.06, 0.65), Vector3(1.0, 0.72, 0.65), CANVAS, 0.95, 0.0, Vector3(deg_to_rad(35.0), 0, 0))
	box(root, Vector3(0.95, 0.06, 0.65), Vector3(1.0, 0.72, 1.15), CANVAS, 0.95, 0.0, Vector3(deg_to_rad(-35.0), 0, 0))
	cyl(root, 0.06, 0.07, 0.9, Vector3(-0.9, 0.85, 1.0), WOOD, 0.8)
	box(root, Vector3(0.5, 0.08, 0.08), Vector3(-0.9, 1.1, 1.0), WOOD, 0.8)
	sph(root, 0.12, Vector3(-0.9, 1.4, 1.0), CANVAS, Vector3.ONE, 0.9)
	banner(root, Vector3(-0.2, 0.4, 1.5), 2.8, team_col, 1.2)
	sandbags(root, Vector3(-1.2, 0.36, 2.55), 5)
	barrel(root, Vector3(1.7, 0.36, 2.5))


# مصنع الدبابات: قاعة صناعية بسقف منشاري وأبراج مداخن ورافعة جسرية
static func _factory(root: Node3D, team_col: Color) -> void:
	foundation(root, 6.8)
	box(root, Vector3(6.5, 0.4, 6.5), Vector3(0, 0.2, 0), Color(0.45, 0.42, 0.38), 0.9)
	var f := node(root, Vector3(0, 0, -0.3))
	box(f, Vector3(5.6, 2.9, 4.8), Vector3(0, 1.85, 0), Color(0.72, 0.66, 0.56), 0.85)
	box(f, Vector3(5.7, 0.2, 4.9), Vector3(0, 3.35, 0), Color(0.5, 0.47, 0.42), 0.85)
	for k in range(3):
		box(f, Vector3(1.8, 0.14, 4.9), Vector3(-1.9 + k * 1.9, 3.7, 0), team_col, 0.6, 0.0, Vector3(0, 0, deg_to_rad(-14.0)))
		box(f, Vector3(0.1, 0.8, 4.9), Vector3(-1.0 + k * 1.9, 3.8, 0), Color(0.58, 0.55, 0.5), 0.8)
		box(f, Vector3(0.05, 0.5, 4.5), Vector3(-1.07 + k * 1.9, 3.85, 0), GLASS, 0.1, 0.3)
	for k in range(6):
		box(f, Vector3(5.62, 0.06, 0.1), Vector3(0, 0.9 + k * 0.35, 2.42), Color(0.6, 0.56, 0.5), 0.9)
	# بوابتان كبيرتان
	for sx in [-1, 1]:
		box(root, Vector3(2.0, 2.1, 0.14), Vector3(1.45 * sx, 1.45, 2.14), DARK, 0.8)
		for k in range(6):
			box(root, Vector3(1.9, 0.06, 0.18), Vector3(1.45 * sx, 0.6 + k * 0.34, 2.22), IRON, 0.6, 0.2)
		box(root, Vector3(2.3, 0.2, 0.3), Vector3(1.45 * sx, 2.6, 2.2), Color(0.5, 0.47, 0.42), 0.8)
	box(root, Vector3(5.7, 0.38, 0.06), Vector3(0, 3.0, 2.14), team_col, 0.6)
	for k in range(3):
		win(root, Vector3(-1.9 + k * 1.9, 2.4, -2.72), PI, 0.5, 0.45, Color(0.5, 0.47, 0.42))
	for k in range(2):
		win(root, Vector3(2.82, 2.1, -1.2 + k * 1.8), PI * 0.5, 0.5, 0.45, Color(0.5, 0.47, 0.42))
		win(root, Vector3(-2.82, 2.1, -1.2 + k * 1.8), -PI * 0.5, 0.5, 0.45, Color(0.5, 0.47, 0.42))
	# مداخن
	cyl(root, 0.34, 0.46, 3.0, Vector3(2.2, 4.9, -2.1), BRICK, 0.9)
	cyl(root, 0.4, 0.36, 0.2, Vector3(2.2, 6.45, -2.1), BRICK.darkened(0.3), 0.9)
	cyl(root, 0.28, 0.38, 2.5, Vector3(-2.2, 4.7, -2.1), BRICK, 0.9)
	cyl(root, 0.34, 0.3, 0.18, Vector3(-2.2, 5.98, -2.1), BRICK.darkened(0.3), 0.9)
	# أنابيب وخزانات وقود
	cyl(root, 0.1, 0.1, 4.0, Vector3(2.95, 1.6, 0.0), IRON, 0.5, 0.3, Vector3(PI / 2.0, 0, 0))
	cyl(root, 0.1, 0.1, 1.6, Vector3(2.95, 2.4, 1.6), IRON, 0.5, 0.3)
	for k in range(2):
		cyl(root, 0.42, 0.42, 1.6, Vector3(-2.7, 0.9, 1.0 + k * 1.1), Color(0.55, 0.55, 0.5), 0.55, 0.3, Vector3(PI / 2.0, 0, 0))
	# رافعة جسرية أمام المصنع
	for sx in [-1, 1]:
		box(root, Vector3(0.14, 3.0, 0.14), Vector3(3.15 * sx, 1.9, 2.9), team_col.darkened(0.1), 0.6, 0.2)
	box(root, Vector3(6.4, 0.2, 0.22), Vector3(0, 3.4, 2.9), team_col, 0.6, 0.2)
	box(root, Vector3(0.5, 0.3, 0.4), Vector3(0.8, 3.15, 2.9), IRON, 0.5, 0.3)
	limb(root, Vector3(0.8, 3.0, 2.9), Vector3(0.8, 2.0, 2.9), 0.012, 0.012, DARK, 0.5)
	box(root, Vector3(0.28, 0.24, 0.28), Vector3(0.8, 1.85, 2.9), Color(0.85, 0.7, 0.2), 0.6, 0.3)
	box(root, Vector3(0.9, 0.9, 0.9), Vector3(-2.6, 0.85, 3.0), WOOD, 0.85)
	box(root, Vector3(0.9, 0.9, 0.9), Vector3(-2.6, 1.75, 3.0), WOOD.darkened(0.15), 0.85)
	banner(root, Vector3(-3.0, 0.4, 3.0), 3.4, team_col, 1.3)
	barrel(root, Vector3(3.0, 0.4, 3.1))
	barrel(root, Vector3(2.5, 0.4, 3.2), Color(0.5, 0.3, 0.2))


# المطار: حظيرة مقوّسة وبرج مراقبة ومهبط مروحيات ومدرج
static func _airfield(root: Node3D, team_col: Color) -> void:
	foundation(root, 6.8)
	box(root, Vector3(6.5, 0.3, 6.5), Vector3(0, 0.15, 0), Color(0.40, 0.40, 0.39), 0.9)
	for k in range(5):
		box(root, Vector3(0.2, 0.04, 0.9), Vector3(1.9, 0.33, -2.5 + k * 1.25), Color(0.94, 0.94, 0.9), 0.8)
	box(root, Vector3(0.12, 0.04, 6.2), Vector3(0.9, 0.33, 0), Color(0.94, 0.94, 0.9), 0.8)
	box(root, Vector3(0.12, 0.04, 6.2), Vector3(2.9, 0.33, 0), Color(0.94, 0.94, 0.9), 0.8)
	# الحظيرة
	var hg := node(root, Vector3(-1.5, 0, -1.2))
	box(hg, Vector3(4.2, 1.6, 3.6), Vector3(0, 0.95, 0), Color(0.55, 0.53, 0.48), 0.85)
	cyl(hg, 2.0, 2.0, 3.6, Vector3(0, 1.75, 0), Color(0.76, 0.72, 0.62), 0.7, 0.1, Vector3(PI / 2.0, 0, 0))
	for k in range(7):
		cyl(hg, 2.04, 2.04, 0.08, Vector3(0, 1.75, -1.6 + k * 0.53), Color(0.55, 0.52, 0.45), 0.7, 0.2, Vector3(PI / 2.0, 0, 0))
	box(hg, Vector3(4.2, 0.2, 3.6), Vector3(0, 0.15, 0), Color(0.5, 0.48, 0.44), 0.9)
	box(hg, Vector3(3.0, 1.8, 0.16), Vector3(0, 1.1, 1.85), Color(0.2, 0.2, 0.2), 0.7, 0.2)
	cyl(hg, 1.5, 1.5, 0.16, Vector3(0, 2.0, 1.85), Color(0.2, 0.2, 0.2), 0.7, 0.2, Vector3(PI / 2.0, 0, 0))
	for k in range(6):
		box(hg, Vector3(2.9, 0.04, 0.2), Vector3(0, 0.5 + k * 0.28, 1.9), IRON, 0.5, 0.3)
	box(hg, Vector3(3.4, 0.14, 0.2), Vector3(0, 3.38, 1.9), team_col, 0.6)
	# برج المراقبة
	cyl(root, 0.35, 0.48, 3.5, Vector3(2.5, 2.0, 2.4), Color(0.8, 0.76, 0.68), 0.8)
	cyl(root, 0.7, 0.55, 0.5, Vector3(2.5, 3.95, 2.4), Color(0.7, 0.66, 0.58), 0.8)
	cyl(root, 0.72, 0.72, 0.7, Vector3(2.5, 4.55, 2.4), GLASS, 0.1, 0.3)
	for k in range(4):
		var a: float = float(k) * PI / 2.0
		box(root, Vector3(0.06, 0.74, 0.06), Vector3(2.5 + cos(a) * 0.72, 4.55, 2.4 + sin(a) * 0.72), DARK, 0.6)
	cyl(root, 0.9, 0.9, 0.14, Vector3(2.5, 4.97, 2.4), team_col, 0.6)
	cyl(root, 0.03, 0.03, 1.3, Vector3(2.5, 5.7, 2.4), IRON, 0.5, 0.2)
	dish(root, Vector3(2.5, 5.0, 2.4), 0.3, 0.8)
	# مهبط المروحيات
	cyl(root, 1.0, 1.0, 0.05, Vector3(-2.0, 0.34, 2.4), Color(0.3, 0.3, 0.3), 0.9)
	cyl(root, 0.86, 0.86, 0.06, Vector3(-2.0, 0.355, 2.4), Color(0.95, 0.85, 0.2), 0.8)
	cyl(root, 0.8, 0.8, 0.07, Vector3(-2.0, 0.37, 2.4), Color(0.3, 0.3, 0.3), 0.9)
	box(root, Vector3(0.1, 0.08, 0.7), Vector3(-2.22, 0.4, 2.4), Color(0.95, 0.95, 0.9), 0.8)
	box(root, Vector3(0.1, 0.08, 0.7), Vector3(-1.78, 0.4, 2.4), Color(0.95, 0.95, 0.9), 0.8)
	box(root, Vector3(0.46, 0.08, 0.1), Vector3(-2.0, 0.4, 2.4), Color(0.95, 0.95, 0.9), 0.8)
	# صهريج وقود وكيس رياح وإنارة
	cyl(root, 0.4, 0.4, 1.4, Vector3(0.0, 0.8, 2.8), Color(0.62, 0.6, 0.55), 0.55, 0.3, Vector3(0, 0, PI / 2.0))
	box(root, Vector3(0.5, 0.45, 0.55), Vector3(-0.8, 0.6, 2.8), team_col, 0.6)
	cyl(root, 0.03, 0.03, 1.8, Vector3(3.0, 1.2, -2.8), IRON, 0.5, 0.2)
	cyl(root, 0.0, 0.18, 0.6, Vector3(3.3, 2.0, -2.8), Color(1.0, 0.45, 0.15), 0.8, 0.0, Vector3(0, 0, PI / 2.0))
	banner(root, Vector3(0.0, 0.3, 3.0), 3.0, team_col, 1.3)
	lamp(root, Vector3(3.1, 0.3, 0.0))
	lamp(root, Vector3(3.1, 0.3, -1.6))


# برج الدفاع: برج حجري ببرج رماية دوّار
static func _tower(root: Node3D, team_col: Color) -> void:
	foundation(root, 2.8)
	cyl(root, 1.05, 1.2, 0.5, Vector3(0, 0.25, 0), STONE, 0.9)
	cyl(root, 0.82, 1.0, 2.7, Vector3(0, 1.75, 0), SAND, 0.9)
	for k in range(4):
		cyl(root, 0.86 - k * 0.005, 0.86, 0.05, Vector3(0, 0.8 + k * 0.6, 0), SAND_D, 0.95)
	for k in range(4):
		var a: float = float(k) * PI / 2.0 + 0.4
		box(root, Vector3(0.1, 0.45, 0.1), Vector3(cos(a) * 0.86, 2.1, sin(a) * 0.86), Color(0.1, 0.1, 0.1), 0.5, 0.0, Vector3(0, -a, 0))
	box(root, Vector3(0.5, 0.9, 0.1), Vector3(0, 0.95, 0.92), WOOD, 0.8)
	cyl(root, 1.12, 1.0, 0.3, Vector3(0, 3.25, 0), STONE, 0.9)
	cyl(root, 1.1, 1.1, 0.08, Vector3(0, 3.42, 0), SAND_D, 0.9)
	merlons(root, 1.9, 1.9, 3.7, SAND_D, 0.4)
	sandbags(root, Vector3(-0.5, 3.5, 0.8), 3)
	var t := node(root, Vector3(0, 3.55, 0))
	cyl(t, 0.3, 0.38, 0.45, Vector3(0, 0.1, 0), IRON, 0.5, 0.25)
	sph(t, 0.42, Vector3(0, 0.45, 0), IRON, Vector3(1, 0.7, 1), 0.5, 0.25)
	cyl(t, 0.07, 0.09, 1.7, Vector3(0, 0.5, 1.0), DARK, 0.4, 0.25, Vector3(PI / 2.0, 0, 0))
	cyl(t, 0.12, 0.12, 0.3, Vector3(0, 0.5, 1.85), DARK, 0.4, 0.25, Vector3(PI / 2.0, 0, 0))
	box(t, Vector3(0.7, 0.55, 0.06), Vector3(0, 0.55, 0.45), IRON.darkened(0.1), 0.5, 0.3)
	box(t, Vector3(0.28, 0.2, 0.3), Vector3(-0.45, 0.35, 0.0), Color(0.3, 0.33, 0.22), 0.8)
	box(t, Vector3(0.6, 0.16, 0.6), Vector3(0, 0.82, -0.1), team_col, 0.6)
	banner(root, Vector3(0.85, 3.5, 0.85), 2.0, team_col, 0.9)


static func darken(n: Node, f: float) -> void:
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n
		if mi.material_override is StandardMaterial3D:
			var sm: StandardMaterial3D = mi.material_override.duplicate()
			sm.albedo_color = sm.albedo_color.darkened(f)
			sm.emission_enabled = false
			mi.material_override = sm
	for c in n.get_children():
		darken(c, f)
