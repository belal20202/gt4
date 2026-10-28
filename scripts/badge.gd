class_name IraqBadge
extends Control
## عبارة «صنع في العراق» فقط: نص ذهبي واضح وأنيق بزخرفة خطية، بلا شعار ولا علم.
## تُستخدم في القائمة الرئيسية فقط، ولا تظهر أثناء اللعب.

const GOLD := Color(0.96, 0.7, 0.18)
const GOLD_LIGHT := Color(1.0, 0.9, 0.56)

var text_h := 0.0


# المعاملات القديمة (s, with_emblem, with_label) محفوظة للتوافق، ولا تُستخدم الأيقونة ولا اللوحة بعد الآن.
func setup(s: float, _with_emblem := false, _with_label := true) -> IraqBadge:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fs: int = clampi(int(s * 0.36), 22, 36)
	var w: float = float(fs) * 7.4 + 30.0
	var h: float = float(fs) * 1.5 + 22.0
	custom_minimum_size = Vector2(w, h)
	size = custom_minimum_size
	var lbl := Label.new()
	lbl.text = "صنع في العراق"
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.position = Vector2(0.0, 3.0)
	lbl.size = Vector2(w, float(fs) * 1.5 + 4.0)
	lbl.add_theme_font_size_override("font_size", fs)
	lbl.add_theme_color_override("font_color", GOLD_LIGHT)
	lbl.add_theme_color_override("font_outline_color", Color(0.22, 0.13, 0.02, 0.98))
	lbl.add_theme_constant_override("outline_size", maxi(5, int(float(fs) * 0.26)))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	add_child(lbl)
	text_h = float(fs) * 1.5 + 4.0
	queue_redraw()
	return self


func _draw() -> void:
	if text_h <= 0.0:
		return
	var w: float = size.x
	var y: float = text_h + 11.0
	var cx: float = w * 0.5
	# خط ذهبي متدرج الشفافية نحو الأطراف مع معين صغير في الوسط
	var segs := 24
	for i in range(segs):
		var t0: float = float(i) / float(segs)
		var t1: float = float(i + 1) / float(segs)
		var a: float = 1.0 - absf(t0 + 0.5 / float(segs) - 0.5) * 2.0
		var col := Color(GOLD.r, GOLD.g, GOLD.b, clampf(a * 1.1, 0.0, 1.0))
		draw_line(Vector2(w * 0.06 + (w * 0.88) * t0, y), Vector2(w * 0.06 + (w * 0.88) * t1, y), col, 2.0)
	var d := 5.0
	draw_colored_polygon(PackedVector2Array([Vector2(cx, y - d), Vector2(cx + d, y), Vector2(cx, y + d), Vector2(cx - d, y)]), GOLD)
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 18.0, y), Vector2(cx - 12.0, y - 3.0), Vector2(cx - 12.0, y + 3.0)]), GOLD)
	draw_colored_polygon(PackedVector2Array([Vector2(cx + 18.0, y), Vector2(cx + 12.0, y - 3.0), Vector2(cx + 12.0, y + 3.0)]), GOLD)
