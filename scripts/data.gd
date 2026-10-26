extends Node
## بيانات اللعبة: الجيوش والوحدات والمنشآت والأنماط. عدّل الأرقام هنا لتغيير التوازن.

const VERSION := "1.0.2"
const MAP := 256         # عدد الخلايا في كل ضلع (256 = خريطة خفيفة وسلسة على الهاتف)
const K := 1.0           # نسبة التكبير مقارنة بالخريطة الأساسية (MAP / 256)
const CELL := 2.0        # طول الخلية بالمتر
const MINE_GOLD := 5000.0    # كمية الذهب في كل منجم
const TRUCK_LOAD := 300.0    # حمولة الشاحنة في الرحلة الواحدة
var BASES: Array = []        # أربع قواعد: 0 أسفل اليسار، 1 أعلى اليسار، 2 أعلى اليمين، 3 أسفل اليمين
var MINES: Array = []


func _ready() -> void:
	for p in [Vector2(36, 212), Vector2(36, 44), Vector2(217, 41), Vector2(217, 212)]:
		BASES.append(Vector2i(roundi(p.x * K), roundi(p.y * K)))
	var quad := [Vector2i(46, 196), Vector2i(34, 172), Vector2i(62, 226), Vector2i(74, 200), Vector2i(54, 150), Vector2i(88, 178), Vector2i(30, 140)]
	for q in quad:
		var x: int = roundi(q.x * K)
		var y: int = roundi(q.y * K)
		var mx: int = MAP - 2 - x
		var my: int = MAP - 2 - y
		MINES.append(Vector2i(x, y))
		MINES.append(Vector2i(x, my))
		MINES.append(Vector2i(mx, y))
		MINES.append(Vector2i(mx, my))


# جيوش بأسماء مهيبة. لون كل جيش يظهر على الأعلام والأسقف والأشرطة.
var ARMIES := {
	"red": {"name": "فيلق اللهيب القرمزي", "short": "اللهيب", "color": Color.html("d92b2b"), "desc": "+10٪ صحة لكل الوحدات", "hp": 1.1},
	"blue": {"name": "حرس العاصفة الزرقاء", "short": "العاصفة", "color": Color.html("2b6cde"), "desc": "+15٪ دخل الذهب", "inc": 1.15},
	"yellow": {"name": "جحافل الشمس الذهبية", "short": "الشمس", "color": Color.html("f2c21a"), "desc": "+10٪ ضرر لكل الوحدات", "dmg": 1.1},
	"white": {"name": "حرس الثلج الملكي", "short": "الثلج", "color": Color.html("f4f4f0"), "desc": "+400 ذهب عند البداية", "gold": 400},
}

# أنماط اللعب. players: خانات القواعد المشاركة، teams: رقم الفريق لكل خانة (-1 غير مشاركة)
var MODES := {
	"1v1": {"name": "1 ضد 1", "desc": "مواجهة مباشرة مع جيش واحد", "players": [0, 2], "teams": [0, -1, 1, -1], "boost": 1.0},
	"2v2": {"name": "2 ضد 2", "desc": "أنت وحليف يقوده الحاسوب ضد جيشين متحالفين", "players": [0, 1, 2, 3], "teams": [0, 0, 1, 1], "boost": 1.0},
	"1v2": {"name": "1 ضد 2", "desc": "وحدك ضد جيشين متحالفين. تحدٍّ صعب", "players": [0, 2, 3], "teams": [0, -1, 1, 1], "boost": 1.0},
	"2v1": {"name": "2 ضد 1", "desc": "أنت وحليفك ضد جيش واحد أقوى", "players": [0, 1, 2], "teams": [0, 0, 1, -1], "boost": 1.3},
}

# ثلاثة مستويات حقيقية. every: ثواني بين قرارات التدريب، wave: حجم الموجة، gm: مضاعف دخل العدو
# bt: ثواني بين قرارات البناء، hp/dmg: مضاعف صحة وضرر العدو، first: أقل وقت (ثانية) قبل أول هجوم
# air: هل يستخدم الطيران، trucks: عدد شاحنات الذهب، depots: عدد مقرات الذهب، tech: مستوى الوحدات المتقدمة 0..2
var DIFF := {
	"easy": {"name": "سهل", "desc": "عدو بطيء ومتأخر الهجوم", "every": 24.0, "wave": 4, "gm": 0.55, "bt": 50.0, "hp": 0.75, "dmg": 0.65, "first": 360.0, "air": false, "trucks": 2, "depots": 1, "tech": 0},
	"normal": {"name": "متوسط", "desc": "عدو متوازن يتوسع ويهاجم بموجات", "every": 13.0, "wave": 7, "gm": 0.9, "bt": 30.0, "hp": 1.0, "dmg": 0.95, "first": 200.0, "air": false, "trucks": 3, "depots": 2, "tech": 1},
	"hard": {"name": "صعب", "desc": "عدو سريع بدبابات ثقيلة وطيران", "every": 7.0, "wave": 10, "gm": 1.25, "bt": 18.0, "hp": 1.1, "dmg": 1.05, "first": 120.0, "air": true, "trucks": 5, "depots": 3, "tech": 2},
}

