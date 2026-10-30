extends Node
## أصوات ذات طابع تاريخي: عود وناي وطبول إطارية بمقام الحجاز، ومؤثرات خشبية وحجرية هادئة. كلها تُولَّد بالكود.
## لاستبدالها ضع ملفات في assets/audio باسم الصوت (بصيغة ogg): click shot mg cannon boom hit music ...
## التحسينات: ناقلات صوت (SFX/Music) مع صدى خفيف ومحدّد قمم، أصوات قتال متعددة الطبقات (فرقعة + دوي + ذيل)،
## تنوّع طفيف في طبقة الصوت، حد أدنى بين تكرار الصوت نفسه، وبناء الأصوات الثقيلة تدريجياً دون تجميد البداية.

const RATE := 22050
var streams := {}
var pool: Array = []
var music: AudioStreamPlayer
var muted := false
var music_ready := false
var loops := {}
const CFG_PATH := "user://settings.cfg"
var music_vol := 0.8
var sfx_vol := 0.9
var last_play := {}

# أقل فاصل (ثانية) بين تشغيل الصوت نفسه، لمنع التكدس والتشويش
const GAP := {"shot": 0.05, "mg": 0.07, "smg": 0.07, "hit": 0.06, "hit_metal": 0.07, "hit_stone": 0.07, "cannon": 0.1, "cannon_light": 0.08, "cannon_heavy": 0.12, "rocket": 0.1, "sniper": 0.1, "artillery": 0.15, "aa": 0.06, "heli_gun": 0.1, "jet_gun": 0.12, "bomb": 0.12, "boom": 0.1, "boom_small": 0.08}
# أصوات القتال يتنوع ارتفاعها قليلاً لتبدو طبيعية
const VARY := ["shot", "mg", "smg", "hit", "hit_metal", "hit_stone", "cannon", "cannon_light", "cannon_heavy", "rocket", "sniper", "artillery", "aa", "heli_gun", "jet_gun", "bomb", "boom", "boom_small"]
# تعديل مستوى الصوت لكل نوع (ديسيبل)
const GAIN := {"shot": -3.0, "mg": -5.0, "smg": -5.0, "hit": -6.0, "hit_metal": -5.0, "hit_stone": -5.0, "aa": -4.0, "heli_gun": -3.0, "jet_gun": -3.0, "boom": 1.0}
# أصوات مهمة تُقاطع غيرها عند امتلاء المشغّلات
const PRIORITY := ["boom", "alert", "win", "lose", "click", "ok", "bad", "go", "start"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for i in 20:
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		p.bus = "SFX"
		add_child(p)
		pool.append(p)
	music = AudioStreamPlayer.new()
	music.volume_db = -9.0
	music.bus = "Music"
	add_child(music)
	_load_settings()
	_build_sfx()
	var loop_defs := {"steps": _loop_steps(), "engine": _loop_engine(), "air": _loop_air()}
	for k in loop_defs.keys():
		var lp := AudioStreamPlayer.new()
		lp.stream = _wav(loop_defs[k], true)
		lp.volume_db = -80.0
		lp.bus = "SFX"
		add_child(lp)
		lp.play()
		loops[k] = lp
	for k in streams.keys():
		var path := "res://assets/audio/%s.ogg" % k
		if ResourceLoader.exists(path):
			streams[k] = load(path)
	call_deferred("_build_extra")
	call_deferred("_build_combat")


# ناقلات الصوت: SFX بصدى خفيف، Music، ومحدّد قمم على الناقل الرئيسي حتى لا يتشوه الصوت عند كثرة المعارك
func _setup_buses() -> void:
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		var i: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, "SFX")
		AudioServer.set_bus_send(i, "Master")
		var rv := AudioEffectReverb.new()
		rv.room_size = 0.35
		rv.damping = 0.6
		rv.wet = 0.1
		rv.dry = 1.0
		AudioServer.add_bus_effect(i, rv)
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		var j: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(j, "Music")
		AudioServer.set_bus_send(j, "Master")
	var lim := AudioEffectLimiter.new()
	lim.ceiling_db = -1.0
	lim.threshold_db = -4.0
	AudioServer.add_bus_effect(0, lim)


