class_name Terrain
extends Node3D
## تضاريس 3D مستوية بالكامل: لا ماء ولا جبال ولا مرتفعات. أرض رملية وعشب وغابات نخيل وطرق وآثار.
## الأنواع: 0 رمل، 1 عشب، 2 صخر، 3 ماء، 4 جسر، 5 غابة، 6 معلم أثري
## build_block: 1 = لا يمكن البناء (شجر أو حجر أو أثر)

const SHADER_T := preload("res://shaders/terrain.gdshader")
const FLAT_Y := 1.0   # ارتفاع الأرض الثابت (فوق حدّ الرطوبة في الشيدر فلا تظهر الأرض داكنة)
const CHUNK := 64.0

var n: int = Data.MAP
var types := PackedByteArray()
var heights := PackedFloat32Array()
var road_w := PackedFloat32Array()
var build_block := PackedByteArray()
var terr_mat: ShaderMaterial
var height_tex: ImageTexture
var landmarks: Array = []
var bridge_rows: Array = []
var prog := Callable()


func idx(x: int, y: int) -> int:
	return y * n + x


func _p(v: float, text: String) -> void:
	if prog.is_valid():
		prog.call(v, text)


func generate(seed_val: int, progress: Callable) -> void:
	prog = progress
	bridge_rows = []
	build_block.resize(n * n)
	build_block.fill(0)
	await _gen_types(seed_val)
	await _gen_heights(seed_val)
	_p(0.6, "جاري بناء سطح الأرض...")
	await get_tree().process_frame
	await _build_mesh()
	_build_ground()
	_p(0.8, "جاري زرع النخيل وبناء الآثار...")
	await get_tree().process_frame
	await _build_details(seed_val)
	_p(0.92, "اكتمل تشكيل الخريطة")


func set_fog(tex: Texture2D) -> void:
	terr_mat.set_shader_parameter("fog_tex", tex)
	terr_mat.set_shader_parameter("map_size", n * Data.CELL)


func _noise(sd: int, freq: float, oct: int) -> FastNoiseLite:
	var f := FastNoiseLite.new()
	f.seed = sd
	f.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	f.frequency = freq / Data.K
	f.fractal_type = FastNoiseLite.FRACTAL_FBM
	f.fractal_octaves = oct
	return f


func _hs(x: int, y: int) -> float:
	var h: int = (x * 374761393) ^ (y * 668265263)
	h = (h ^ (h >> 13)) * 1274126177
	return float((h ^ (h >> 16)) & 0xFFFF) / 65535.0


func _gen_types(seed_val: int) -> void:
	var K: float = Data.K
	var nb := _noise(seed_val, 0.012, 4)
	var nd := _noise(seed_val + 11, 0.035, 3)
	types.resize(n * n)
	for y in n:
		if y % 24 == 0:
			_p(0.02 + 0.26 * float(y) / n, "جاري تجهيز الأرض المستوية...")
			await get_tree().process_frame
		for x in n:
			var v: float = (nb.get_noise_2d(x, y) * 0.65 + nd.get_noise_2d(x, y) * 0.35) * 0.5 + 0.5
			var t := 0
			if v < 0.33:
				t = 1
			if t == 1 and _hs(x, y) > 0.42:
				t = 5
			types[idx(x, y)] = t
	_carve_roads()
	for b in Data.BASES:
		var bx: int = b.x + 1
		var by2: int = b.y + 1
		for y in range(by2 - 15, by2 + 16):
			for x in range(bx - 15, bx + 16):
				if x >= 0 and y >= 0 and x < n and y < n and (x - bx) * (x - bx) + (y - by2) * (y - by2) < 200:
					types[idx(x, y)] = 1 if (x * 7 + y * 3) % 11 == 0 else 0
	for m in Data.MINES:
		for y in range(m.y - 2, m.y + 4):
			for x in range(m.x - 2, m.x + 4):
				if x >= 0 and y >= 0 and x < n and y < n:
					types[idx(x, y)] = 0
	landmarks = []
	for lm in [Vector2i(66, 142), Vector2i(188, 112), Vector2i(60, 70), Vector2i(194, 184), Vector2i(128, 20), Vector2i(128, 232), Vector2i(100, 100), Vector2i(160, 156)]:
		var p := Vector2i(roundi(lm.x * K), roundi(lm.y * K))
		var ok := true
		for b in Data.BASES:
			if Vector2(p).distance_to(Vector2(b)) < 40.0:
				ok = false
		if ok:
			landmarks.append(p)
	for lm in landmarks:
		for y in range(lm.y, lm.y + 5):
			for x in range(lm.x, lm.x + 5):
				types[idx(x, y)] = 6
				build_block[idx(x, y)] = 1


