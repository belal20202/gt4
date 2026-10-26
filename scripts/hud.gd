class_name Hud
extends CanvasLayer
## الواجهة: القائمة الرئيسية التفاعلية، شاشة الانتظار، الشريط العلوي، لوحة الأوامر، الخريطة المصغرة

const GOLD := Color(0.96, 0.7, 0.18)
const INK := Color(0.05, 0.08, 0.1, 0.93)
const STEEL := Color(0.3, 0.4, 0.42)
const PANEL := Color(0.07, 0.1, 0.12, 0.95)
const TIPS := [
	"ابنِ مقرات تجميع الذهب قرب المناجم لتزيد دخلك.",
	"قاذفو الصواريخ أفضل سلاح ضد الدبابات والمدرعات.",
	"المقاتلات والمضادات تتفوق على المروحيات.",
	"القناص بعيد المدى ممتاز ضد المشاة لكنه ضعيف أمام الآليات.",
	"أي منطقة تكتشفها تبقى ظاهرة لك دائماً، وكذلك ما يدخلها من العدو.",
	"في نمط 2 ضد 2 يساعدك حليف يقوده الحاسوب بجيشه ومنشآته.",
	"الأشجار والصخور والأرض غير المستوية تمنع البناء.",
	"المدفعية بعيدة المدى وتدمّر المباني، فاحمها بالمشاة والدبابات.",
	"احفظ مبارياتك من قائمة الإيقاف في عدة خانات، وستجدها في «المحفوظات».",
	"الطرق والجسور أسرع طريق نحو قاعدة العدو.",
]

var g: Main
var picked_army := "red"
var picked_diff := "normal"
var picked_mode := "1v1"
var menu: Control
var hud_root: Control
var pause_box: Control
var end_box: Control
var end_title: Label
var end_sub: Label
var lbl_gold: Label
var lbl_trucks: Label
var lbl_time: Label
var lbl_mode: Label
var panel: HBoxContainer
var toast_lbl: Label
var minimap: TextureRect
var box_panel: Panel
var btn_amove: Button
var btn_box: Button
var army_btns := {}
var mode_btns := {}
var diff_btns := {}
var cost_btns: Array = []
var queue_lbl: Label
var sig := ""
var ui_nodes: Array = []
var toast_tween: Tween
var mm_fog: TextureRect
var mm_dots: TextureRect
var loading: Control
var load_bar: ProgressBar
var load_pct: Label
var load_stage: Label
var load_tip: Label
var tip_t := 0.0
var tip_i := 0
var btn_continue: Button
var lbl_army_info: Label
var lbl_mode_info: Label
var lbl_diff_info: Label
var prev_root: Node
var prev_cache := {}
var alert_btn: Button
var alert_tw: Tween
var alert_pos := Vector3.ZERO
var repair_btn: Button
var repair_b = null
var hp_bar: ProgressBar
var hp_fill: StyleBoxFlat
var menu_items: Array = []
var settings_box: Control
var saves_box: Control
var saves_list: VBoxContainer
var pause_update_btn: Button
var lbl_music: Label
var lbl_sfx: Label
var grab_tex: ImageTexture
var title_lbl: Label
var sub_lbl: Label

const PREVIEW_K := {"inf": 0.45, "rpg": 0.45, "sniper": 0.45, "tank": 1.0, "lt": 0.85, "heavy": 1.25, "art": 1.05, "aa": 1.0, "truck": 1.0, "heli": 1.05, "jet": 1.1, "bomber": 1.6, "hq": 1.7, "dep": 1.5, "bar": 1.15, "fac": 1.5, "air": 1.5, "twr": 0.7}


# شريط ألوان الجيش على بطاقة الاختيار
class ArmyBanner extends Control:
	var col := Color.RED

	func _draw() -> void:
		var r := Rect2(Vector2(6, 0), size - Vector2(12, 0))
		draw_rect(r, col)
		draw_rect(Rect2(r.position, Vector2(r.size.x, 6)), col.darkened(0.25))
		draw_rect(Rect2(r.position + Vector2(0, r.size.y - 6), Vector2(r.size.x, 6)), col.darkened(0.25))
		draw_rect(r, Color(0, 0, 0, 0.5), false, 2.0)
		var c := r.get_center()
		var rad: float = minf(r.size.y * 0.38, 20.0)
		var pts := PackedVector2Array()
		for i in range(16):
			var ang: float = i * PI / 8.0 - PI / 2.0
			var rr: float = rad if i % 2 == 0 else rad * 0.45
			pts.append(c + Vector2(cos(ang), sin(ang)) * rr)
		var star_col: Color = col.lightened(0.5) if col.get_luminance() < 0.7 else col.darkened(0.5)
		draw_colored_polygon(pts, star_col)


class Insignia extends Control:
	var col := Color.RED

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.04, 0.06, 0.07))
		draw_rect(Rect2(0, 0, 8, size.y), col)
		draw_rect(r, Color(0.3, 0.4, 0.42), false, 1.0)
		var c := Vector2(size.x * 0.5, size.y * 0.5)
		var rad: float = minf(size.y * 0.36, 20.0)
		var pts := PackedVector2Array()
		for i in range(16):
			var ang: float = float(i) * PI / 8.0 - PI / 2.0
			pts.append(c + Vector2(cos(ang), sin(ang)) * (rad if i % 2 == 0 else rad * 0.45))
		draw_colored_polygon(pts, col.lightened(0.35) if col.get_luminance() < 0.7 else col.darkened(0.3))
		for sx in [-1, 1]:
			for k in range(3):
				var x: float = c.x + float(sx) * (rad + 14.0 + float(k) * 9.0)
				draw_line(Vector2(x, c.y - 9), Vector2(x + 5.0 * float(sx), c.y), col, 2.5)
				draw_line(Vector2(x + 5.0 * float(sx), c.y), Vector2(x, c.y + 9), col, 2.5)


class Brackets extends Control:
	func _draw() -> void:
		var l := 14.0
		var col := Color(0.96, 0.7, 0.18)
		for sx in [0, 1]:
			for sy in [0, 1]:
				var px: float = 2.0 if sx == 0 else size.x - 2.0
				var py: float = 2.0 if sy == 0 else size.y - 2.0
				var dx: float = l if sx == 0 else -l
				var dy: float = l if sy == 0 else -l
				draw_line(Vector2(px, py), Vector2(px + dx, py), col, 3.0)
				draw_line(Vector2(px, py), Vector2(px, py + dy), col, 3.0)


