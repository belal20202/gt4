class_name IraqBadge
extends Control
## شارة «صنع في العراق»: لوحة داكنة بإطار ذهبي وشريط بألوان العلم العراقي، ومعها أيقونة اللعبة اختيارياً.

const EMBLEM_PATH := "res://assets/emblem.png"
const GOLD := Color(0.96, 0.7, 0.18)
const FLAG_RED := Color(0.81, 0.07, 0.15)
const FLAG_WHITE := Color(0.97, 0.97, 0.97)
const FLAG_BLACK := Color(0.04, 0.04, 0.04)
const STRIPE := 3.0

var plate := Rect2()


# s: حجم الأيقونة (أو مقياس اللوحة عند عدم وجودها). with_emblem: إظهار الأيقونة. with_label: إظهار اللوحة والنص.
func setup(s: float, with_emblem := false, with_label := true) -> IraqBadge:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fs: int = clampi(int(s * 0.24), 14, 34) if with_emblem else clampi(int(s * 0.3), 14, 34)
	var th: float = STRIPE * 3.0 + float(fs) * 1.6 + 6.0 if with_label else 0.0
	var w: float = s * 2.0 if with_emblem else s * 3.2
	var ih: float = s + 6.0 if with_emblem else 0.0
	custom_minimum_size = Vector2(w, ih + th)
	size = custom_minimum_size
	if with_emblem:
		var tr := TextureRect.new()
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if ResourceLoader.exists(EMBLEM_PATH):
			tr.texture = load(EMBLEM_PATH)
		tr.size = Vector2(s, s)
		tr.position = Vector2((w - s) * 0.5, 0.0)
		add_child(tr)
	if with_label:
		plate = Rect2(0.0, ih, w, th)
		var lbl := Label.new()
		lbl.text = "صنع في العراق"
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.position = Vector2(0.0, ih + STRIPE * 3.0 + 2.0)
		lbl.size = Vector2(w, th - STRIPE * 3.0 - 4.0)
		lbl.add_theme_font_size_override("font_size", fs)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.93, 0.7))
		lbl.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.02, 0.95))
		lbl.add_theme_constant_override("outline_size", maxi(3, int(fs * 0.2)))
		add_child(lbl)
	queue_redraw()
	return self


func _draw() -> void:
	if plate.size.y <= 0.0:
		return
	var p := plate.position
	var w := plate.size.x
	draw_rect(plate, Color(0.04, 0.06, 0.07, 0.94))
	draw_rect(Rect2(p.x + 2.0, p.y + 2.0, w - 4.0, STRIPE), FLAG_RED)
	draw_rect(Rect2(p.x + 2.0, p.y + 2.0 + STRIPE, w - 4.0, STRIPE), FLAG_WHITE)
	draw_rect(Rect2(p.x + 2.0, p.y + 2.0 + STRIPE * 2.0, w - 4.0, STRIPE), FLAG_BLACK)
	draw_rect(plate, GOLD, false, 2.0)