func _sv(a: Array) -> Array:
	var out: Array = []
	for p in a:
		out.append(Vector2(p.x * Data.K, p.y * Data.K))
	return out


func _carve_roads() -> void:
	road_w.resize(n * n)
	road_w.fill(0.0)
	var B: Array = Data.BASES
	var c0 := Vector2(B[0].x + 1, B[0].y + 1)
	var c1 := Vector2(B[1].x + 1, B[1].y + 1)
	var c2 := Vector2(B[2].x + 1, B[2].y + 1)
	var c3 := Vector2(B[3].x + 1, B[3].y + 1)
	_stamp_road([c0] + _sv([Vector2(66, 190), Vector2(96, 166), Vector2(128, 164), Vector2(164, 150), Vector2(192, 104), Vector2(206, 66)]) + [c2])
	_stamp_road([c0] + _sv([Vector2(44, 160), Vector2(80, 130), Vector2(128, 128), Vector2(176, 128), Vector2(206, 92)]) + [c2])
	_stamp_road([c0] + _sv([Vector2(28, 170), Vector2(26, 120), Vector2(30, 80)]) + [c1])
	_stamp_road([c3] + _sv([Vector2(228, 170), Vector2(230, 120), Vector2(226, 80)]) + [c2])
	_stamp_road([c1] + _sv([Vector2(76, 70), Vector2(110, 88), Vector2(128, 92), Vector2(150, 70), Vector2(180, 52)]) + [c2])
	_stamp_road([c0] + _sv([Vector2(80, 236), Vector2(128, 208), Vector2(176, 238)]) + [c3])


func _stamp_road(pts: Array) -> void:
	for k in range(pts.size() - 1):
		var p0: Vector2 = pts[k]
		var p1: Vector2 = pts[k + 1]
		var steps: int = int(p0.distance_to(p1) * 2.0)
		for s in range(steps + 1):
			var p: Vector2 = p0.lerp(p1, float(s) / maxf(float(steps), 1.0))
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					var cx: int = int(p.x) + dx
					var cy: int = int(p.y) + dy
					if cx < 1 or cy < 1 or cx >= n - 1 or cy >= n - 1:
						continue
					var d: float = Vector2(cx + 0.5, cy + 0.5).distance_to(p)
					var i := idx(cx, cy)
					if d <= 2.4:
						var t: int = types[i]
						if t == 3:
							var ed: int = mini(mini(cx, cy), mini(n - 1 - cx, n - 1 - cy))
							if ed >= 40:
								types[i] = 4
						elif t == 2 or t == 5 or t == 6:
							types[i] = 0
					if d <= 3.4:
						road_w[i] = maxf(road_w[i], 1.0 - d / 3.4)


func _gen_heights(_seed_val: int) -> void:
	var w := n + 1
	heights.resize(w * w)
	heights.fill(FLAT_Y)
	var img := Image.create_from_data(w, w, false, Image.FORMAT_RF, heights.to_byte_array())
	img.convert(Image.FORMAT_RH)
	height_tex = ImageTexture.create_from_image(img)