func setup(main: Main) -> void:
	g = main
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_font()
	prev_root = Node.new()
	add_child(prev_root)
	_build_hud()
	_build_menu()
	_build_overlays()
	show_menu()


func _process(delta: float) -> void:
	if menu != null and menu.visible and title_lbl != null:
		var k: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 2.2)
		title_lbl.add_theme_color_override("font_outline_color", Color(0.35 + 0.35 * k, 0.2 + 0.2 * k, 0.03, 0.95))
	if loading != null and loading.visible:
		tip_t += delta
		if tip_t > 3.4:
			tip_t = 0.0
			tip_i = (tip_i + 1) % TIPS.size()
			load_tip.modulate.a = 0.0
			load_tip.text = "نصيحة: " + str(TIPS[tip_i])
			create_tween().tween_property(load_tip, "modulate:a", 1.0, 0.5)


func _apply_font() -> void:
	var path := "res://assets/fonts/arabic.ttf"
	if ResourceLoader.exists(path):
		var th := Theme.new()
		th.default_font = load(path)
		th.default_font_size = 18
		get_tree().root.theme = th


func _style(bg: Color, border: Color, radius := 10, bw := 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(mini(radius, 4))
	s.set_content_margin_all(6)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 3)
	return s


func _pop(b: Control, s: float) -> void:
	if not is_instance_valid(b):
		return
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2(s, s), 0.09)


func _btn(text: String, cb: Callable, min_size := Vector2(92, 66), fs := 18) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", fs)
	b.add_theme_stylebox_override("normal", _style(Color(0.08, 0.12, 0.14, 0.96), STEEL, 3, 1))
	b.add_theme_stylebox_override("hover", _style(Color(0.13, 0.19, 0.21, 0.98), GOLD, 3, 2))
	b.add_theme_stylebox_override("pressed", _style(Color(0.2, 0.26, 0.24, 0.98), Color.WHITE, 3, 2))
	b.add_theme_stylebox_override("disabled", _style(Color(0.08, 0.09, 0.1, 0.9), Color(0.3, 0.3, 0.28), 3, 1))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Color(0.95, 0.91, 0.82))
	b.pressed.connect(cb)
	b.resized.connect(func(): b.pivot_offset = b.size / 2.0)
	b.mouse_entered.connect(func(): _pop(b, 1.05))
	b.mouse_exited.connect(func(): _pop(b, 1.0))
	b.button_down.connect(func(): _pop(b, 0.96))
	b.button_up.connect(func(): _pop(b, 1.04))
	return b