func _build_sfx() -> void:
	# أصوات الواجهة: نغمات ناعمة تشبه الكالمبا والجرس الزجاجي بدل النقرات الخشبية الجافة
	streams["click"] = _wav(_mix(_chime(880.0, 0.2, 0.34), _chime(1320.0, 0.14, 0.12), 0.012))
	streams["ok"] = _wav(_arp([659.25, 830.61, 987.77], 0.07, 0.3, 0.3))
	streams["bad"] = _wav(_arp([329.63, 261.63], 0.1, 0.32, 0.3))
	streams["place"] = _wav(_mix(_thud(95.0, 50.0, 0.28, 0.8), _noise_lp(0.12, 0.5, 0.25, 18.0), 0.0))
	streams["built"] = _wav(_mix(_mix(_pluck(293.66, 0.5, 0.5), _pluck(370.0, 0.5, 0.45), 0.12), _pluck(440.0, 0.7, 0.45), 0.24))
	streams["deliver"] = _wav(_mix(_bell(1320.0, 0.35, 0.22), _bell(1760.0, 0.3, 0.18), 0.06))
	streams["spawn_inf"] = _wav(_mix(_mix(_wood(330.0, 0.05, 0.4), _wood(330.0, 0.05, 0.4), 0.11), _horn(262.0, 0.5, 0.22), 0.2))
	streams["spawn_tank"] = _wav(_mix(_mix(_thud(110.0, 55.0, 0.3, 0.7), _thud(110.0, 55.0, 0.3, 0.7), 0.15), _noise_lp(0.5, 0.25, 0.04, 3.0), 0.0))
	streams["spawn_air"] = _wav(_mix(_whoosh(0.9, 0.5), _horn(196.0, 0.7, 0.2), 0.1))
	streams["shot"] = _wav(_mix(_noise_lp(0.07, 0.7, 0.5, 28.0), _thud(220.0, 110.0, 0.05, 0.25), 0.0))
	streams["cannon"] = _wav(_mix(_noise_lp(0.35, 0.8, 0.12, 9.0), _thud(100.0, 35.0, 0.4, 0.9), 0.0))
	streams["boom"] = _wav(_mix(_noise_lp(0.9, 0.9, 0.07, 5.0), _thud(80.0, 28.0, 0.8, 1.0), 0.0))
	streams["hit"] = _wav(_mix(_wood(180.0, 0.09, 0.6), _noise_lp(0.05, 0.4, 0.4, 40.0), 0.0))
	var win := PackedFloat32Array()
	var wn := [293.66, 370.0, 440.0, 587.33]
	for i in 4:
		win = _mix(win, _horn(wn[i], 0.5, 0.3), 0.22 * i)
	win = _mix(win, _thud(100.0, 50.0, 0.5, 0.8), 0.0)
	streams["win"] = _wav(win)
	var lose := PackedFloat32Array()
	var ln := [293.66, 261.63, 220.0, 146.83]
	for i in 4:
		lose = _mix(lose, _pluck(ln[i], 0.8, 0.5), 0.28 * i)
	streams["lose"] = _wav(lose)


