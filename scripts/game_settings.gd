class_name GameSettings
extends RefCounted
## إعدادات الصورة والجودة والأداء (تُحفظ في user://graphics.cfg وتُطبَّق فوراً).
## الجودة: 0 منخفضة (هواتف ضعيفة)، 1 متوسطة، 2 عالية (هواتف قوية).

const PATH := "user://graphics.cfg"
const QUALITY_NAMES := ["منخفضة", "متوسطة", "عالية"]
const QUALITY_HINTS := [
	"للهواتف الضعيفة: بدون ظلال، دقة أقل، أشجار أقل ظهوراً من بعيد",
	"للهواتف المتوسطة: ظلال خفيفة وتوازن بين الجمال والسرعة",
	"للهواتف القوية: ظلال كاملة وحواف ناعمة وماء بأقصى تفاصيله",
]

static var quality := 1
static var brightness := 1.0   # 0.7 .. 1.3
static var contrast := 1.0     # 0.8 .. 1.3
static var saturation := 1.0   # 0.5 .. 1.5
static var fps := 60           # 30 / 45 / 60
static var loaded := false


# جودة مقترحة حسب قوة الجهاز (عدد أنوية المعالج) عند أول تشغيل
static func auto_quality() -> int:
	var cores: int = OS.get_processor_count()
	if cores <= 4:
		return 0
	if cores <= 6:
		return 1
	return 2


static func load_cfg() -> void:
	if loaded:
		return
	loaded = true
	quality = auto_quality()
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		quality = clampi(int(cf.get_value("gfx", "quality", quality)), 0, 2)
		brightness = clampf(float(cf.get_value("gfx", "brightness", 1.0)), 0.7, 1.3)
		contrast = clampf(float(cf.get_value("gfx", "contrast", 1.0)), 0.8, 1.3)
		saturation = clampf(float(cf.get_value("gfx", "saturation", 1.0)), 0.5, 1.5)
		fps = int(cf.get_value("gfx", "fps", 60))
		if fps != 30 and fps != 45 and fps != 60:
			fps = 60


static func save_cfg() -> void:
	var cf := ConfigFile.new()
	cf.set_value("gfx", "quality", quality)
	cf.set_value("gfx", "brightness", brightness)
	cf.set_value("gfx", "contrast", contrast)
	cf.set_value("gfx", "saturation", saturation)
	cf.set_value("gfx", "fps", fps)
	cf.save(PATH)


static func reset_image() -> void:
	brightness = 1.0
	contrast = 1.0
	saturation = 1.0


# يطبّق كل الإعدادات على المشهد الحالي (آمن للاستدعاء في أي وقت، حتى قبل وجود التضاريس)
static func apply(main: Main) -> void:
	load_cfg()
	var q: int = quality
	var vp: Viewport = main.get_viewport()
	var scales: Array = [0.7, 0.85, 1.0]
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = float(scales[q])
	vp.msaa_3d = Viewport.MSAA_2X if q == 2 else Viewport.MSAA_DISABLED
	Engine.max_fps = fps
	var atlas: Array = [1024, 1024, 2048]
	RenderingServer.directional_shadow_atlas_set_size(int(atlas[q]), true)
	var sq: Array = [RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, RenderingServer.SHADOW_QUALITY_SOFT_LOW]
	RenderingServer.directional_soft_shadow_filter_set_quality(sq[q])
	var dist: Array = [0.0, 60.0, 95.0]
	for c in main.get_children():
		if c is DirectionalLight3D:
			var sun: DirectionalLight3D = c
			sun.shadow_enabled = q > 0
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if q == 1 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			sun.directional_shadow_max_distance = maxf(float(dist[q]), 10.0)
		elif c is WorldEnvironment:
			var env: Environment = (c as WorldEnvironment).environment
			if env != null:
				env.adjustment_enabled = true
				env.adjustment_brightness = brightness
				env.adjustment_contrast = 1.06 * contrast
				env.adjustment_saturation = 1.25 * saturation
	var tr = main.terrain
	if tr != null and is_instance_valid(tr):
		var vk: Array = [0.5, 0.78, 1.0]
		for m in tr.get_children():
			if m is MultiMeshInstance3D:
				if not m.has_meta("vr0"):
					m.set_meta("vr0", m.visibility_range_end)
				m.visibility_range_end = float(m.get_meta("vr0")) * float(vk[q])
		if tr.water_mat != null:
			tr.water_mat.set_shader_parameter("detail", q)
