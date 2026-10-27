class_name ModelsEx
extends RefCounted
## نماذج الجنديين الجديدين (الرشّاش والكوماندوز) فوق جندي المشاة الأساسي. باقي الوحدات تُسلَّم لـ Models.

static var _tpl := {}


static func unit_model(type: String, team_col: Color) -> Node3D:
	if type != "mg" and type != "cmd":
		return Models.unit_model(type, team_col)
	var key: String = type + ":" + team_col.to_html(false)
	if not _tpl.has(key):
		_tpl[key] = _build(type, team_col)
	var tpl: Node3D = _tpl[key]
	return tpl.duplicate() as Node3D


static func _build(type: String, team_col: Color) -> Node3D:
	var root := Node3D.new()
	Models._infantry(root, team_col, "inf")
	var steel := Color(0.14, 0.14, 0.15)
	if type == "mg":
		# رشاش ثقيل بماسورة سميكة وحامل ثنائي وصندوق ذخيرة وسير رصاص
		Models.limb(root, Vector3(0.1, 1.22, 0.85), Vector3(0.1, 1.22, 1.3), 0.04, 0.034, steel, 0.4, 0.4)
		Models.box(root, Vector3(0.1, 0.1, 0.34), Vector3(0.1, 1.28, 0.55), steel, 0.5, 0.3)
		Models.limb(root, Vector3(0.1, 1.2, 1.0), Vector3(0.0, 0.82, 1.22), 0.012, 0.012, steel, 0.5)
		Models.limb(root, Vector3(0.1, 1.2, 1.0), Vector3(0.2, 0.82, 1.22), 0.012, 0.012, steel, 0.5)
		Models.box(root, Vector3(0.16, 0.2, 0.26), Vector3(0.27, 1.1, 0.3), Models.OLIVE, 0.8)
		for k in range(5):
			Models.box(root, Vector3(0.05, 0.05, 0.05), Vector3(0.2, 1.17 - k * 0.025, 0.28 + k * 0.03), Models.GOLD, 0.4, 0.5)
		Models.box(root, Vector3(0.3, 0.06, 0.2), Vector3(0, 1.8, 0.0), Models.OLIVE.darkened(0.2), 0.9)
	else:
		# كوماندوز: قناع أسود، سترة داكنة، كاتم صوت، وشارة بلون الجيش على الكتف
		var dark := Color(0.09, 0.09, 0.1)
		Models.sph(root, 0.13, Vector3(0, 1.71, 0.01), dark, Vector3(0.95, 1.1, 1.05), 0.9)
		Models.box(root, Vector3(0.15, 0.03, 0.03), Vector3(0, 1.735, 0.125), Color(0.74, 0.55, 0.42), 0.9)
		Models.box(root, Vector3(0.53, 0.44, 0.3), Vector3(0, 1.33, 0.02), dark, 0.88)
		Models.cyl(root, 0.03, 0.03, 0.32, Vector3(0.1, 1.23, 1.08), Models.DARK, 0.5, 0.2, Vector3(PI / 2.0, 0, 0))
		Models.box(root, Vector3(0.12, 0.05, 0.06), Vector3(-0.22, 1.58, 0.0), team_col, 0.7)
		Models.box(root, Vector3(0.12, 0.05, 0.06), Vector3(0.22, 1.58, 0.0), team_col, 0.7)
	root.scale = Vector3(1.1, 1.1, 1.1)
	Models._bake(root)
	return root