func _build_extra() -> void:
	# أصوات التجهيز: لكل فئة صوت مختلف
	var ti := PackedFloat32Array()
	ti.resize(int(0.95 * RATE))
	for k in range(5):
		_add(ti, _noise_lp(0.06, 0.34 + 0.08 * float(k), 0.6, 14.0), int(float(k) * 0.055 * RATE))
	_add(ti, _horn(392.0, 0.2, 0.3), int(0.3 * RATE))
	_add(ti, _horn(523.25, 0.45, 0.32), int(0.5 * RATE))
	streams["train_inf"] = _wav(ti)
	var tt := _engine_rev(0.9, 42.0, 105.0, 0.55)
	_add(tt, _thud(140.0, 60.0, 0.2, 0.7), 0)
	_add(tt, _bell(190.0, 0.3, 0.18), int(0.02 * RATE))
	streams["train_tank"] = _wav(tt)
	streams["train_air"] = _wav(_mix(_spool(1.1, 0.55), _whoosh(0.7, 0.3), 0.35))
	streams["train_truck"] = _wav(_mix(_engine_rev(0.5, 60.0, 95.0, 0.4), _horn(330.0, 0.14, 0.22), 0.3))
	streams["alert"] = _wav(_siren(1.15, 0.42))
	var rp := PackedFloat32Array()
	rp.resize(int(0.95 * RATE))
	_add(rp, _noise_lp(0.4, 0.16, 0.5, 5.0), 0)
	for k in range(4):
		_add(rp, _wood(700.0 + 180.0 * float(k), 0.07, 0.5), int(float(k) * 0.12 * RATE))
		_add(rp, _bell(1500.0 + 220.0 * float(k), 0.18, 0.12), int(float(k) * 0.12 * RATE))
	streams["repair"] = _wav(rp)
	# أصوات الاختيار: لكل جيش نغمة خاصة
	streams["pick_red"] = _wav(_mix(_arp([293.66, 440.0, 587.33], 0.07, 0.34, 0.3), _thud(110.0, 60.0, 0.2, 0.22), 0.0))
	streams["pick_blue"] = _wav(_arp([329.63, 493.88, 659.25, 987.77], 0.065, 0.34, 0.28))
	streams["pick_yellow"] = _wav(_mix(_arp([392.0, 587.33, 783.99], 0.07, 0.36, 0.28), _bell(1568.0, 0.4, 0.1), 0.14))
	streams["pick_white"] = _wav(_mix(_ney(392.0, 0.3, 0.26), _arp([523.25, 698.46], 0.1, 0.36, 0.22), 0.06))
	streams["pick_mode"] = _wav(_arp([740.0, 987.77], 0.07, 0.24, 0.28))
	streams["diff_easy"] = _wav(_arp([783.99, 1174.66], 0.08, 0.3, 0.28))
	streams["diff_normal"] = _wav(_mix(_arp([587.33, 740.0, 880.0], 0.07, 0.3, 0.28), _thud(150.0, 80.0, 0.16, 0.18), 0.0))
	streams["diff_hard"] = _wav(_mix(_arp([440.0, 349.23, 293.66], 0.09, 0.4, 0.3), _thud(90.0, 45.0, 0.4, 0.4), 0.0))
	var st := PackedFloat32Array()
	st.resize(int(1.3 * RATE))
	for k in range(8):
		_add(st, _noise_lp(0.06, 0.3 + 0.04 * float(k), 0.6, 14.0), int(float(k) * 0.045 * RATE))
	_add(st, _horn(293.66, 0.7, 0.28), int(0.4 * RATE))
	_add(st, _horn(370.0, 0.7, 0.26), int(0.4 * RATE))
	_add(st, _horn(440.0, 0.7, 0.26), int(0.4 * RATE))
	_add(st, _thud(100.0, 45.0, 0.5, 0.8), int(0.4 * RATE))
	streams["start"] = _wav(st)
	streams["go"] = _wav(_mix(_horn(293.66, 0.3, 0.3), _horn(440.0, 0.5, 0.32), 0.15))
	streams["tick"] = _wav(_chime(1175.0, 0.09, 0.2))
	streams["saved"] = _wav(_mix(_bell(1046.0, 0.3, 0.25), _bell(1568.0, 0.4, 0.22), 0.08))
	streams["repaired"] = _wav(_mix(_bell(880.0, 0.5, 0.3), _bell(1320.0, 0.5, 0.28), 0.1))


func play(key: String) -> void:
	if muted or sfx_vol <= 0.001 or not streams.has(key):
		return
	var now: int = Time.get_ticks_msec()
	var gap: float = float(GAP.get(key, 0.0))
	if gap > 0.0 and now - int(last_play.get(key, -100000)) < int(gap * 1000.0):
		return
	last_play[key] = now
	var pl: AudioStreamPlayer = null
	for p in pool:
		if not p.playing:
			pl = p
			break
	if pl == null:
		if not PRIORITY.has(key):
			return
		var oldest := 0.0
		pl = pool[0]
		for p in pool:
			var pos: float = p.get_playback_position()
			if pos >= oldest:
				oldest = pos
				pl = p
	pl.stream = streams[key]
	pl.pitch_scale = randf_range(0.94, 1.06) if VARY.has(key) else 1.0
	pl.volume_db = -6.0 + linear_to_db(sfx_vol) + float(GAIN.get(key, 0.0))
	pl.play()


func _music_db() -> float:
	if muted or music_vol <= 0.001:
		return -80.0
	return -9.0 + linear_to_db(music_vol)


func set_music_volume(v: float) -> void:
	music_vol = clampf(v, 0.0, 1.0)
	music.volume_db = _music_db()
	save_settings()


func set_sfx_volume(v: float) -> void:
	sfx_vol = clampf(v, 0.0, 1.0)
	save_settings()


