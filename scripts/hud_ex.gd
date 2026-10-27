class_name HudEx
extends Hud
## واجهة محسّنة: معاينة الوحدات والمباني تُؤطَّر تلقائياً حسب حجم النموذج (كان الجنود يظهرون مقصوصين أو غير ظاهرين)،
## وتدعم نماذج الجنديين الجديدين.


func _model_box(n: Node, inv: Transform3D, out: Array) -> void:
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n
		if mi.mesh != null:
			var bb: AABB = (inv * mi.global_transform) * mi.get_aabb()
			if out.is_empty():
				out.append(bb)
			else:
				out[0] = (out[0] as AABB).merge(bb)
	for c in n.get_children():
		_model_box(c, inv, out)


func _freeze_preview(sv: SubViewport) -> void:
	if is_instance_valid(sv):
		sv.render_target_update_mode = SubViewport.UPDATE_DISABLED


func make_preview(key: String, col: Color, sz: Vector2, building := false) -> Control:
	var tr := TextureRect.new()
	tr.custom_minimum_size = sz
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ck: String = key + ":" + col.to_html(false) + ("b" if building else "u")
	if not prev_cache.has(ck):
		var sv := SubViewport.new()
		sv.own_world_3d = true
		sv.transparent_bg = true
		sv.size = Vector2i(220, 120)
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		prev_root.add_child(sv)
		var root := Node3D.new()
		sv.add_child(root)
		var model: Node3D = Models.building_model(key, col) if building else ModelsEx.unit_model(key, col)
		model.rotation.y = 0.7
		root.add_child(model)
		var env := Environment.new()
		env.background_mode = Environment.BG_CLEAR_COLOR
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.75, 0.75, 0.82)
		env.ambient_light_energy = 0.9
		var we := WorldEnvironment.new()
		we.environment = env
		root.add_child(we)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-35.0, 35.0, 0.0)
		light.light_energy = 1.3
		root.add_child(light)
		# تأطير تلقائي: الكاميرا تبتعد بقدر نصف قطر النموذج ليظهر كاملاً
		var box_out: Array = []
		_model_box(model, root.global_transform.affine_inverse(), box_out)
		var center := Vector3(0, 0.9, 0)
		var radius := 1.5
		if not box_out.is_empty():
			var bb: AABB = box_out[0]
			center = bb.get_center()
			radius = maxf(bb.size.length() * 0.5, 0.6)
		var cam := Camera3D.new()
		cam.fov = 40.0
		cam.near = 0.05
		cam.far = 400.0
		root.add_child(cam)
		var dist: float = radius / sin(deg_to_rad(20.0)) * 0.88
		cam.position = center + Vector3(0.0, 0.38, 1.0).normalized() * dist
		cam.look_at(center, Vector3.UP)
		prev_cache[ck] = sv
		get_tree().create_timer(0.6).timeout.connect(_freeze_preview.bind(sv))
	tr.texture = (prev_cache[ck] as SubViewport).get_texture()
	return tr