func _lbl(text: String, fs := 20, col := Color(0.95, 0.91, 0.82)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	l.add_theme_constant_override("outline_size", maxi(4, int(fs * 0.2)))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _full(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE


# ---------- العناصر أثناء اللعب ----------
func _build_hud() -> void:
	hud_root = Control.new()
	_full(hud_root)
	add_child(hud_root)

	var logo := IraqBadge.new().setup(60.0, false, true)
	logo.position = Vector2(8, 6)
	hud_root.add_child(logo)
	var ver := _lbl("v" + Data.VERSION, 13, Color(0.8, 0.76, 0.66))
	ver.position = Vector2(14, 54)
	hud_root.add_child(ver)

	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", _style(INK, GOLD, 10, 1))
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.offset_top = 8
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 22)
	lbl_gold = _lbl("الذهب 0")
	lbl_trucks = _lbl("الشاحنات 0")
	lbl_time = _lbl("00:00")
	lbl_mode = _lbl("", 16, Color(0.8, 0.85, 0.95))
	hb.add_child(lbl_gold)
	hb.add_child(lbl_trucks)
	hb.add_child(lbl_time)
	hb.add_child(lbl_mode)
	top.add_child(hb)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(top)

	var sys := HBoxContainer.new()
	sys.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	sys.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	sys.offset_top = 8
	sys.offset_right = -12
	sys.add_theme_constant_override("separation", 6)
	sys.add_child(_btn("إعدادات", func(): open_settings(), Vector2(84, 48), 15))
	sys.add_child(_btn("إيقاف", func(): g.pause_game(), Vector2(64, 48), 15))
	hud_root.add_child(sys)
	ui_nodes.append(sys)

	var tools := VBoxContainer.new()
	tools.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	tools.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tools.grow_vertical = Control.GROW_DIRECTION_BOTH
	tools.offset_right = -12
	tools.add_theme_constant_override("separation", 6)
	tools.add_child(_btn("كل الجيش", func(): g.select_all(), Vector2(84, 52), 15))
	btn_amove = _btn("هجوم", func(): g.toggle_amove(), Vector2(84, 52), 15)
	tools.add_child(btn_amove)
	btn_box = _btn("إطار", func(): g.toggle_box(), Vector2(84, 52), 15)
	tools.add_child(btn_box)
	tools.add_child(_btn("بناء", func(): g.clear_selection(), Vector2(84, 52), 15))
	hud_root.add_child(tools)
	ui_nodes.append(tools)

	minimap = TextureRect.new()
	minimap.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	minimap.offset_left = 12
	minimap.offset_bottom = -12
	minimap.offset_top = -172
	minimap.offset_right = 172
	minimap.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	minimap.stretch_mode = TextureRect.STRETCH_SCALE
	minimap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	minimap.mouse_filter = Control.MOUSE_FILTER_STOP
	minimap.gui_input.connect(_mini_input)
	mm_fog = _mm_layer()
	minimap.add_child(mm_fog)
	mm_dots = _mm_layer()
	minimap.add_child(mm_dots)
	var mm_frame := Panel.new()
	mm_frame.add_theme_stylebox_override("panel", _style(Color(0, 0, 0, 0), GOLD, 4, 3))
	mm_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	mm_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap.add_child(mm_frame)
	hud_root.add_child(minimap)
	ui_nodes.append(minimap)

	panel = HBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 190
	panel.offset_right = -110
	panel.offset_top = -104
	panel.offset_bottom = -12
	panel.alignment = BoxContainer.ALIGNMENT_BEGIN
	panel.add_theme_constant_override("separation", 8)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(panel)
	ui_nodes.append(panel)

	toast_lbl = _lbl("", 22, Color(1, 0.95, 0.75))
	toast_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_lbl.offset_top = 74
	toast_lbl.modulate.a = 0.0
	hud_root.add_child(toast_lbl)

	alert_btn = _btn("", func(): _alert_go(), Vector2(420, 48), 22)
	alert_btn.add_theme_stylebox_override("normal", _style(Color(0.62, 0.08, 0.06, 0.95), Color(1, 0.75, 0.3), 12, 3))
	alert_btn.add_theme_stylebox_override("hover", _style(Color(0.72, 0.1, 0.08, 0.97), Color(1, 0.85, 0.4), 12, 3))
	alert_btn.add_theme_stylebox_override("pressed", _style(Color(0.5, 0.06, 0.05, 0.97), Color.WHITE, 12, 3))
	alert_btn.set_anchors_preset(Control.PRESET_CENTER_TOP)
	alert_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	alert_btn.offset_top = 116
	alert_btn.visible = false
	hud_root.add_child(alert_btn)
	ui_nodes.append(alert_btn)

	box_panel = Panel.new()
	box_panel.add_theme_stylebox_override("panel", _style(Color(0.4, 1, 0.55, 0.15), Color(0.4, 1, 0.55), 2, 2))
	box_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box_panel.visible = false
	hud_root.add_child(box_panel)
	hud_root.visible = false


func show_alert(msg: String, pos: Vector3) -> void:
	alert_pos = pos
	alert_btn.text = msg
	alert_btn.visible = true
	alert_btn.modulate = Color.WHITE
	if alert_tw != null:
		alert_tw.kill()
	alert_tw = create_tween()
	for i in range(8):
		alert_tw.tween_property(alert_btn, "modulate", Color(1.0, 0.6, 0.6), 0.28)
		alert_tw.tween_property(alert_btn, "modulate", Color.WHITE, 0.28)
	alert_tw.tween_callback(func(): alert_btn.visible = false)


func _alert_go() -> void:
	g.goto_pos(alert_pos)
	alert_btn.visible = false
	Sfx.play("click")


func _mini_input(ev: InputEvent) -> void:
	var pressed := false
	var pos := Vector2.ZERO
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
		pos = ev.position
	elif ev is InputEventMouseMotion and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		pressed = true
		pos = ev.position
	if pressed:
		g.minimap_goto(pos / minimap.size)


func is_over_ui(p: Vector2) -> bool:
	if menu.visible or pause_box.visible or end_box.visible or loading.visible or settings_box.visible or saves_box.visible:
		return true
	for n in ui_nodes:
		if n is Control and n.visible and n.get_global_rect().has_point(p):
			return true
	return false


func set_box(r: Rect2, show_it: bool) -> void:
	box_panel.visible = show_it
	if show_it:
		box_panel.position = r.position
		box_panel.size = r.size


func _mm_layer() -> TextureRect:
	var t := TextureRect.new()
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _set_tex(rect: TextureRect, img: Image) -> void:
	if rect.texture == null or (rect.texture as ImageTexture).get_width() != img.get_width():
		rect.texture = ImageTexture.create_from_image(img)
	else:
		(rect.texture as ImageTexture).update(img)


func set_mini_base(img: Image) -> void:
	minimap.texture = ImageTexture.create_from_image(img)
	mm_fog.texture = null
	mm_dots.texture = null


func update_mini_fog(img: Image) -> void:
	_set_tex(mm_fog, img)


func update_mini_dots(img: Image) -> void:
	_set_tex(mm_dots, img)


func set_toggles(amove: bool, box_on: bool) -> void:
	btn_amove.modulate = Color(0.6, 1.0, 0.7) if amove else Color.WHITE
	btn_box.modulate = Color(0.6, 1.0, 0.7) if box_on else Color.WHITE


func toast(msg: String) -> void:
	toast_lbl.text = msg
	toast_lbl.modulate.a = 1.0
	if toast_tween != null:
		toast_tween.kill()
	toast_tween = create_tween()
	toast_tween.tween_interval(1.8)
	toast_tween.tween_property(toast_lbl, "modulate:a", 0.0, 0.4)


# ---------- اللوحة السفلية ----------
func refresh(force := false) -> void:
	if g.gold.size() < 4:
		return
	lbl_gold.text = "الذهب %d  (+%d/ث)" % [int(g.gold[0]), int(g.income[0])]
	lbl_trucks.text = "الشاحنات %d" % g.truck_count(0)
	lbl_mode.text = str(Data.MODES[g.mode_key]["name"])
	var s: int = int(g.time)
	lbl_time.text = "%02d:%02d" % [s / 60, s % 60]
	var sg: String = g.selection_sig()
	if force or sg != sig:
		sig = sg
		_rebuild_panel()
	for e in cost_btns:
		if is_instance_valid(e[0]):
			e[0].disabled = g.gold[0] < float(e[1])
	if queue_lbl != null and is_instance_valid(queue_lbl) and g.sel.size() == 1 and g.sel[0].kind == "b":
		var sbd = g.sel[0]
		var qn: int = sbd.q.size()
		var pct: int = int(sbd.hp / sbd.max_hp * 100.0)
		if sbd.con < 1.0:
			queue_lbl.text = "قيد البناء %d٪" % int(sbd.con * 100.0)
		elif (sbd.def["train"] as Array).is_empty():
			queue_lbl.text = "الصحة %d٪" % pct
		elif qn > 0:
			queue_lbl.text = "الصحة %d٪ · الطابور %d" % [pct, qn]
		else:
			queue_lbl.text = "الصحة %d٪ · اضغط الأرض للتجمع" % pct
		if hp_bar != null and is_instance_valid(hp_bar):
			var fr: float = clampf(sbd.hp / sbd.max_hp, 0.0, 1.0)
			hp_bar.value = fr * 100.0
			hp_fill.bg_color = Color(0.37, 0.83, 0.42) if fr > 0.5 else (Color(0.95, 0.75, 0.25) if fr > 0.25 else Color(0.9, 0.3, 0.24))
			if sbd.repairing:
				hp_fill.bg_color = Color(0.3, 0.8, 1.0)
	_update_repair_btn()


func make_preview(key: String, col: Color, sz: Vector2, building := false) -> Control:
	# تُرسم المعاينة مرة واحدة فقط وتُخزَّن كصورة، فلا تعمل عوالم 3D إضافية أثناء اللعب
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
		sv.render_target_update_mode = SubViewport.UPDATE_ONCE
		prev_root.add_child(sv)
		var root := Node3D.new()
		sv.add_child(root)
		var model: Node3D = Models.building_model(key, col) if building else Models.unit_model(key, col)
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
		var k: float = float(PREVIEW_K.get(key, 1.0))
		var cam := Camera3D.new()
		cam.fov = 40.0
		root.add_child(cam)
		cam.position = Vector3(0, 2.4 * k, 6.2 * k)
		cam.look_at(Vector3(0, 0.9 * k, 0), Vector3.UP)
		prev_cache[ck] = sv
	tr.texture = (prev_cache[ck] as SubViewport).get_texture()
	return tr


func _card(key: String, col: Color, title: String, cost: int, cb: Callable, building := false) -> Button:
	var b := _btn("", cb, Vector2(108, 92))
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 0)
	v.add_child(make_preview(key, col, Vector2(100, 54), building))
	var l1 := _lbl(title, 14)
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var l2 := _lbl(str(cost), 14, GOLD)
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l1)
	v.add_child(l2)
	b.add_child(v)
	return b