func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(CFG_PATH) == OK:
		music_vol = float(cf.get_value("audio", "music", 0.8))
		sfx_vol = float(cf.get_value("audio", "sfx", 0.9))
	music.volume_db = _music_db()


func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("audio", "music", music_vol)
	cf.set_value("audio", "sfx", sfx_vol)
	cf.save(CFG_PATH)


func warm_music() -> void:
	pass


func prepare_music() -> void:
	if music_ready:
		return
	var path := "res://assets/audio/music.ogg"
	if ResourceLoader.exists(path):
		music.stream = load(path)
	else:
		music.stream = _wav(_build_music(), true)
	music_ready = true


func start_music() -> void:
	prepare_music()
	music.stream_paused = false
	if not music.playing:
		music.play()
	music.volume_db = _music_db()


func stop_music() -> void:
	music.stop()


func set_muted(m: bool) -> void:
	muted = m
	music.volume_db = _music_db()


func set_loops(steps: int, engine: int, air: int) -> void:
	var arr := [steps, engine, air]
	var keys := ["steps", "engine", "air"]
	var caps := [0.18, 0.22, 0.2]
	for i in 3:
		var cnt: int = arr[i]
		var vol := 0.0
		if cnt > 0 and not muted:
			vol = minf(0.04 + 0.02 * cnt, float(caps[i])) * sfx_vol
		loops[keys[i]].volume_db = -80.0 if vol <= 0.0 else linear_to_db(vol)


# أصوات القتال تُبنى تدريجياً (إطار واحد لكل صوتين) كي لا يتجمد التطبيق عند البداية
func _build_combat() -> void:
	var defs: Array = [
		["shot", func(): return _s_shot()],
		["mg", func(): return _s_mg()],
		["smg", func(): return _s_smg()],
		["sniper", func(): return _s_sniper()],
		["rocket", func(): return _s_rocket()],
		["cannon_light", func(): return _s_cannon(0.1, 0.25, 140.0, 70.0, 0.4)],
		["cannon", func(): return _s_cannon(0.14, 0.5, 110.0, 38.0, 0.8)],
		["cannon_heavy", func(): return _s_cannon(0.18, 0.7, 85.0, 28.0, 1.0)],
		["artillery", func(): return _s_artillery()],
		["aa", func(): return _s_aa()],
		["heli_gun", func(): return _s_heli_gun()],
		["jet_gun", func(): return _s_jet_gun()],
		["boom_small", func(): return _s_boom(0.6, 0.8, 0.5)],
		["bomb", func(): return _mix(_whistle(0.4, 1500.0, 450.0, 0.35), _s_boom(0.7, 0.9, 0.7), 0.3)],
		["boom", func(): return _s_boom(1.1, 1.0, 1.3)],
		["hit", func(): return _mix(_noise_lp(0.06, 0.5, 0.35, 25.0), _thud(160.0, 90.0, 0.06, 0.4), 0.0)],
		["hit_metal", func(): return _mix(_bell(900.0, 0.2, 0.22), _crack(0.03, 0.7, 10.0, 0.3), 0.0)],
		["hit_stone", func(): return _mix(_crack(0.06, 0.8, 12.0, 0.1), _thud(120.0, 70.0, 0.08, 0.5), 0.0)],
	]
	var n := 0
	for d in defs:
		streams[str(d[0])] = _wav((d[1] as Callable).call())
		n += 1
		if n % 2 == 0:
			await get_tree().process_frame
	for k in streams.keys():
		var path := "res://assets/audio/%s.ogg" % k
		if ResourceLoader.exists(path):
			streams[k] = load(path)


func _s_shot() -> PackedFloat32Array:
	var a := _mix(_crack(0.09, 0.9, 8.0, 0.2), _sub(210.0, 90.0, 0.08, 0.5, 8.0), 0.0)
	return _norm(_tail(a, 0.25, 0.05, 0.3), 0.85)


func _s_mg() -> PackedFloat32Array:
	var a := _mix(_crack(0.06, 0.9, 9.0, 0.28), _sub(280.0, 130.0, 0.05, 0.4, 9.0), 0.0)
	return _norm(_tail(a, 0.08, 0.03, 0.22), 0.8)


func _s_smg() -> PackedFloat32Array:
	var a := _mix(_crack(0.05, 0.85, 10.0, 0.36), _sub(360.0, 180.0, 0.04, 0.35, 10.0), 0.0)
	return _norm(_tail(a, 0.06, 0.025, 0.2), 0.8)


