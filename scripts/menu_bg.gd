class_name MenuBg
extends Control
## خلفية حربية حديثة متحركة للقائمة وشاشة التحميل: شبكة تكتيكية، خطوط كنتورية، رادار بمسح دوّار،
## طائرة تعبر الشاشة، أقواس زوايا وإحداثيات بغداد.

const GREEN := Color(0.36, 0.9, 0.52)
const AMBER := Color(0.96, 0.7, 0.18)

var t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	if is_visible_in_tree():
		t += delta
		queue_redraw()


func _dir(a: float) -> Vector2:
	return Vector2(cos(a), sin(a))


func _draw() -> void:
	var s := size
	var c0 := Color(0.025, 0.04, 0.055)
	var c1 := Color(0.065, 0.1, 0.12)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x, s.y), Vector2(0, s.y)]), PackedColorArray([c0, c0, c1, c1]))
	_grid(s)
	_contours(s)
	_radar(s)
	_jet(s)
	_frame(s)
	var y: float = fposmod(t * 90.0, s.y + 240.0) - 120.0
	draw_rect(Rect2(0, y, s.x, 70), Color(GREEN.r, GREEN.g, GREEN.b, 0.03))
	var black := Color(0, 0, 0, 0.6)
	var clear := Color(0, 0, 0, 0)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x, 130), Vector2(0, 130)]), PackedColorArray([black, black, clear, clear]))
	draw_polygon(PackedVector2Array([Vector2(0, s.y), Vector2(s.x, s.y), Vector2(s.x, s.y - 130), Vector2(0, s.y - 130)]), PackedColorArray([black, black, clear, clear]))
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(170, 0), Vector2(170, s.y), Vector2(0, s.y)]), PackedColorArray([black, clear, clear, black]))
	draw_polygon(PackedVector2Array([Vector2(s.x, 0), Vector2(s.x - 170, 0), Vector2(s.x - 170, s.y), Vector2(s.x, s.y)]), PackedColorArray([black, clear, clear, black]))


func _grid(s: Vector2) -> void:
	var sp := 56.0
	var ox: float = fposmod(t * 8.0, sp)
	var oy: float = fposmod(t * 4.0, sp)
	var col := Color(0.5, 0.75, 0.7, 0.055)
	var x: float = ox - sp
	while x < s.x:
		draw_line(Vector2(x, 0), Vector2(x, s.y), col, 1.0)
		x += sp
	var y: float = oy - sp
	while y < s.y:
		draw_line(Vector2(0, y), Vector2(s.x, y), col, 1.0)
		var xx: float = ox - sp
		while xx < s.x:
			draw_line(Vector2(xx - 3, y), Vector2(xx + 3, y), Color(0.6, 0.9, 0.8, 0.16), 1.0)
			draw_line(Vector2(xx, y - 3), Vector2(xx, y + 3), Color(0.6, 0.9, 0.8, 0.16), 1.0)
			xx += sp * 3.0
		y += sp


func _contours(s: Vector2) -> void:
	for lvl in range(7):
		var pts := PackedVector2Array()
		var x := 0.0
		while x <= s.x + 32.0:
			var y: float = s.y * (0.2 + 0.1 * float(lvl)) + sin(x * 0.006 + float(lvl) * 1.3 + t * 0.15) * 26.0 + sin(x * 0.013 + float(lvl) * 2.1 - t * 0.1) * 10.0
			pts.append(Vector2(x, y))
			x += 32.0
		draw_polyline(pts, Color(0.35, 0.6, 0.5, 0.075), 1.2)