func _rebuild_panel() -> void:
	for c in panel.get_children():
		c.queue_free()
	cost_btns.clear()
	queue_lbl = null
	repair_btn = null
	repair_b = null
	hp_bar = null
	var col: Color = Data.ARMIES[g.army_of[0]]["color"]
	var su: Array = g.sel.filter(func(e): return e.kind == "u")
	var sb: Array = g.sel.filter(func(e): return e.kind == "b")
	if g.mode == "place":
		panel.add_child(_info("ضع " + str(Data.BUILDINGS[g.place_type]["name"]), "اضغط أرضاً فارغة (لا شجر ولا حجر ولا منحدر)"))
		panel.add_child(_btn("إلغاء", func(): g.cancel_place()))
	elif not su.is_empty():
		if su.size() == 1 and su[0].is_truck:
			panel.add_child(_info("شاحنة ذهب", "الحمولة %d" % int(su[0].load_gold)))
		elif su.size() == 1:
			panel.add_child(_info(str(su[0].def["name"]), "الصحة %d٪" % int(su[0].hp / su[0].max_hp * 100.0)))
			panel.add_child(_btn("إيقاف", func(): g.stop_selected()))
		else:
			var f := 0.0
			for u in su:
				f += u.hp / u.max_hp
			f = f / su.size() * 100.0
			panel.add_child(_info("%d وحدة" % su.size(), "الصحة %d٪" % int(f)))
			panel.add_child(_btn("إيقاف", func(): g.stop_selected()))
	elif not sb.is_empty():
		var b = sb[0]
		var d: Dictionary = b.def
		var info := _info(str(d["name"]), "قيد البناء" if b.con < 1.0 else "", true)
		panel.add_child(info)
		queue_lbl = info.get_child(0).get_child(1)
		repair_btn = null
		repair_b = null
		if b.con >= 1.0 and b.team == 0:
			repair_b = b
			repair_btn = _btn("", func(): g.repair_building(b), Vector2(108, 92), 16)
			panel.add_child(repair_btn)
			_update_repair_btn()
		if b.con >= 1.0 and b.team == 0:
			for t in d["train"]:
				var ud: Dictionary = Data.UNITS[t]
				var bt := _card(t, col, str(ud["name"]), int(ud["cost"]), func(): g.train(b, t))
				panel.add_child(bt)
				cost_btns.append([bt, ud["cost"]])
		if b.type == "hq":
			_add_build_buttons()
	else:
		_add_build_buttons()


func _add_build_buttons() -> void:
	if g.find_hq(0) == null:
		return
	var col: Color = Data.ARMIES[g.army_of[0]]["color"]
	for t in ["dep", "bar", "fac", "air", "twr"]:
		var d: Dictionary = Data.BUILDINGS[t]
		var bt := _card(t, col, str(d["name"]), int(d["cost"]), func(): g.begin_place(t), true)
		panel.add_child(bt)
		cost_btns.append([bt, d["cost"]])


func _update_repair_btn() -> void:
	if repair_btn == null or not is_instance_valid(repair_btn):
		return
	var b = repair_b
	if b == null or not is_instance_valid(b) or b.dead:
		return
	var c: int = b.repair_cost()
	if b.repairing:
		repair_btn.text = "جارٍ التصليح..."
		repair_btn.disabled = true
	elif c <= 0:
		repair_btn.text = "سليم"
		repair_btn.disabled = true
	else:
		repair_btn.text = "تصليح\n%d ذهب" % c
		repair_btn.disabled = g.gold[0] < float(c)


func _info(title: String, sub: String, with_bar := false) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _style(INK, GOLD, 10, 1))
	pc.custom_minimum_size = Vector2(170, 66)
	var v := VBoxContainer.new()
	v.add_child(_lbl(title, 20))
	v.add_child(_lbl(sub, 14, Color(0.78, 0.74, 0.65)))
	hp_bar = null
	if with_bar:
		hp_bar = ProgressBar.new()
		hp_bar.show_percentage = false
		hp_bar.min_value = 0.0
		hp_bar.max_value = 100.0
		hp_bar.value = 100.0
		hp_bar.custom_minimum_size = Vector2(150, 14)
		hp_bar.add_theme_stylebox_override("background", _style(Color(0.08, 0.05, 0.05, 0.95), Color(0.6, 0.5, 0.3), 5, 1))
		hp_fill = _style(Color(0.37, 0.83, 0.42), Color(0, 0, 0, 0), 5, 0)
		hp_fill.shadow_size = 0
		hp_bar.add_theme_stylebox_override("fill", hp_fill)
		v.add_child(hp_bar)
	pc.add_child(v)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pc


