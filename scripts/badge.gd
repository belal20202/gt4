class_name IraqBadge
extends Control
## عنصر «صنع في العراق»: نص ثابت بالعربية، ومعه اختيارياً أيقونة اللعبة الحربية (ثابتة بلا دوران).

const EMBLEM_PATH := "res://assets/emblem.png"


# s: حجم الأيقونة (أو مقياس الخط عند عدم وجودها). with_emblem: إظهار الأيقونة. with_label: إظهار النص.
func setup(s: float, with_emblem := false, with_label := true) -> IraqBadge:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fs: int = clampi(int(s * 0.17), 13, 34) if with_emblem else clampi(int(s * 0.3), 14, 34)
	var th: float = float(fs) * 1.6 if with_label else 0.0
	var w: float = s * 1.5 if with_emblem else s * 3.2
	var ih: float = s if with_emblem else 0.0
	custom_minimum_size = Vector2(w, ih + th + 2.0)
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
		var lbl := Label.new()
		lbl.text = "صنع في العراق"
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.position = Vector2(0.0, ih + 2.0)
		lbl.size = Vector2(w, th)
		lbl.add_theme_font_size_override("font_size", fs)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.93, 0.7))
		lbl.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.02, 0.95))
		lbl.add_theme_constant_override("outline_size", maxi(3, int(fs * 0.22)))
		add_child(lbl)
	return self
