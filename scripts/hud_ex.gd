class_name HudEx
extends Hud
## واجهة محسّنة:
## - القائمة الرئيسية بعبارة «صنع في العراق» فقط، وشاشة اللعب نظيفة بلا شعار ولا علم
## - زر إيقاف دائري بأيقونة ⏸ وقائمة إيقاف احترافية، والصوت يُضبط من الإعدادات فقط
## - إعدادات: الصوت والصورة (سطوع/تباين/تشبع) وجودة اللعبة ومعدل الإطارات (تُطبَّق فعلياً مع عداد إطارات حي)
## - معاينة الوحدات تُؤطَّر تلقائياً (إصلاح ظهور الجنود في الثكنة)

var gfx_quality_btns: Array = []
var gfx_fps_btns: Array = []
var lbl_quality_hint: Label
var lbl_bright: Label
var lbl_contrast: Label
var lbl_sat: Label
var sl_bright: HSlider
var sl_contrast: HSlider
var sl_sat: HSlider
var fps_lbl: Label
var lbl_fps_live: Label
var lbl_fps_hint: Label
var fps_toggle_btn: Button


# أيقونة الإيقاف: شريطان رأسيان
class PauseIcon extends Control:
	func _ready() -> void:
		resized.connect(queue_redraw)

	func _draw() -> void:
		var bw: float = size.x * 0.13
		var bh: float = size.y * 0.42
		var y0: float = (size.y - bh) * 0.5
		var gap: float = size.x * 0.09
		var col := Color(0.97, 0.92, 0.78)
		draw_rect(Rect2(size.x * 0.5 - gap - bw, y0, bw, bh), col)
		draw_rect(Rect2(size.x * 0.5 + gap, y0, bw, bh), col)


# ---------- شاشة اللعب: بلا شعار، وزر إيقاف احترافي ----------
func _build_hud() -> void:
	super._build_hud()
	for c in hud_root.get_children():
		if c is IraqBadge:
			c.queue_free()
		elif c is Label and (c as Label).text == "v" + Data.VERSION:
			c.queue_free()
		elif c is HBoxContainer:
			var has_pause := false
			for b in c.get_children():
				if b is Button and (b as Button).text == "إيقاف":
					has_pause = true
			if has_pause:
				for b in c.get_children():
					b.queue_free()
				c.add_child(_pause_button())
	GameSettings.load_cfg()
	fps_lbl = _lbl("", 16, Color(0.8, 0.95, 0.8))
	fps_lbl.position = Vector2(14, 8)
	fps_lbl.visible = GameSettings.show_fps
	hud_root.add_child(fps_lbl)
	var tm := Timer.new()
	tm.wait_time = 0.5
	tm.process_mode = Node.PROCESS_MODE_ALWAYS
	tm.timeout.connect(_tick_fps)
	add_child(tm)
	tm.start()


func _tick_fps() -> void:
	var f: int = int(Engine.get_frames_per_second())
	if fps_lbl != null and fps_lbl.visible:
		fps_lbl.text = "%d FPS" % f
	if lbl_fps_live != null and settings_box != null and settings_box.visible:
		lbl_fps_live.text = "المعدل الحالي: %d إطار/ث" % f


func _pause_button() -> Button:
	var b := _btn("", func(): g.pause_game(), Vector2(60, 60), 15)
	b.add_theme_stylebox_override("normal", _style(INK, GOLD, 30, 2))
	b.add_theme_stylebox_override("hover", _style(Color(0.12, 0.16, 0.18, 0.98), GOLD.lightened(0.2), 30, 2))
	b.add_theme_stylebox_override("pressed", _style(Color(0.2, 0.24, 0.22, 0.98), Color.WHITE, 30, 2))
	var ic := PauseIcon.new()
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	b.pressed.connect(func(): Sfx.play("click"))
	return b


func toast(msg: String) -> void:
	var m: String = msg
	if msg == "اجمع الذهب بالشاحنات ودمّر مقرات العدو":
		var soldiers := 0
		var trucks := 0
		for u in g.units:
			if u.team == 0 and not u.dead:
				if u.is_truck:
					trucks += 1
				else:
					soldiers += 1
		m = "هديتك: %d جنود و%d شاحنة ذهب. درّب المزيد حسب ذهبك" % [soldiers, trucks]
	super.toast(m)


# ---------- قائمة الإيقاف ----------
func _build_overlays() -> void:
	super._build_overlays()
	var old_idx: int = pause_box.get_index()
	pause_box.queue_free()
	pause_box = _build_pause_menu()
	move_child(pause_box, old_idx)
	pause_box.visible = false


func _pbtn(text: String, cb: Callable, sz: Vector2, fs: int, sound := true) -> Button:
	var b := _btn(text, cb, sz, fs)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if sound:
		b.pressed.connect(func(): Sfx.play("click"))
	return b


func _pause_head(text: String) -> Label:
	var l := _lbl(text, 17, Color(0.74, 0.86, 0.82))
	return l