# ---------- القائمة الرئيسية (بدون نماذج، فقط لون الجيش واسمه ومميزاته) ----------
func _section(num: String, text: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar := ColorRect.new()
	bar.color = GOLD
	bar.custom_minimum_size = Vector2(5, 24)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(bar)
	h.add_child(_lbl(num, 18, GOLD))
	h.add_child(_lbl(text, 22))
	var line := ColorRect.new()
	line.color = Color(0.45, 0.58, 0.56, 0.4)
	line.custom_minimum_size = Vector2(0, 2)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(line)
	return h


func _chip(text: String, col: Color, dot := false) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _style(Color(0.05, 0.08, 0.09, 0.9), col.darkened(0.2), 2, 1))
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	pc.add_child(hb)
	if dot:
		var d := ColorRect.new()
		d.color = col
		d.custom_minimum_size = Vector2(10, 10)
		d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(d)
		var tw := d.create_tween().set_loops()
		tw.tween_property(d, "modulate:a", 0.15, 0.7)
		tw.tween_property(d, "modulate:a", 1.0, 0.7)
	hb.add_child(_lbl(text, 16, col))
	return pc


func _seg_style(b: Button, sel: bool) -> void:
	if sel:
		b.add_theme_stylebox_override("normal", _style(GOLD, GOLD.lightened(0.3), 2, 2))
		b.add_theme_stylebox_override("hover", _style(GOLD.lightened(0.12), Color.WHITE, 2, 2))
		b.add_theme_stylebox_override("pressed", _style(GOLD.darkened(0.15), Color.WHITE, 2, 2))
		for k in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(k, Color(0.08, 0.05, 0.01))
	else:
		b.add_theme_stylebox_override("normal", _style(Color(0.07, 0.1, 0.12, 0.96), STEEL, 2, 1))
		b.add_theme_stylebox_override("hover", _style(Color(0.12, 0.17, 0.19, 0.98), GOLD, 2, 2))
		b.add_theme_stylebox_override("pressed", _style(Color(0.2, 0.26, 0.24, 0.98), Color.WHITE, 2, 2))
		for k in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(k, Color(0.88, 0.93, 0.9))


func _build_menu() -> void:
	menu = Control.new()
	_full(menu)
	menu.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(menu)
	menu.add_child(MenuBg.new())
	var margin := MarginContainer.new()
	_full(margin)
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 18)
	menu.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 9)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(v)

	# ---- الرأس
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 20)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	head.add_child(IraqBadge.new().setup(84.0, true, true))
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(tv)
	var title := _lbl("صقور الرافدين", 62, GOLD)
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color(0.25, 0.16, 0.02, 0.95))
	title.resized.connect(func(): title.pivot_offset = title.size / 2.0)
	title_lbl = title
	title.set_meta("noscale", true)
	tv.add_child(title)
	sub_lbl = _lbl("نظام القيادة والسيطرة  ·  استراتيجية حربية ثلاثية الأبعاد", 20, Color(0.74, 0.86, 0.82))
	tv.add_child(sub_lbl)
	var rv := VBoxContainer.new()
	rv.alignment = BoxContainer.ALIGNMENT_CENTER
	rv.add_theme_constant_override("separation", 8)
	rv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(rv)
	rv.add_child(_chip("جاهز للمعركة", Color(0.36, 0.9, 0.52), true))
	rv.add_child(_chip("الإصدار " + Data.VERSION, Color(0.7, 0.8, 0.8)))
	var sb := _btn("الإعدادات", func(): open_settings(), Vector2(170, 44), 18)
	_seg_style(sb, false)
	rv.add_child(sb)
	var rule := ColorRect.new()
	rule.color = Color(GOLD.r, GOLD.g, GOLD.b, 0.85)
	rule.custom_minimum_size = Vector2(0, 3)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(rule)

	# ---- اختيار الجيش
	var sec1 := _section("01", "اختيار الجيش")
	v.add_child(sec1)
	var arow := HBoxContainer.new()
	arow.add_theme_constant_override("separation", 12)
	arow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(arow)
	for k in Data.ARMIES.keys():
		var card := _army_card(k)
		arow.add_child(card)
		army_btns[k] = card
	lbl_army_info = _lbl("", 16, Color(0.85, 0.92, 0.8))
	v.add_child(lbl_army_info)

	# ---- النمط والصعوبة
	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 30)
	mrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(mrow)
	var mcol := VBoxContainer.new()
	mcol.add_theme_constant_override("separation", 6)
	mcol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mrow.add_child(mcol)
	mcol.add_child(_section("02", "نمط اللعب"))
	var mgrid := GridContainer.new()
	mgrid.columns = 4
	mgrid.add_theme_constant_override("h_separation", 8)
	mcol.add_child(mgrid)
	for k in Data.MODES.keys():
		var mb := _btn(str(Data.MODES[k]["name"]), func(): _pick_mode(k), Vector2(132, 48), 18)
		mgrid.add_child(mb)
		mode_btns[k] = mb
	lbl_mode_info = _lbl("", 14, Color(0.75, 0.84, 0.9))
	mcol.add_child(lbl_mode_info)
	var dcol := VBoxContainer.new()
	dcol.add_theme_constant_override("separation", 6)
	dcol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mrow.add_child(dcol)
	dcol.add_child(_section("03", "مستوى الصعوبة"))
	var drow := HBoxContainer.new()
	drow.add_theme_constant_override("separation", 8)
	dcol.add_child(drow)
	for k in Data.DIFF.keys():
		var db := _btn(str(Data.DIFF[k]["name"]), func(): _pick_diff(k), Vector2(124, 48), 18)
		drow.add_child(db)
		diff_btns[k] = db
	lbl_diff_info = _lbl("", 14, Color(0.95, 0.82, 0.68))
	dcol.add_child(lbl_diff_info)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(spacer)

	# ---- الأزرار السفلية
	var brow := HBoxContainer.new()
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	brow.add_theme_constant_override("separation", 18)
	brow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(brow)
	btn_continue = _btn("المحفوظات", func(): open_saves(), Vector2(300, 70), 22)
	_seg_style(btn_continue, false)
	brow.add_child(btn_continue)
	var chl: Label = _lbl("<<<", 30, GOLD)
	brow.add_child(chl)
	var start := _btn("ابدأ المعركة", func(): _start(), Vector2(400, 74), 30)
	_seg_style(start, true)
	brow.add_child(start)
	var chr: Label = _lbl(">>>", 30, GOLD)
	brow.add_child(chr)
	for ch: Label in [chl, chr]:
		var ct: Tween = ch.create_tween().set_loops()
		ct.tween_property(ch, "modulate:a", 0.15, 0.6)
		ct.tween_property(ch, "modulate:a", 1.0, 0.6)
	start.resized.connect(func(): start.pivot_offset = start.size / 2.0)
	var sbreath := start.create_tween().set_loops()
	sbreath.tween_property(start, "scale", Vector2(1.035, 1.035), 0.8).set_trans(Tween.TRANS_SINE)
	sbreath.tween_property(start, "scale", Vector2(1.0, 1.0), 0.8).set_trans(Tween.TRANS_SINE)
	start.set_meta("noscale", true)
	menu_items = [title, sub_lbl, sec1]
	for k in army_btns.keys():
		menu_items.append(army_btns[k])
	menu_items.append(lbl_army_info)
	menu_items.append(mcol)
	menu_items.append(dcol)
	menu_items.append(btn_continue)
	menu_items.append(start)
	_refresh_menu()