func _s_sniper() -> PackedFloat32Array:
	var a := _mix(_crack(0.22, 1.0, 5.0, 0.15), _sub(130.0, 50.0, 0.3, 0.9, 5.0), 0.0)
	return _norm(_tail(a, 0.9, 0.09, 0.42), 0.9)


func _s_rocket() -> PackedFloat32Array:
	var a := _mix(_whoosh(0.55, 0.55), _sub(150.0, 60.0, 0.22, 0.7, 6.0), 0.0)
	a = _mix(a, _rumble(0.5, 0.35, 4.0), 0.05)
	return _norm(_tail(a, 0.5, 0.07, 0.35), 0.85)


func _s_cannon(crack_dur: float, body_dur: float, f0: float, f1: float, vol: float) -> PackedFloat32Array:
	var a := _mix(_crack(crack_dur, 0.9, 6.0, 0.12), _sub(f0, f1, body_dur, 0.95, 5.0), 0.0)
	a = _mix(a, _rumble(body_dur, vol * 0.5, 4.0), 0.02)
	return _norm(_tail(a, body_dur + 0.3, 0.08, 0.4), 0.9)


func _s_artillery() -> PackedFloat32Array:
	var a := _mix(_sub(70.0, 30.0, 0.6, 1.0, 4.0), _crack(0.12, 0.7, 7.0, 0.12), 0.0)
	a = _mix(a, _bell(420.0, 0.5, 0.15), 0.0)
	return _norm(_tail(a, 1.2, 0.12, 0.45), 0.9)


func _s_aa() -> PackedFloat32Array:
	var a := _mix(_crack(0.035, 0.85, 9.0, 0.3), _crack(0.035, 0.85, 9.0, 0.3), 0.05)
	a = _mix(a, _bell(1800.0, 0.12, 0.08), 0.0)
	return _norm(a, 0.8)


func _s_heli_gun() -> PackedFloat32Array:
	var a := _crack(0.04, 0.85, 9.0, 0.3)
	a = _mix(a, _crack(0.04, 0.85, 9.0, 0.3), 0.06)
	a = _mix(a, _crack(0.04, 0.85, 9.0, 0.3), 0.12)
	a = _mix(a, _sub(95.0, 70.0, 0.2, 0.4, 5.0), 0.0)
	return _norm(_tail(a, 0.15, 0.04, 0.25), 0.8)


func _s_jet_gun() -> PackedFloat32Array:
	return _norm(_tail(_brrt(0.3, 70.0, 0.9), 0.2, 0.04, 0.25), 0.85)


# انفجار: دوي منخفض + فرقعة + حطام متناثر + ذيل صدى
func _s_boom(dur: float, vol: float, tail_sec: float) -> PackedFloat32Array:
	var a := _mix(_rumble(dur, vol, 3.2), _sub(62.0, 24.0, dur * 0.9, vol, 3.0), 0.0)
	a = _mix(a, _crack(0.12, 0.9, 6.0, 0.12), 0.0)
	for k in range(6):
		a = _mix(a, _crack(0.02, 0.3, 6.0, 0.25), 0.15 + randf() * dur * 0.6)
	return _norm(_tail(a, tail_sec, 0.1, 0.5), 0.9)