func _build_pause_menu() -> Control:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.04, 0.08, 0.8)
	_full(bg)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	var cc := CenterContainer.new()
	_full(cc)
	bg.add_child(cc)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _style(Color(0.06, 0.09, 0.11, 0.98), GOLD, 6, 2))
	pc.custom_minimum_size = Vector2(560, 0)
	cc.add_child(pc)
	var mg := MarginContainer.new()
	mg.add_theme_constant_override("margin_left", 24)
	mg.add_theme_constant_override("margin_right", 24)
	mg.add_theme_constant_override("margin_top", 16)
	mg.add_theme_constant_override("margin_bottom", 18)
	pc.add_child(mg)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	mg.add_child(v)
	var t := _lbl("اللعبة متوقفة", 36, GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var resume := _pbtn("متابعة اللعب", func(): g.resume_game(), Vector2(500, 64), 26)
	_seg_style(resume, true)
	v.add_child(resume)
	v.add_child(_pbtn("الإعدادات", func(): open_settings(), Vector2(500, 52), 20, false))
	v.add_child(_pause_head("الحفظ"))
	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 10)
	v.add_child(r1)
	r1.add_child(_pbtn("حفظ في خانة جديدة", func(): g.save_game(true), Vector2(240, 52), 17))
	pause_update_btn = _pbtn("تحديث الحفظ الحالي", func(): g.save_game(true, g.cur_slot), Vector2(240, 52), 17)
	r1.add_child(pause_update_btn)
	v.add_child(_pause_head("الخروج"))
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 10)
	v.add_child(r2)
	r2.add_child(_pbtn("حفظ والخروج للقائمة", func(): g.save_and_menu(), Vector2(240, 52), 17))
	var ex := _confirm_btn("خروج بدون حفظ", "اضغط للتأكيد: سيضيع التقدم", func(): g.to_menu(), Vector2(240, 52), 17)
	ex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r2.add_child(ex)
	return bg


# ---------- الإعدادات: صوت وصورة وجودة وأداء ----------
func _range_slider(lo: float, hi: float, st: float, init: float, cb: Callable) -> HSlider:
	var sl := HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = st
	sl.set_value_no_signal(init)
	sl.custom_minimum_size = Vector2(420, 44)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.add_theme_stylebox_override("slider", _style(Color(0.08, 0.12, 0.2), Color(0.5, 0.4, 0.2), 6, 1))
	sl.add_theme_stylebox_override("grabber_area", _style(Color(0.88, 0.69, 0.31), Color(0.88, 0.69, 0.31), 6, 0))
	sl.add_theme_stylebox_override("grabber_area_highlight", _style(Color(0.95, 0.8, 0.4), Color(0.95, 0.8, 0.4), 6, 0))
	sl.add_theme_icon_override("grabber", _grabber())
	sl.add_theme_icon_override("grabber_highlight", _grabber())
	sl.value_changed.connect(cb)
	sl.drag_ended.connect(func(_c): Sfx.play("tick"))
	return sl