func _army_card(k: String) -> Button:
	var a: Dictionary = Data.ARMIES[k]
	var b := _btn("", func(): _pick_army(k), Vector2(290, 150), 16)
	var cv := VBoxContainer.new()
	cv.set_anchors_preset(Control.PRESET_FULL_RECT)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.offset_left = 14
	cv.offset_right = -8
	cv.offset_top = 10
	cv.offset_bottom = -8
	cv.add_theme_constant_override("separation", 5)
	var ins := Insignia.new()
	ins.col = a["color"]
	ins.custom_minimum_size = Vector2(0, 52)
	ins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(ins)
	var n1 := _lbl(str(a["name"]), 20)
	n1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(n1)
	var n2 := _lbl(str(a["desc"]), 14, Color(0.96, 0.82, 0.45))
	n2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(n2)
	b.add_child(cv)
	var br := Brackets.new()
	br.set_anchors_preset(Control.PRESET_FULL_RECT)
	br.mouse_filter = Control.MOUSE_FILTER_IGNORE
	br.visible = false
	b.add_child(br)
	b.set_meta("br", br)
	return b


func _start() -> void:
	if loading.visible:
		return
	Sfx.play("start")
	g.start_game(picked_army, picked_diff, picked_mode)


func _pick_army(k: String) -> void:
	picked_army = k
	Sfx.play("pick_" + k)
	var cb: Control = army_btns[k]
	cb.scale = Vector2(0.92, 0.92)
	cb.create_tween().tween_property(cb, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_refresh_menu()


func _pick_mode(k: String) -> void:
	picked_mode = k
	_refresh_menu()
	Sfx.play("pick_mode")


func _pick_diff(k: String) -> void:
	picked_diff = k
	_refresh_menu()
	Sfx.play("diff_" + k)


func _card_style(col: Color, sel: bool) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.12, 0.17, 0.19, 0.98) if sel else Color(0.07, 0.1, 0.12, 0.95)
	st.border_color = GOLD if sel else STEEL
	st.border_width_left = 9 if sel else 6
	st.border_width_right = 2 if sel else 1
	st.border_width_top = 2 if sel else 1
	st.border_width_bottom = 2 if sel else 1
	st.set_corner_radius_all(2)
	st.set_content_margin_all(6)
	st.shadow_color = Color(0, 0, 0, 0.5)
	st.shadow_size = 8 if sel else 4
	st.shadow_offset = Vector2(0, 3)
	return st


func _refresh_menu() -> void:
	for k in army_btns.keys():
		var sel: bool = k == picked_army
		var col: Color = Data.ARMIES[k]["color"]
		var ab: Button = army_btns[k]
		var stl := _card_style(col, sel)
		stl.border_color = GOLD if sel else col.darkened(0.2)
		ab.add_theme_stylebox_override("normal", stl)
		ab.add_theme_stylebox_override("hover", _card_style(col, true))
		ab.add_theme_stylebox_override("pressed", _card_style(col, true))
		ab.modulate.r = 1.0 if sel else 0.78
		ab.modulate.g = 1.0 if sel else 0.78
		ab.modulate.b = 1.0 if sel else 0.82
		(ab.get_meta("br") as Control).visible = sel
	for k in mode_btns.keys():
		_seg_style(mode_btns[k], k == picked_mode)
	for k in diff_btns.keys():
		_seg_style(diff_btns[k], k == picked_diff)
	var a: Dictionary = Data.ARMIES[picked_army]
	lbl_army_info.text = "الجيش المختار: %s  ·  الميزة: %s" % [a["name"], a["desc"]]
	lbl_mode_info.text = str(Data.MODES[picked_mode]["desc"])
	lbl_diff_info.text = str(Data.DIFF[picked_diff]["desc"])


func refresh_continue() -> void:
	var n: int = g.list_saves().size()
	btn_continue.visible = true
	btn_continue.text = "المحفوظات (%d)" % n if n > 0 else "المحفوظات"


# ---------- النوافذ وشاشة الانتظار ----------
func _build_overlays() -> void:
	pause_update_btn = _btn("تحديث الحفظ الحالي", func(): g.save_game(true, g.cur_slot), Vector2(300, 50), 18)
	pause_box = _make_box("إيقاف مؤقت", [
		["متابعة", func(): g.resume_game(), Vector2(300, 58), 22],
		["حفظ في خانة جديدة", func(): g.save_game(true), Vector2(300, 50), 18],
		[pause_update_btn],
		["الإعدادات", func(): open_settings(), Vector2(300, 50), 18],
		["حفظ والخروج للقائمة", func(): g.save_and_menu(), Vector2(300, 50), 18],
		[_confirm_btn("خروج بدون حفظ", "اضغط للتأكيد: سيضيع التقدم", func(): g.to_menu(), Vector2(300, 50), 18)],
	])
	end_box = _make_box("", [
		["لعب مرة أخرى", func(): g.restart(), Vector2(300, 58), 22],
		["القائمة الرئيسية", func(): g.to_menu(), Vector2(300, 50), 18],
	])
	end_title = end_box.get_meta("title")
	end_sub = end_box.get_meta("sub")
	pause_box.visible = false
	end_box.visible = false
	_build_loading()
	_build_settings()
	_build_saves()