func _radar(s: Vector2) -> void:
	var c := Vector2(s.x * 0.8, s.y * 0.5)
	var r: float = s.y * 0.46
	var ring := Color(GREEN.r, GREEN.g, GREEN.b, 0.17)
	for k in range(1, 5):
		draw_arc(c, r * float(k) / 4.0, 0.0, TAU, 64, ring, 1.2, true)
	draw_line(c - Vector2(r, 0), c + Vector2(r, 0), ring, 1.0)
	draw_line(c - Vector2(0, r), c + Vector2(0, r), ring, 1.0)
	for i in range(36):
		var d := _dir(float(i) * TAU / 36.0)
		draw_line(c + d * r, c + d * (r + (9.0 if i % 3 == 0 else 5.0)), Color(GREEN.r, GREEN.g, GREEN.b, 0.3), 1.0)
	var a: float = t * 1.1
	for i in range(26):
		var a0: float = a - float(i) * 0.035
		var a1: float = a - float(i + 1) * 0.035
		draw_colored_polygon(PackedVector2Array([c, c + _dir(a0) * r, c + _dir(a1) * r]), Color(GREEN.r, GREEN.g, GREEN.b, 0.17 * (1.0 - float(i) / 26.0)))
	draw_line(c, c + _dir(a) * r, Color(GREEN.r, GREEN.g, GREEN.b, 0.7), 2.0)
	for k in range(9):
		var ang: float = float(k) * 0.83 + 0.3
		var dist: float = r * (0.18 + 0.72 * fposmod(float(k) * 0.37, 1.0))
		var diff: float = fposmod(a - ang, TAU)
		var al: float = clampf(1.0 - diff / (TAU * 0.8), 0.0, 1.0)
		if al > 0.02:
			var p: Vector2 = c + _dir(ang) * dist
			draw_circle(p, 3.5, Color(GREEN.r, GREEN.g, GREEN.b, al))
			draw_arc(p, 6.0 + (1.0 - al) * 10.0, 0.0, TAU, 16, Color(GREEN.r, GREEN.g, GREEN.b, al * 0.5), 1.0)


func _jet(s: Vector2) -> void:
	var ph: float = fposmod(t, 15.0)
	if ph > 6.0:
		return
	var f: float = ph / 6.0
	var x: float = lerpf(-80.0, s.x + 80.0, f)
	var y: float = s.y * 0.13 + sin(f * 6.0) * 5.0
	draw_line(Vector2(x - 220, y), Vector2(x - 20, y), Color(0.85, 0.95, 0.95, 0.18), 3.0)
	draw_line(Vector2(x - 120, y), Vector2(x - 20, y), Color(0.85, 0.95, 0.95, 0.3), 2.0)
	var col := Color(0.78, 0.86, 0.86, 0.6)
	draw_colored_polygon(PackedVector2Array([Vector2(x + 22, y), Vector2(x - 14, y - 4), Vector2(x - 18, y), Vector2(x - 14, y + 4)]), col)
	draw_colored_polygon(PackedVector2Array([Vector2(x + 2, y), Vector2(x - 10, y - 17), Vector2(x - 15, y - 17), Vector2(x - 8, y)]), col)
	draw_colored_polygon(PackedVector2Array([Vector2(x + 2, y), Vector2(x - 10, y + 17), Vector2(x - 15, y + 17), Vector2(x - 8, y)]), col)
	draw_circle(Vector2(x - 19, y), 2.5, Color(1, 0.6, 0.2, 0.9))


func _frame(s: Vector2) -> void:
	var m := 16.0
	var l := 44.0
	var col := Color(AMBER.r, AMBER.g, AMBER.b, 0.85)
	for sx in [0, 1]:
		for sy in [0, 1]:
			var px: float = m if sx == 0 else s.x - m
			var py: float = m if sy == 0 else s.y - m
			var dx: float = l if sx == 0 else -l
			var dy: float = l if sy == 0 else -l
			draw_line(Vector2(px, py), Vector2(px + dx, py), col, 2.0)
			draw_line(Vector2(px, py), Vector2(px, py + dy), col, 2.0)
	var x := 90.0
	while x < s.x - 90.0:
		draw_line(Vector2(x, 8), Vector2(x, 8 + (7.0 if int(x / 16.0) % 5 == 0 else 4.0)), Color(0.8, 0.9, 0.85, 0.18), 1.0)
		x += 16.0
	var f := get_theme_default_font()
	if f != null:
		draw_string(f, Vector2(34, s.y - 30), "33°18′N  44°22′E  ·  BAGHDAD", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.85, 0.8, 0.6))