# المسافات (range, vis) بوحدة الخلايا، والسرعة بخلية/ثانية.
# cls: فئة الوحدة (inf مشاة، veh آلية، air طيران). vs: مضاعف الضرر على كل فئة هدف (bld مبنى)
var UNITS := {
	"inf": {"name": "مشاة", "cls": "inf", "hp": 70.0, "speed": 2.4, "range": 4.5, "dmg": 9.0, "cd": 0.7, "cost": 100, "time": 4.0, "vis": 7.0, "air": false, "noair": false, "radius": 0.8, "vs": {"inf": 1.0, "veh": 0.45, "air": 0.4, "bld": 0.5}},
	"rpg": {"name": "قاذف صواريخ", "cls": "inf", "hp": 80.0, "speed": 2.1, "range": 6.0, "dmg": 38.0, "cd": 2.2, "cost": 200, "time": 6.0, "vis": 7.0, "air": false, "noair": true, "radius": 0.8, "vs": {"inf": 0.5, "veh": 1.7, "air": 0.0, "bld": 1.1}},
	"sniper": {"name": "قناص", "cls": "inf", "hp": 55.0, "speed": 2.2, "range": 11.0, "dmg": 55.0, "cd": 3.0, "cost": 250, "time": 7.0, "vis": 10.0, "air": false, "noair": true, "radius": 0.8, "vs": {"inf": 1.5, "veh": 0.15, "air": 0.0, "bld": 0.1}},
	"lt": {"name": "مدرعة خفيفة", "cls": "veh", "hp": 170.0, "speed": 3.2, "range": 5.5, "dmg": 16.0, "cd": 0.9, "cost": 220, "time": 6.0, "vis": 8.0, "air": false, "noair": false, "radius": 1.8, "vs": {"inf": 1.3, "veh": 0.7, "air": 0.5, "bld": 0.6}},
	"tank": {"name": "دبابة", "cls": "veh", "hp": 260.0, "speed": 1.9, "range": 6.5, "dmg": 30.0, "cd": 1.5, "cost": 350, "time": 8.0, "vis": 8.0, "air": false, "noair": true, "radius": 2.2, "vs": {"inf": 0.8, "veh": 1.0, "air": 0.0, "bld": 1.3}},
	"heavy": {"name": "دبابة ثقيلة", "cls": "veh", "hp": 480.0, "speed": 1.4, "range": 7.0, "dmg": 55.0, "cd": 1.9, "cost": 650, "time": 12.0, "vis": 8.0, "air": false, "noair": true, "radius": 2.6, "vs": {"inf": 0.8, "veh": 1.2, "air": 0.0, "bld": 1.5}},
	"art": {"name": "مدفعية", "cls": "veh", "hp": 110.0, "speed": 1.5, "range": 11.0, "dmg": 40.0, "cd": 2.6, "cost": 450, "time": 10.0, "vis": 7.0, "air": false, "noair": true, "radius": 2.2, "vs": {"inf": 1.0, "veh": 0.9, "air": 0.0, "bld": 1.6}},
	"aa": {"name": "مضاد طيران", "cls": "veh", "hp": 150.0, "speed": 2.2, "range": 9.0, "dmg": 12.0, "cd": 0.25, "cost": 400, "time": 8.0, "vis": 9.0, "air": false, "noair": false, "radius": 2.1, "vs": {"inf": 0.3, "veh": 0.2, "air": 2.4, "bld": 0.1}},
	"heli": {"name": "مروحية", "cls": "air", "hp": 150.0, "speed": 3.4, "range": 5.5, "dmg": 14.0, "cd": 0.5, "cost": 500, "time": 10.0, "vis": 9.0, "air": true, "noair": false, "radius": 2.6, "vs": {"inf": 1.2, "veh": 0.9, "air": 0.8, "bld": 0.8}},
	"jet": {"name": "مقاتلة", "cls": "air", "hp": 120.0, "speed": 5.2, "range": 6.0, "dmg": 26.0, "cd": 1.0, "cost": 700, "time": 14.0, "vis": 10.0, "air": true, "noair": false, "radius": 2.2, "vs": {"inf": 0.6, "veh": 1.0, "air": 1.8, "bld": 1.0}},
	"bomber": {"name": "قاذفة", "cls": "air", "hp": 230.0, "speed": 3.6, "range": 2.5, "dmg": 90.0, "cd": 2.8, "cost": 900, "time": 16.0, "vis": 9.0, "air": true, "noair": true, "radius": 3.4, "vs": {"inf": 1.0, "veh": 1.2, "air": 0.0, "bld": 2.2}},
	"truck": {"name": "شاحنة ذهب", "cls": "veh", "hp": 180.0, "speed": 3.0, "range": 0.0, "dmg": 0.0, "cd": 99.0, "cost": 300, "time": 6.0, "vis": 6.0, "air": false, "noair": true, "radius": 2.1, "vs": {"inf": 0.0, "veh": 0.0, "air": 0.0, "bld": 0.0}},
}

var BUILDINGS := {
	"hq": {"name": "مقر القيادة", "size": 3, "hp": 1600.0, "vis": 10.0, "cost": 0, "bt": 1.0, "train": []},
	"dep": {"name": "مقر تجميع الذهب", "size": 3, "hp": 1100.0, "vis": 8.0, "cost": 600, "bt": 10.0, "train": ["truck"]},
	"bar": {"name": "ثكنة", "size": 2, "hp": 700.0, "vis": 7.0, "cost": 300, "bt": 8.0, "train": ["inf", "rpg", "sniper"]},
	"fac": {"name": "مصنع دبابات", "size": 3, "hp": 950.0, "vis": 7.0, "cost": 600, "bt": 12.0, "train": ["lt", "tank", "heavy", "art", "aa"]},
	"air": {"name": "مطار", "size": 3, "hp": 900.0, "vis": 8.0, "cost": 800, "bt": 14.0, "train": ["heli", "jet", "bomber"]},
	"twr": {"name": "برج دفاع", "size": 1, "hp": 520.0, "vis": 8.0, "cost": 250, "bt": 6.0, "train": [], "range": 7.5, "dmg": 15.0, "cd": 0.9},
}