func _confirm_press(st: Dictionary, text: String, ctext: String, action: Callable) -> void:
	var b: Button = st["btn"]
	if st["armed"]:
		st["armed"] = false
		b.text = text
		b.modulate = Color.WHITE
		action.call()
		return
	st["armed"] = true
	b.text = ctext
	b.modulate = Color(1.0, 0.6, 0.55)
	Sfx.play("bad")
	get_tree().create_timer(3.0).timeout.connect(func():
		if is_instance_valid(b) and st["armed"]:
			st["armed"] = false
			b.text = text
			b.modulate = Color.WHITE)


# زر يحتاج ضغطتين (لمنع الخسارة بالخطأ)
func _confirm_btn(text: String, ctext: String, action: Callable, sz: Vector2, fs: int) -> Button:
	var st := {"armed": false, "btn": null}
	var b := _btn(text, func(): _confirm_press(st, text, ctext, action), sz, fs)
	st["btn"] = b
	return b


func _grabber() -> ImageTexture:
	if grab_tex == null:
		var n := 44
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		var c := Vector2(n * 0.5, n * 0.5)
		for y in n:
			for x in n:
				var d: float = Vector2(x + 0.5, y + 0.5).distance_to(c)
				if d < 20.0:
					img.set_pixel(x, y, Color(0.95, 0.76, 0.28) if d < 15.0 else Color(0.35, 0.22, 0.05))
		grab_tex = ImageTexture.create_from_image(img)
	return grab_tex


func _slider(init: float, cb: Callable) -> HSlider:
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 100.0
	sl.step = 5.0
	sl.value = init
	sl.custom_minimum_size = Vector2(420, 44)
	sl.add_theme_stylebox_override("slider", _style(Color(0.08, 0.12, 0.2), Color(0.5, 0.4, 0.2), 6, 1))
	sl.add_theme_stylebox_override("grabber_area", _style(Color(0.88, 0.69, 0.31), Color(0.88, 0.69, 0.31), 6, 0))
	sl.add_theme_stylebox_override("grabber_area_highlight", _style(Color(0.95, 0.8, 0.4), Color(0.95, 0.8, 0.4), 6, 0))
	sl.add_theme_icon_override("grabber", _grabber())
	sl.add_theme_icon_override("grabber_highlight", _grabber())
	sl.value_changed.connect(cb)
	sl.drag_ended.connect(func(_c): Sfx.play("tick"))
	return sl


func _overlay(title: String, width: float) -> Array:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.04, 0.08, 0.86)
	_full(bg)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	var cc := CenterContainer.new()
	_full(cc)
	bg.add_child(cc)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _style(Color(0.06, 0.09, 0.11, 0.98), GOLD, 4, 2))
	pc.custom_minimum_size = Vector2(width, 0)
	cc.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	pc.add_child(v)
	var t := _lbl(title, 36, GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	bg.visible = false
	return [bg, v]


func _build_settings() -> void:
	var o := _overlay("الإعدادات", 540.0)
	settings_box = o[0]
	var v: VBoxContainer = o[1]
	lbl_music = _lbl("", 22)
	v.add_child(lbl_music)
	v.add_child(_slider(Sfx.music_vol * 100.0, func(x: float): _set_music(x)))
	lbl_sfx = _lbl("", 22)
	v.add_child(lbl_sfx)
	v.add_child(_slider(Sfx.sfx_vol * 100.0, func(x: float): _set_sfx(x)))
	_update_vol_labels()
	var back := _btn("رجوع", func(): close_settings(), Vector2(300, 54), 22)
	var br := HBoxContainer.new()
	br.alignment = BoxContainer.ALIGNMENT_CENTER
	br.add_child(back)
	v.add_child(br)


func _set_music(x: float) -> void:
	Sfx.set_music_volume(x / 100.0)
	_update_vol_labels()


func _set_sfx(x: float) -> void:
	Sfx.set_sfx_volume(x / 100.0)
	_update_vol_labels()


func _update_vol_labels() -> void:
	lbl_music.text = "الموسيقى: %d٪" % int(Sfx.music_vol * 100.0 + 0.5)
	lbl_sfx.text = "المؤثرات الصوتية: %d٪" % int(Sfx.sfx_vol * 100.0 + 0.5)


func open_settings() -> void:
	Sfx.play("click")
	settings_box.visible = true


func close_settings() -> void:
	Sfx.play("click")
	settings_box.visible = false


func _build_saves() -> void:
	var o := _overlay("المحفوظات", 760.0)
	saves_box = o[0]
	var v: VBoxContainer = o[1]
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(700, 320)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	saves_list = VBoxContainer.new()
	saves_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	saves_list.add_theme_constant_override("separation", 8)
	sc.add_child(saves_list)
	var br := HBoxContainer.new()
	br.alignment = BoxContainer.ALIGNMENT_CENTER
	br.add_child(_btn("رجوع", func(): close_saves(), Vector2(300, 54), 22))
	v.add_child(br)


func open_saves() -> void:
	Sfx.play("click")
	_fill_saves()
	saves_box.visible = true


func close_saves() -> void:
	Sfx.play("click")
	saves_box.visible = false
	refresh_continue()


func _fill_saves() -> void:
	for c in saves_list.get_children():
		c.queue_free()
	var arr: Array = g.list_saves()
	if arr.is_empty():
		var e := _lbl("لا توجد مباريات محفوظة بعد.\nاحفظ من قائمة الإيقاف أثناء اللعب.", 20, Color(0.8, 0.8, 0.75))
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		saves_list.add_child(e)
		return
	for e in arr:
		saves_list.add_child(_save_row(e))


func _save_row(e: Dictionary) -> Control:
	var id: String = str(e["id"])
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _style(INK, GOLD.darkened(0.3), 10, 1))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	pc.add_child(hb)
	var m: int = int(float(e["time"]))
	var mn: String = str(Data.MODES.get(str(e["mode"]), {}).get("name", ""))
	var df: String = str(Data.DIFF.get(str(e["diff"]), {}).get("name", ""))
	var an: String = str(Data.ARMIES.get(str(e["army"]), {}).get("name", ""))
	var head: String = "حفظ تلقائي (عند مغادرة اللعبة)" if id == "auto" else "%s · %s" % [mn, df]
	var info := _lbl("%s\n%s · %s · المدة %02d:%02d" % [head, an, str(e["date"]), m / 60, m % 60], 17)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(info)
	hb.add_child(_btn("تحميل", func(): _load_slot(id), Vector2(110, 54), 18))
	hb.add_child(_confirm_btn("حذف", "تأكيد؟", func(): _delete_slot(id), Vector2(110, 54), 18))
	return pc