func height_at(x: float, z: float) -> float:
	var w := n + 1
	var fx: float = clampf(x / Data.CELL, 0.0, float(n) - 0.001)
	var fz: float = clampf(z / Data.CELL, 0.0, float(n) - 0.001)
	var i: int = int(fx)
	var j: int = int(fz)
	var tx: float = fx - i
	var tz: float = fz - j
	var h00: float = heights[j * w + i]
	var h10: float = heights[j * w + i + 1]
	var h01: float = heights[(j + 1) * w + i]
	var h11: float = heights[(j + 1) * w + i + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


# أدنى وأعلى ارتفاع تحت مبنى (x = الأدنى، y = الأعلى)
func footprint(c: Vector2i, s: int) -> Vector2:
	var w := n + 1
	var lo := 1e9
	var hi := -1e9
	for j in range(c.y, c.y + s + 1):
		for i in range(c.x, c.x + s + 1):
			var h: float = heights[j * w + i]
			lo = minf(lo, h)
			hi = maxf(hi, h)
	return Vector2(lo, hi)


func type_color(t: int) -> Color:
	match t:
		1:
			return Color(0.42, 0.56, 0.24)
		2:
			return Color(0.56, 0.46, 0.36)
		3:
			return Color(0.55, 0.47, 0.33)
		4:
			return Color(0.46, 0.37, 0.27)
		5:
			return Color(0.27, 0.42, 0.17)
		6:
			return Color(0.72, 0.62, 0.44)
	return Color(0.87, 0.73, 0.49)


func _build_mesh() -> void:
	var w := n + 1
	var tcol: Array = []
	for t in range(7):
		tcol.append(type_color(t))
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	verts.resize(w * w)
	norms.resize(w * w)
	cols.resize(w * w)
	for j in w:
		if j % 30 == 0:
			_p(0.6 + 0.2 * float(j) / w, "جاري بناء سطح الأرض...")
			await get_tree().process_frame
		for i in w:
			var k: int = j * w + i
			var hh: float = heights[k]
			verts[k] = Vector3(i * Data.CELL, hh, j * Data.CELL)
			var hl: float = heights[j * w + maxi(i - 1, 0)]
			var hr: float = heights[j * w + mini(i + 1, w - 1)]
			var hu: float = heights[maxi(j - 1, 0) * w + i]
			var hd: float = heights[mini(j + 1, w - 1) * w + i]
			norms[k] = Vector3(hl - hr, 2.0 * Data.CELL, hu - hd).normalized()
			var c := Color(0, 0, 0)
			var cnt := 0.0
			var rd := 0.0
			for dj in range(-1, 1):
				for di in range(-1, 1):
					var cx: int = i + di
					var cy: int = j + dj
					if cx < 0 or cy < 0 or cx >= n or cy >= n:
						continue
					var ci := idx(cx, cy)
					c += tcol[types[ci]]
					rd = maxf(rd, road_w[ci])
					cnt += 1.0
			c = c / maxf(cnt, 1.0)
			c = c.lerp(Color(0.64, 0.52, 0.35), rd * 0.7)
			if hh < 3.0:
				c = c * (0.9 + clampf(hh / 2.5, 0.0, 1.0) * 0.18)
			else:
				c = c.lerp(Color(0.72, 0.62, 0.49), clampf((hh - 3.0) / 16.0, 0.0, 0.5))
			var v: float = 0.92 + _hs(i, j) * 0.16
			cols[k] = Color(c.r * v, c.g * v, c.b * v, 1.0)
	var indices := PackedInt32Array()
	indices.resize(n * n * 6)
	var q := 0
	for j in n:
		for i in n:
			var a: int = j * w + i
			var b: int = a + 1
			var c2: int = a + w
			var d2: int = c2 + 1
			indices[q] = a
			indices[q + 1] = b
			indices[q + 2] = c2
			indices[q + 3] = b
			indices[q + 4] = d2
			indices[q + 5] = c2
			q += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = indices
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	terr_mat = ShaderMaterial.new()
	terr_mat.shader = SHADER_T
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = terr_mat
	add_child(mi)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = m.create_trimesh_shape()
	body.add_child(cs)
	add_child(body)


# أرض مستوية ممتدة خارج حدود الخريطة بدل البحر القديم
func _build_ground() -> void:
	var ws: float = n * Data.CELL
	var pm := PlaneMesh.new()
	pm.size = Vector2(5200.0, 5200.0)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.5, 0.42, 0.29)
	gm.roughness = 1.0
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = gm
	mi.position = Vector3(ws * 0.5, FLAT_Y - 0.08, ws * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# ---------- النباتات والصخور والجسور والآثار ----------
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	st.set_color(col)
	st.add_vertex(a)
	st.set_color(col)
	st.add_vertex(b)
	st.set_color(col)
	st.add_vertex(c)


func _palm_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk_col := Color(0.46, 0.33, 0.2)
	var rings: Array = []
	var seg := 4
	for k in range(seg + 1):
		var t: float = float(k) / float(seg)
		rings.append([Vector3(sin(t * 1.3) * 0.35, t * 3.4, 0.0), lerpf(0.2, 0.1, t)])
	for k in range(seg):
		var a: Array = rings[k]
		var b: Array = rings[k + 1]
		for s in range(5):
			var a0: float = TAU * s / 5.0
			var a1: float = TAU * (s + 1) / 5.0
			var p00: Vector3 = a[0] + Vector3(cos(a0) * a[1], 0, sin(a0) * a[1])
			var p01: Vector3 = a[0] + Vector3(cos(a1) * a[1], 0, sin(a1) * a[1])
			var p10: Vector3 = b[0] + Vector3(cos(a0) * b[1], 0, sin(a0) * b[1])
			var p11: Vector3 = b[0] + Vector3(cos(a1) * b[1], 0, sin(a1) * b[1])
			var shade: Color = trunk_col.darkened(0.12 * float(k % 2))
			_tri(st, p00, p10, p01, shade)
			_tri(st, p01, p10, p11, shade)
	var top: Vector3 = rings[seg][0]
	for f in range(8):
		var ang: float = TAU * f / 8.0 + 0.3
		var dir := Vector3(cos(ang), 0, sin(ang))
		var side := Vector3(-dir.z, 0, dir.x)
		var pts: Array = []
		for k in range(4):
			var t2: float = float(k) / 3.0
			pts.append(top + dir * (t2 * 2.4) + Vector3(0, sin(t2 * PI * 0.8) * 0.85 - t2 * t2 * 1.1, 0))
		var green := Color(0.22, 0.46, 0.15).lerp(Color(0.36, 0.57, 0.2), float(f % 3) / 3.0)
		for k in range(3):
			var w0: float = 0.44 * (1.0 - float(k) / 4.0)
			var w1: float = 0.44 * (1.0 - float(k + 1) / 4.0)
			var q0: Vector3 = pts[k]
			var q1: Vector3 = pts[k + 1]
			_tri(st, q0 - side * w0, q1 - side * w1, q0 + side * w0, green)
			_tri(st, q0 + side * w0, q1 - side * w1, q1 + side * w1, green)
	st.generate_normals()
	return st.commit()


func _blob(st: SurfaceTool, c: Vector3, r: float, sq: float, col: Color, segs := 7, rings := 4) -> void:
	# كتلة أوراق منخفضة التفاصيل (كرة مضغوطة) بتدرج لوني من الأسفل للأعلى
	for j in range(rings):
		var a0: float = PI * float(j) / float(rings)
		var a1: float = PI * float(j + 1) / float(rings)
		for i in range(segs):
			var b0: float = TAU * float(i) / float(segs)
			var b1: float = TAU * float(i + 1) / float(segs)
			var p00 := c + Vector3(sin(a0) * cos(b0) * r, -cos(a0) * r * sq, sin(a0) * sin(b0) * r)
			var p01 := c + Vector3(sin(a0) * cos(b1) * r, -cos(a0) * r * sq, sin(a0) * sin(b1) * r)
			var p10 := c + Vector3(sin(a1) * cos(b0) * r, -cos(a1) * r * sq, sin(a1) * sin(b0) * r)
			var p11 := c + Vector3(sin(a1) * cos(b1) * r, -cos(a1) * r * sq, sin(a1) * sin(b1) * r)
			var shade: Color = col.darkened(0.28 * (1.0 - float(j) / float(rings))).lightened(0.06 * float(j) / float(rings))
			_tri(st, p00, p10, p01, shade)
			_tri(st, p01, p10, p11, shade)


func _trunk(st: SurfaceTool, base: Vector3, top: Vector3, r0: float, r1: float, col: Color) -> void:
	var sides := 5
	for s in range(sides):
		var a0: float = TAU * float(s) / float(sides)
		var a1: float = TAU * float(s + 1) / float(sides)
		var p00: Vector3 = base + Vector3(cos(a0) * r0, 0, sin(a0) * r0)
		var p01: Vector3 = base + Vector3(cos(a1) * r0, 0, sin(a1) * r0)
		var p10: Vector3 = top + Vector3(cos(a0) * r1, 0, sin(a0) * r1)
		var p11: Vector3 = top + Vector3(cos(a1) * r1, 0, sin(a1) * r1)
		_tri(st, p00, p10, p01, col)
		_tri(st, p01, p10, p11, col)


func _acacia_mesh() -> ArrayMesh:
	# شجرة سدر/سنط عراقية: جذع منحنٍ وتاج عريض من كتل خضراء
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bark := Color(0.38, 0.27, 0.17)
	_trunk(st, Vector3(0, 0, 0), Vector3(0.15, 1.5, 0.05), 0.22, 0.14, bark)
	_trunk(st, Vector3(0.15, 1.5, 0.05), Vector3(0.65, 2.3, 0.2), 0.14, 0.08, bark)
	_trunk(st, Vector3(0.15, 1.5, 0.05), Vector3(-0.5, 2.2, -0.2), 0.12, 0.07, bark)
	var leaf := Color(0.30, 0.46, 0.18)
	_blob(st, Vector3(0.1, 2.9, 0.1), 1.35, 0.55, leaf)
	_blob(st, Vector3(1.0, 2.6, 0.3), 0.95, 0.55, leaf.lightened(0.08))
	_blob(st, Vector3(-0.95, 2.55, -0.25), 1.0, 0.55, leaf.darkened(0.05))
	_blob(st, Vector3(0.1, 3.3, -0.5), 0.8, 0.6, leaf.lightened(0.12))
	st.generate_normals()
	return st.commit()


func _poplar_mesh() -> ArrayMesh:
	# شجرة حور/صفصاف طويلة ضيقة
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_trunk(st, Vector3.ZERO, Vector3(0, 1.6, 0), 0.16, 0.1, Color(0.42, 0.34, 0.24))
	var leaf := Color(0.26, 0.44, 0.17)
	_blob(st, Vector3(0, 2.4, 0), 0.8, 1.5, leaf)
	_blob(st, Vector3(0.05, 3.6, 0.0), 0.62, 1.4, leaf.lightened(0.07))
	_blob(st, Vector3(0, 4.6, 0.02), 0.4, 1.2, leaf.lightened(0.12))
	st.generate_normals()
	return st.commit()


func _add_inst(group: Dictionary, wx: float, wz: float, xf: Transform3D, col: Color) -> void:
	var key := Vector2i(int(wx / CHUNK), int(wz / CHUNK))
	if not group.has(key):
		group[key] = {"x": [], "c": []}
	group[key]["x"].append(xf)
	group[key]["c"].append(col)


func _flush(group: Dictionary, mesh: Mesh, mat: Material, vis_end: float, shadows := true) -> void:
	for key in group.keys():
		var xs: Array = group[key]["x"]
		var cs: Array = group[key]["c"]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = xs.size()
		for i in xs.size():
			mm.set_instance_transform(i, xs[i])
			mm.set_instance_color(i, cs[i])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = mat
		mi.visibility_range_end = vis_end
		if not shadows:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


func _veg_mat(double_sided: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	if double_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _near_base(x: int, y: int, r: float) -> bool:
	for b in Data.BASES:
		if absf(x - b.x) < r and absf(y - b.y) < r:
			return true
	return false


func _build_details(seed_val: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val + 99
	var palms := {}
	var bushes := {}
	var rocks := {}
	var planks := {}
	var rails_x := {}
	var rails_z := {}
	var pylons := {}
	var acacias := {}
	var poplars := {}
	var rock_count := 0
	var tn := _noise(seed_val + 77, 0.05, 2)
	for y in n:
		if y % 30 == 0:
			_p(0.8 + 0.1 * float(y) / n, "جاري زرع النخيل وبناء الآثار...")
			await get_tree().process_frame
		for x in n:
			var ci := idx(x, y)
			var t: int = types[ci]
			if t == 4:
				var cxw: float = (x + 0.5) * Data.CELL
				var czw: float = (y + 0.5) * Data.CELL
				_add_inst(planks, cxw, czw, Transform3D(Basis.IDENTITY, Vector3(cxw, 0.3, czw)), Color(0.42, 0.29, 0.17))
				if types[idx(x + 1, y)] == 3:
					_add_inst(rails_x, cxw, czw, Transform3D(Basis.IDENTITY, Vector3((x + 1) * Data.CELL - 0.1, 0.85, czw)), Color(0.34, 0.23, 0.14))
				if types[idx(x - 1, y)] == 3:
					_add_inst(rails_x, cxw, czw, Transform3D(Basis.IDENTITY, Vector3(x * Data.CELL + 0.1, 0.85, czw)), Color(0.34, 0.23, 0.14))
				if types[idx(x, y + 1)] == 3:
					_add_inst(rails_z, cxw, czw, Transform3D(Basis.IDENTITY, Vector3(cxw, 0.85, (y + 1) * Data.CELL - 0.1)), Color(0.34, 0.23, 0.14))
				if types[idx(x, y - 1)] == 3:
					_add_inst(rails_z, cxw, czw, Transform3D(Basis.IDENTITY, Vector3(cxw, 0.85, y * Data.CELL + 0.1)), Color(0.34, 0.23, 0.14))
				if (x + y) % 2 == 0:
					_add_inst(pylons, cxw, czw, Transform3D(Basis.IDENTITY, Vector3(cxw, -1.7, czw)), Color(0.4, 0.34, 0.28))
				continue
			if t == 0 or t == 1 or t == 5:
				if road_w[ci] > 0.05 or _near_base(x, y, 15.0):
					continue
			else:
				continue
			var wx: float = (x + rng.randf()) * Data.CELL
			var wz: float = (y + rng.randf()) * Data.CELL
			var gy: float = height_at(wx, wz)
			var grove: float = smoothstep(0.55, 0.82, tn.get_noise_2d(x, y) * 0.5 + 0.5)
			var roll: float = rng.randf()
			if t == 5:
				# الغابات: نخيل وسدر وحور مختلطة
				if roll < 0.62:
					var s: float = rng.randf_range(0.85, 1.5)
					var rb := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s))
					var shade: float = rng.randf_range(0.85, 1.1)
					if roll < 0.12:
						_add_inst(acacias, wx, wz, Transform3D(rb, Vector3(wx, gy, wz)), Color(shade, shade, shade))
					elif roll < 0.2:
						_add_inst(poplars, wx, wz, Transform3D(rb, Vector3(wx, gy, wz)), Color(shade, shade, shade))
					else:
						_add_inst(palms, wx, wz, Transform3D(rb, Vector3(wx, gy, wz)), Color(shade, shade, shade))
			elif t == 1:
				# العشب: أشجار متفرقة وشجيرات
				if roll < 0.07 + grove * 0.1:
					_plant_tree(rng, wx, wz, gy, palms, acacias, poplars)
					build_block[ci] = 1
				elif roll < 0.3:
					var sb: float = rng.randf_range(0.6, 1.2)
					var gcol := Color(0.3, 0.46, 0.18).lerp(Color(0.45, 0.55, 0.22), rng.randf())
					_add_inst(bushes, wx, wz, Transform3D(Basis.IDENTITY.scaled(Vector3(sb, sb * 0.8, sb)), Vector3(wx, gy + 0.2, wz)), gcol)
			else:
				# الرمل: أشجار منتشرة في كل مكان وتتكاثف في بساتين، والصخور نادرة جداً
				if roll < 0.012 + grove * 0.05:
					_plant_tree(rng, wx, wz, gy, palms, acacias, poplars)
					build_block[ci] = 1
				elif roll < 0.0125 + grove * 0.05 and rock_count < 18 and not _near_base(x, y, 30.0):
					rock_count += 1
					var sr: float = rng.randf_range(0.5, 1.2)
					var rcol := Color(0.55, 0.47, 0.38).lerp(Color(0.68, 0.6, 0.48), rng.randf())
					var rrb := Basis(Vector3(rng.randf() + 0.1, rng.randf(), rng.randf()).normalized(), rng.randf() * TAU).scaled(Vector3(sr * 1.4, sr, sr * 1.1))
					_add_inst(rocks, wx, wz, Transform3D(rrb, Vector3(wx, gy + sr * 0.25, wz)), rcol)
					build_block[ci] = 1
				elif roll < 0.08:
					var sb2: float = rng.randf_range(0.4, 0.8)
					var dcol := Color(0.5, 0.45, 0.25).lerp(Color(0.62, 0.55, 0.33), rng.randf())
					_add_inst(bushes, wx, wz, Transform3D(Basis.IDENTITY.scaled(Vector3(sb2, sb2 * 0.6, sb2)), Vector3(wx, gy + 0.1, wz)), dcol)
	_flush(palms, _palm_mesh(), _veg_mat(true), 170.0)
	_flush(acacias, _acacia_mesh(), _veg_mat(true), 170.0)
	_flush(poplars, _poplar_mesh(), _veg_mat(true), 170.0)
	var bush := SphereMesh.new()
	bush.radius = 0.6
	bush.height = 0.9
	bush.radial_segments = 6
	bush.rings = 3
	_flush(bushes, bush, _veg_mat(false), 110.0, false)
	var rock := SphereMesh.new()
	rock.radius = 0.7
	rock.height = 1.0
	rock.radial_segments = 6
	rock.rings = 3
	_flush(rocks, rock, _veg_mat(false), 150.0, false)
	var plank := BoxMesh.new()
	plank.size = Vector3(Data.CELL, 0.3, Data.CELL)
	_flush(planks, plank, _veg_mat(false), 600.0)
	var rx := BoxMesh.new()
	rx.size = Vector3(0.16, 0.7, Data.CELL)
	_flush(rails_x, rx, _veg_mat(false), 300.0, false)
	var rz := BoxMesh.new()
	rz.size = Vector3(Data.CELL, 0.7, 0.16)
	_flush(rails_z, rz, _veg_mat(false), 300.0, false)
	var py := CylinderMesh.new()
	py.top_radius = 0.28
	py.bottom_radius = 0.3
	py.height = 4.0
	py.radial_segments = 6
	_flush(pylons, py, _veg_mat(false), 300.0, false)
	for lm in landmarks:
		_ziggurat(Vector3((lm.x + 2.5) * Data.CELL, FLAT_Y, (lm.y + 2.5) * Data.CELL))
	_ruins(rng)


func _plant_tree(rng: RandomNumberGenerator, wx: float, wz: float, gy: float, palms: Dictionary, acacias: Dictionary, poplars: Dictionary) -> void:
	var s: float = rng.randf_range(0.8, 1.35)
	var rb := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s))
	var shade: float = rng.randf_range(0.88, 1.1)
	var xf := Transform3D(rb, Vector3(wx, gy, wz))
	var pick: float = rng.randf()
	if pick < 0.45:
		_add_inst(palms, wx, wz, xf, Color(shade, shade, shade))
	elif pick < 0.8:
		_add_inst(acacias, wx, wz, xf, Color(shade, shade, shade))
	else:
		_add_inst(poplars, wx, wz, xf, Color(shade, shade, shade))