func _build_settings() -> void:
	GameSettings.load_cfg()
	var o := _overlay("الإعدادات", 700.0)
	settings_box = o[0]
	var v: VBoxContainer = o[1]
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 400)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 10)
	sc.add_child(inner)

	inner.add_child(_section("01", "الصوت"))
	lbl_music = _lbl("", 20)
	inner.add_child(lbl_music)
	inner.add_child(_slider(Sfx.music_vol * 100.0, func(x: float): _set_music(x)))
	lbl_sfx = _lbl("", 20)
	inner.add_child(lbl_sfx)
	inner.add_child(_slider(Sfx.sfx_vol * 100.0, func(x: float): _set_sfx(x)))
	_update_vol_labels()

	inner.add_child(_section("02", "الصورة"))
	lbl_bright = _lbl("", 20)
	inner.add_child(lbl_bright)
	sl_bright = _range_slider(70.0, 130.0, 5.0, GameSettings.brightness * 100.0, func(x: float): _on_bright(x))
	inner.add_child(sl_bright)
	lbl_contrast = _lbl("", 20)
	inner.add_child(lbl_contrast)
	sl_contrast = _range_slider(80.0, 130.0, 5.0, GameSettings.contrast * 100.0, func(x: float): _on_contrast(x))
	inner.add_child(sl_contrast)
	lbl_sat = _lbl("", 20)
	inner.add_child(lbl_sat)
	sl_sat = _range_slider(50.0, 150.0, 5.0, GameSettings.saturation * 100.0, func(x: float): _on_sat(x))
	inner.add_child(sl_sat)
	var rb := _btn("استعادة الصورة الافتراضية", func(): _reset_image(), Vector2(320, 44), 17)
	var rbr := HBoxContainer.new()
	rbr.alignment = BoxContainer.ALIGNMENT_CENTER
	rbr.add_child(rb)
	inner.add_child(rbr)

	inner.add_child(_section("03", "جودة اللعبة"))
	var qrow := HBoxContainer.new()
	qrow.add_theme_constant_override("separation", 8)
	inner.add_child(qrow)
	gfx_quality_btns.clear()
	for i in range(GameSettings.QUALITY_NAMES.size()):
		var qb := _btn(str(GameSettings.QUALITY_NAMES[i]), func(): _set_quality(i), Vector2(120, 50), 18)
		qb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		qrow.add_child(qb)
		gfx_quality_btns.append(qb)
	lbl_quality_hint = _lbl("", 15, Color(0.75, 0.86, 0.82))
	lbl_quality_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_quality_hint.custom_minimum_size = Vector2(620, 0)
	inner.add_child(lbl_quality_hint)

	inner.add_child(_section("04", "معدل الإطارات"))
	var frow := HBoxContainer.new()
	frow.add_theme_constant_override("separation", 8)
	inner.add_child(frow)
	gfx_fps_btns.clear()
	for i in range(GameSettings.FPS_VALUES.size()):
		var fb := _btn(str(GameSettings.FPS_NAMES[i]), func(): _set_fps(i), Vector2(120, 50), 19)
		fb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		frow.add_child(fb)
		gfx_fps_btns.append(fb)
	lbl_fps_hint = _lbl("", 15, Color(0.75, 0.86, 0.82))
	lbl_fps_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_fps_hint.custom_minimum_size = Vector2(620, 0)
	inner.add_child(lbl_fps_hint)
	lbl_fps_live = _lbl("", 17, Color(0.62, 0.95, 0.7))
	inner.add_child(lbl_fps_live)
	fps_toggle_btn = _btn("", func(): _toggle_fps(), Vector2(380, 44), 17)
	var tr_row := HBoxContainer.new()
	tr_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tr_row.add_child(fps_toggle_btn)
	inner.add_child(tr_row)
	_refresh_gfx_ui()

	var back := _btn("رجوع", func(): close_settings(), Vector2(300, 54), 22)
	var br := HBoxContainer.new()
	br.alignment = BoxContainer.ALIGNMENT_CENTER
	br.add_child(back)
	v.add_child(br)


func _update_vol_labels() -> void:
	lbl_music.text = "الموسيقى: %d٪" % int(Sfx.music_vol * 100.0 + 0.5)
	lbl_sfx.text = "المؤثرات: %d٪" % int(Sfx.sfx_vol * 100.0 + 0.5)


func _refresh_gfx_ui() -> void:
	lbl_bright.text = "السطوع: %d٪" % int(GameSettings.brightness * 100.0 + 0.5)
	lbl_contrast.text = "التباين: %d٪" % int(GameSettings.contrast * 100.0 + 0.5)
	lbl_sat.text = "التشبع: %d٪" % int(GameSettings.saturation * 100.0 + 0.5)
	for i in range(gfx_quality_btns.size()):
		_seg_style(gfx_quality_btns[i], i == GameSettings.quality)
	lbl_quality_hint.text = str(GameSettings.QUALITY_HINTS[GameSettings.quality])
	var fi: int = GameSettings.fps_index()
	for i in range(gfx_fps_btns.size()):
		_seg_style(gfx_fps_btns[i], i == fi)
	lbl_fps_hint.text = str(GameSettings.FPS_HINTS[fi])
	lbl_fps_live.text = "المعدل الحالي: %d إطار/ث" % int(Engine.get_frames_per_second())
	fps_toggle_btn.text = "عداد الإطارات أثناء اللعب: " + ("مفعّل" if GameSettings.show_fps else "معطّل")
	if fps_lbl != null:
		fps_lbl.visible = GameSettings.show_fps


func _apply_gfx() -> void:
	GameSettings.save_cfg()
	GameSettings.apply(g)
	_refresh_gfx_ui()


func _on_bright(x: float) -> void:
	GameSettings.brightness = x / 100.0
	_apply_gfx()


func _on_contrast(x: float) -> void:
	GameSettings.contrast = x / 100.0
	_apply_gfx()


func _on_sat(x: float) -> void:
	GameSettings.saturation = x / 100.0
	_apply_gfx()


func _reset_image() -> void:
	GameSettings.reset_image()
	sl_bright.set_value_no_signal(100.0)
	sl_contrast.set_value_no_signal(100.0)
	sl_sat.set_value_no_signal(100.0)
	Sfx.play("ok")
	_apply_gfx()


func _set_quality(q: int) -> void:
	GameSettings.quality = q
	Sfx.play("pick_mode")
	_apply_gfx()


func _set_fps(i: int) -> void:
	GameSettings.fps = int(GameSettings.FPS_VALUES[i])
	Sfx.play("pick_mode")
	_apply_gfx()


func _toggle_fps() -> void:
	GameSettings.show_fps = not GameSettings.show_fps
	Sfx.play("pick_mode")
	_apply_gfx()


# ---------- معاينة الوحدات والمباني ----------
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