func _load_slot(id: String) -> void:
	if loading.visible:
		return
	Sfx.play("start")
	saves_box.visible = false
	g.continue_game(id)


func _delete_slot(id: String) -> void:
	g.delete_slot(id)
	_fill_saves()


# يغلق نافذة الإعدادات أو المحفوظات إن كانت مفتوحة (لزر الرجوع)
func close_overlays() -> bool:
	if settings_box.visible:
		settings_box.visible = false
		return true
	if saves_box.visible:
		close_saves()
		return true
	return false


func _build_loading() -> void:
	loading = Control.new()
	_full(loading)
	loading.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(loading)
	loading.add_child(MenuBg.new())
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.05, 0.1, 0.55)
	_full(dim)
	loading.add_child(dim)
	var cc := CenterContainer.new()
	_full(cc)
	loading.add_child(cc)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(720, 0)
	v.add_theme_constant_override("separation", 14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	cc.add_child(v)
	var t := _lbl("صقور الرافدين", 52, GOLD)
	t.add_theme_constant_override("outline_size", 9)
	t.add_theme_color_override("font_outline_color", Color(0.35, 0.2, 0.03, 0.95))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	v.add_child(gap)
	var bar_row := HBoxContainer.new()
	bar_row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(bar_row)
	load_bar = ProgressBar.new()
	load_bar.custom_minimum_size = Vector2(620, 30)
	load_bar.show_percentage = false
	load_bar.min_value = 0.0
	load_bar.max_value = 100.0
	load_bar.add_theme_stylebox_override("background", _style(Color(0.06, 0.1, 0.18, 0.95), GOLD.darkened(0.3), 12, 2))
	load_bar.add_theme_stylebox_override("fill", _style(GOLD, GOLD.lightened(0.35), 12, 0))
	bar_row.add_child(load_bar)
	load_pct = _lbl("0٪", 26, GOLD)
	load_pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(load_pct)
	load_stage = _lbl("", 22)
	load_stage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	load_stage.custom_minimum_size = Vector2(0, 34)
	v.add_child(load_stage)
	load_tip = _lbl("نصيحة: " + str(TIPS[0]), 18, Color(0.82, 0.9, 1.0))
	load_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	load_tip.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	load_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	load_tip.custom_minimum_size = Vector2(680, 56)
	v.add_child(load_tip)
	var ver := _lbl("الإصدار " + Data.VERSION, 15, Color(0.75, 0.72, 0.64))
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ver)
	loading.visible = false


func set_progress(p: float, text: String) -> void:
	load_bar.value = clampf(p, 0.0, 1.0) * 100.0
	load_pct.text = "%d٪" % int(clampf(p, 0.0, 1.0) * 100.0)
	load_stage.text = text


func show_loading(on: bool, _text := "") -> void:
	loading.visible = on
	if on:
		menu.visible = false
		hud_root.visible = false
		pause_box.visible = false
		end_box.visible = false
		tip_t = 0.0
		tip_i = randi() % TIPS.size()
		load_tip.text = "نصيحة: " + str(TIPS[tip_i])
		load_tip.modulate.a = 1.0


func _make_box(title: String, buttons: Array) -> Control:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.04, 0.08, 0.78)
	_full(bg)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	var cc := CenterContainer.new()
	_full(cc)
	bg.add_child(cc)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _style(Color(0.06, 0.09, 0.11, 0.98), GOLD, 4, 2))
	cc.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	pc.add_child(v)
	var t := _lbl(title, 36, GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := _lbl("", 18)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	for bt in buttons:
		if bt[0] is Button:
			v.add_child(bt[0])
		else:
			v.add_child(_btn(str(bt[0]), bt[1], bt[2], int(bt[3])))
	bg.set_meta("title", t)
	bg.set_meta("sub", s)
	return bg


func _menu_intro() -> void:
	var i := 0
	for n in menu_items:
		var c: Control = n
		if not is_instance_valid(c):
			continue
		c.modulate.a = 0.0
		var tw := c.create_tween()
		tw.tween_interval(0.08 + 0.09 * float(i))
		tw.tween_property(c, "modulate:a", 1.0, 0.45)
		if not c.has_meta("noscale"):
			c.scale = Vector2(0.82, 0.82)
			var tw2 := c.create_tween()
			tw2.tween_interval(0.08 + 0.09 * float(i))
			tw2.tween_property(c, "scale", Vector2(1.0, 1.0), 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		i += 1
	if sub_lbl != null:
		sub_lbl.visible_ratio = 0.0
		var tt := sub_lbl.create_tween()
		tt.tween_interval(0.5)
		tt.tween_property(sub_lbl, "visible_ratio", 1.0, 1.4)
	if title_lbl != null:
		var br := title_lbl.create_tween().set_loops()
		br.tween_property(title_lbl, "scale", Vector2(1.035, 1.035), 1.5).set_trans(Tween.TRANS_SINE)
		br.tween_property(title_lbl, "scale", Vector2(1.0, 1.0), 1.5).set_trans(Tween.TRANS_SINE)
		title_lbl.set_meta("breath", br)


func show_menu() -> void:
	if title_lbl != null and title_lbl.has_meta("breath"):
		var old: Tween = title_lbl.get_meta("breath")
		if old != null:
			old.kill()
		title_lbl.remove_meta("breath")
	menu.visible = true
	_menu_intro()
	hud_root.visible = false
	pause_box.visible = false
	end_box.visible = false
	refresh_continue()


func show_hud() -> void:
	menu.visible = false
	hud_root.visible = true
	pause_box.visible = false
	end_box.visible = false
	sig = ""


func show_pause(v: bool) -> void:
	pause_box.visible = v
	if v:
		pause_update_btn.visible = g.cur_slot != ""


func show_end(win: bool, text: String) -> void:
	end_title.text = "النصر!" if win else "هُزمت"
	end_sub.text = text
	end_box.visible = true