# ---------- مرشحات ومولّدات صوت متقدمة ----------
func _hp_noise(n: int, a: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		var w := randf() * 2.0 - 1.0
		y += (w - y) * a
		out[i] = w - y
	return out


# فرقعة حادة: ضوضاء عالية التردد سريعة التلاشي
func _crack(dur: float, vol: float, decay: float, a := 0.2) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var nz := _hp_noise(n, a)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / float(n)
		out[i] = nz[i] * vol * exp(-decay * t)
	return out


# دوي منخفض: موجة جيبية هابطة التردد
func _sub(f0: float, f1: float, dur: float, vol: float, decay: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / float(n)
		ph += TAU * lerpf(f0, f1, t) / RATE
		out[i] = sin(ph) * vol * minf(float(i) / 40.0, 1.0) * exp(-decay * t)
	return out


# هدير: ضوضاء يزداد إغلاق مرشحها مع الزمن (كصوت انفجار بعيد)
func _rumble(dur: float, vol: float, decay: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		var t := float(i) / float(n)
		var a: float = lerpf(0.45, 0.025, minf(t * 2.0, 1.0))
		y += (randf() * 2.0 - 1.0 - y) * a
		out[i] = y * vol * 3.0 * exp(-decay * t)
	return out


# أزيز سريع النبض (مدفع الطائرة)
func _brrt(dur: float, rate: float, vol: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var nz := _hp_noise(n, 0.35)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / float(n)
		var am: float = 0.35 + 0.65 * maxf(sin(TAU * rate * float(i) / RATE), 0.0)
		out[i] = nz[i] * vol * am * minf(t * 12.0, 1.0) * (1.0 - smoothstep(0.7, 1.0, t))
	return out


# صفير هابط (سقوط القنبلة)
func _whistle(dur: float, f0: float, f1: float, vol: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / float(n)
		ph += TAU * lerpf(f0, f1, t) / RATE
		out[i] = sin(ph) * vol * minf(t * 8.0, 1.0) * (1.0 - smoothstep(0.8, 1.0, t))
	return out


# ذيل صدى: عدة ارتدادات مرشّحة تعطي إحساس المكان المفتوح
func _tail(a: PackedFloat32Array, extra_sec: float, base: float, fb: float) -> PackedFloat32Array:
	var n0: int = a.size()
	var n: int = n0 + int(extra_sec * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n0:
		out[i] = a[i]
	var taps := [1.0, 1.7, 2.45, 3.3]
	for k in taps.size():
		var d: int = int(base * float(taps[k]) * RATE)
		var gain: float = pow(fb, float(k + 1))
		var y := 0.0
		for i in n0:
			var j: int = i + d
			if j >= n:
				break
			y += (a[i] - y) * 0.3
			out[j] += y * gain
	return out


# يمنع التشويه: يخفض الصوت إن تجاوز الذروة المسموحة
func _norm(a: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var m := 0.0
	for v in a:
		m = maxf(m, absf(v))
	if m > peak:
		var k: float = peak / m
		for i in a.size():
			a[i] = a[i] * k
	return a


# ---------- أدوات التوليد ----------
func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	var b := PackedByteArray()
	b.resize(samples.size() * 2)
	for i in samples.size():
		b.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	s.data = b
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = samples.size()
	return s


func _mix(a: PackedFloat32Array, b: PackedFloat32Array, offset_sec: float) -> PackedFloat32Array:
	var off := int(offset_sec * RATE)
	var n: int = maxi(a.size(), b.size() + off)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in a.size():
		out[i] = a[i]
	for i in b.size():
		out[i + off] += b[i]
	return out


func _add(dst: PackedFloat32Array, src: PackedFloat32Array, at: int) -> void:
	var n: int = mini(src.size(), dst.size() - at)
	for i in n:
		dst[at + i] += src[i]


func _lp(n: int, a: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		y += (randf() * 2.0 - 1.0 - y) * a
		out[i] = y
	return out


func _noise_lp(dur: float, vol: float, a: float, decay: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var nz := _lp(n, a)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = nz[i] * vol * 2.5 * exp(-decay * float(i) / float(n))
	return out


func _thud(f0: float, f1: float, dur: float, vol: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / float(n)
		ph += TAU * lerpf(f0, f1, t) / RATE
		out[i] = sin(ph) * vol * exp(-6.0 * t)
	return out


func _wood(f: float, dur: float, vol: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var p1 := 0.0
	var p2 := 0.0
	for i in n:
		var t := float(i) / float(n)
		p1 += TAU * f / RATE
		p2 += TAU * f * 2.4 / RATE
		out[i] = (sin(p1) * 0.8 + sin(p2) * 0.35) * vol * exp(-14.0 * t)
	return out


# نغمة ناعمة: هجوم قصير جداً وتلاشٍ سلس مع جهير ثانٍ خافت (إحساس الكالمبا/الجرس الزجاجي)
func _chime(f: float, dur: float, vol: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var decay: float = 5.5 / maxf(dur, 0.05)
	for i in n:
		var t := float(i) / RATE
		var att: float = minf(t / 0.004, 1.0)
		var env: float = att * exp(-decay * t)
		out[i] = (sin(TAU * f * t) + 0.28 * sin(TAU * f * 2.0 * t) * exp(-9.0 * t) + 0.08 * sin(TAU * f * 3.01 * t) * exp(-14.0 * t)) * env * vol
	return out


# أرابيج من عدة نغمات متتالية: step ثواني بين النغمة والتالية
func _arp(notes: Array, step: float, dur: float, vol: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int((step * float(notes.size()) + dur) * RATE))
	for k in notes.size():
		_add(out, _chime(float(notes[k]), dur, vol), int(float(k) * step * RATE))
	return out


func _bell(f: float, dur: float, vol: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		out[i] = (sin(TAU * f * t) * exp(-6.0 * t) + sin(TAU * f * 2.76 * t) * 0.5 * exp(-9.0 * t) + sin(TAU * f * 5.4 * t) * 0.25 * exp(-14.0 * t)) * vol
	return out


func _horn(f: float, dur: float, vol: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	var y := 0.0
	for i in n:
		var t := float(i) / float(n)
		ph += TAU * f * (1.0 + 0.006 * sin(TAU * 5.0 * float(i) / RATE)) / RATE
		var saw := fposmod(ph, TAU) / TAU * 2.0 - 1.0
		y += (saw - y) * 0.12
		var env := minf(t * 12.0, 1.0) * (1.0 - smoothstep(0.7, 1.0, t))
		out[i] = y * vol * env * 1.6
	return out


func _whoosh(dur: float, vol: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		var t := float(i) / float(n)
		y += (randf() * 2.0 - 1.0 - y) * lerpf(0.04, 0.3, t)
		out[i] = y * vol * 2.2 * sin(PI * t)
	return out


func _pluck(freq: float, dur: float, vol: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var p: int = maxi(2, int(RATE / freq))
	var buf := PackedFloat32Array()
	buf.resize(p)
	for i in p:
		buf[i] = randf() * 2.0 - 1.0
	var out := PackedFloat32Array()
	out.resize(n)
	var idx := 0
	for i in n:
		var cur: float = buf[idx]
		out[i] = cur * vol
		var nxt: float = buf[(idx + 1) % p]
		buf[idx] = (cur + nxt) * 0.5 * 0.997
		idx = (idx + 1) % p
	return out


func _ney(freq: float, dur: float, vol: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var nz := _lp(n, 0.3)
	var ph := 0.0
	for i in n:
		var t := float(i) / float(n)
		ph += TAU * freq * (1.0 + 0.005 * sin(TAU * 5.2 * float(i) / RATE)) / RATE
		var env := minf(t * 10.0, 1.0) * (1.0 - smoothstep(0.75, 1.0, t))
		out[i] = (sin(ph) * 0.8 + sin(ph * 2.0) * 0.18 + nz[i] * 0.12) * vol * env
	return out


func _note(i: int) -> float:
	var base := [146.83, 155.56, 185.0, 196.0, 220.0, 233.08, 261.63]
	return float(base[posmod(i, 7)]) * pow(2.0, floorf(float(i) / 7.0))


func _echo(a: PackedFloat32Array, delay_sec: float, fb: float) -> void:
	var d := int(delay_sec * RATE)
	for i in range(d, a.size()):
		a[i] += a[i - d] * fb


func _loop_fix(a: PackedFloat32Array, fade_sec: float) -> PackedFloat32Array:
	var m := int(fade_sec * RATE)
	var n: int = a.size() - m
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = a[i]
	for i in m:
		var w := float(i) / float(m)
		out[i] = lerpf(a[n + i], a[i], w)
	return out


# ---------- مولّدات أصوات التجهيز والتنبيه ----------
func _engine_rev(dur: float, f0: float, f1: float, vol: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var nz := _lp(n, 0.06)
	var ph := 0.0
	for i in n:
		var t := float(i) / float(n)
		ph += TAU * lerpf(f0, f1, t * t) / RATE
		var saw: float = fposmod(ph, TAU) / TAU * 2.0 - 1.0
		var body: float = sin(ph) * 0.6 + saw * 0.35 + sin(ph * 2.0) * 0.2
		var env: float = minf(t * 8.0, 1.0) * (1.0 - smoothstep(0.75, 1.0, t))
		var rattle: float = 0.75 + 0.25 * sin(TAU * 28.0 * float(i) / RATE)
		out[i] = (body * rattle + nz[i] * 1.2) * vol * env
	return out


func _spool(dur: float, vol: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	var ph := 0.0
	for i in n:
		var t := float(i) / float(n)
		y += (randf() * 2.0 - 1.0 - y) * lerpf(0.02, 0.45, t)
		ph += TAU * lerpf(260.0, 1500.0, t * t) / RATE
		var env: float = minf(t * 5.0, 1.0) * (1.0 - smoothstep(0.8, 1.0, t))
		out[i] = (y * 1.8 * (0.3 + t) + sin(ph) * 0.12 * t) * vol * env
	return out


func _siren(dur: float, vol: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / float(n)
		var tone: float = 880.0 if int(t * 6.0) % 2 == 0 else 660.0
		ph += TAU * tone / RATE
		var sq: float = signf(sin(ph)) * 0.45 + sin(ph) * 0.55
		var seg: float = fposmod(t * 6.0, 1.0)
		out[i] = sq * vol * (1.0 - seg * 0.35) * minf(t * 40.0, 1.0) * (1.0 - smoothstep(0.9, 1.0, t))
	return out


# ---------- موسيقى تاريخية: مقام الحجاز ----------
func _build_music() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7741
	var step_sec := 60.0 / 84.0 / 2.0
	var steps := 64
	var total := int(step_sec * steps * RATE)
	var out := PackedFloat32Array()
	out.resize(total + RATE * 2)
	for i in total:
		var t := float(i) / RATE
		out[i] += sin(TAU * 73.42 * t) * 0.10 + sin(TAU * 110.0 * t) * 0.05 + sin(TAU * 146.83 * t) * 0.025
	for s in steps:
		var t0 := int(s * step_sec * RATE)
		var b: int = s % 8
		if b == 0 or b == 4:
			_add(out, _thud(120.0, 48.0, 0.3, 0.5), t0)
		if b == 2 or b == 3 or b == 6:
			_add(out, _noise_lp(0.06, 0.22, 0.6, 12.0), t0)
		if s % 32 == 0:
			_add(out, _thud(90.0, 35.0, 1.2, 0.7), t0)
		if s % 8 == 0:
			_add(out, _pluck(_note(0), 0.9, 0.38), t0)
	var ney := PackedFloat32Array()
	ney.resize(out.size())
	var phrase := [[7, 0, 2], [8, 2, 1], [7, 3, 1], [9, 4, 4], [10, 8, 2], [9, 10, 1], [8, 11, 1], [7, 12, 4], [9, 16, 2], [10, 18, 2], [11, 20, 2], [10, 22, 2], [9, 24, 1], [8, 25, 1], [7, 26, 6]]
	for nt in phrase:
		var dur: float = float(nt[2]) * step_sec * 0.96
		_add(ney, _ney(_note(nt[0]), dur, 0.28), int(float(nt[1]) * step_sec * RATE))
	_echo(ney, step_sec * 3.0, 0.28)
	var pat := [0, 4, 2, 4, 3, 4, 1, 4]
	for s in range(32, 64):
		if s % 2 == 0:
			var ix: int = pat[(s / 2) % 8] + (7 if (s % 16 == 0) else 0)
			_add(out, _pluck(_note(ix), 0.7, 0.45), int(s * step_sec * RATE))
	_add(out, _pluck(_note(7), 1.6, 0.4), int(62.0 * step_sec * RATE))
	for i in out.size():
		out[i] += ney[i]
	out.resize(total)
	return _loop_fix(out, 0.08)


# ---------- أصوات الحركة (هادئة) ----------
func _loop_engine() -> PackedFloat32Array:
	var n := int(1.0 * RATE)
	var nz := _lp(n, 0.02)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var am := 0.75 + 0.25 * sin(TAU * 4.0 * t)
		out[i] = (sin(TAU * 38.0 * t) * 0.12 + sin(TAU * 57.0 * t) * 0.07 + nz[i] * 0.8) * am
	return _loop_fix(out, 0.05)


func _loop_steps() -> PackedFloat32Array:
	var n := int(1.7 * RATE)
	var nz := _lp(n, 0.08)
	var out := PackedFloat32Array()
	out.resize(n)
	var times := [0.0, 0.45, 0.82, 1.3]
	for k in 4:
		var s0 := int(float(times[k]) * RATE)
		var blen := int(0.11 * RATE)
		for i in blen:
			out[s0 + i] = nz[s0 + i] * 2.2 * exp(-9.0 * float(i) / float(blen))
	return out


func _loop_air() -> PackedFloat32Array:
	var n := int(1.0 * RATE)
	var nz := _lp(n, 0.12)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		out[i] = nz[i] * 1.2 * (0.5 + 0.5 * sin(TAU * 16.0 * t)) + sin(TAU * 70.0 * t) * 0.08
	return _loop_fix(out, 0.05)