func _stone_mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.95
	return m


func _block(parent: Node3D, size: Vector3, pos: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _stone_mat(col)
	mi.position = pos
	parent.add_child(mi)


func _ziggurat(center: Vector3) -> void:
	var root := Node3D.new()
	root.position = center
	add_child(root)
	var col := Color(0.75, 0.63, 0.43)
	_block(root, Vector3(10.4, 2.2, 10.4), Vector3(0, -0.2, 0), col.darkened(0.12))
	var sizes := [9.0, 7.0, 5.0, 3.0]
	var y := 1.3
	for k in range(sizes.size()):
		var s: float = sizes[k]
		_block(root, Vector3(s, 1.7, s), Vector3(0, y, 0), col.darkened(0.04 * float(k)))
		y += 1.7
	_block(root, Vector3(1.8, 1.5, 1.8), Vector3(0, y + 0.1, 0), col.lightened(0.08))
	_block(root, Vector3(2.2, 0.4, 3.0), Vector3(0, 0.9, 5.8), col.darkened(0.15))


func _ruins(rng: RandomNumberGenerator) -> void:
	var placed := 0
	var tries := 0
	while placed < 30 and tries < 900:
		tries += 1
		var x: int = rng.randi_range(40, n - 40)
		var y: int = rng.randi_range(40, n - 40)
		if types[idx(x, y)] != 0 or road_w[idx(x, y)] > 0.05 or _near_base(x, y, 45.0):
			continue
		var ok := true
		for dy in range(-1, 3):
			for dx in range(-1, 3):
				var t: int = types[idx(x + dx, y + dy)]
				if t != 0 or build_block[idx(x + dx, y + dy)] == 1:
					ok = false
		if not ok:
			continue
		var fp: Vector2 = footprint(Vector2i(x, y), 2)
		if fp.y - fp.x > 0.6:
			continue
		var root := Node3D.new()
		var wx: float = (x + 1.0) * Data.CELL
		var wz: float = (y + 1.0) * Data.CELL
		root.position = Vector3(wx, fp.y, wz)
		add_child(root)
		var col := Color(0.78, 0.68, 0.5)
		_block(root, Vector3(4.2, 0.6, 4.2), Vector3(0, 0.0, 0), col.darkened(0.1))
		for k in range(rng.randi_range(3, 5)):
			var cx: float = rng.randf_range(-1.5, 1.5)
			var cz: float = rng.randf_range(-1.5, 1.5)
			var h: float = rng.randf_range(1.6, 3.6)
			var mi := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.34
			cm.bottom_radius = 0.4
			cm.height = h
			cm.radial_segments = 8
			mi.mesh = cm
			mi.material_override = _stone_mat(col)
			if rng.randf() > 0.7:
				mi.rotation = Vector3(0, rng.randf() * TAU, PI / 2.0 - 0.1)
				mi.position = Vector3(cx, 0.55, cz)
			else:
				mi.position = Vector3(cx, h * 0.5 + 0.3, cz)
			root.add_child(mi)
		for dy in range(0, 2):
			for dx in range(0, 2):
				types[idx(x + dx, y + dy)] = 6
		for dy in range(-1, 3):
			for dx in range(-1, 3):
				build_block[idx(x + dx, y + dy)] = 1
		placed += 1
