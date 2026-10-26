class_name RtsCamera
extends Node3D
## كاميرا استراتيجية: سحب للتحريك، قرص للتقريب، تدوير بإصبعين

var cam: Camera3D
var focus := Vector3(80, 0, 80)
var yaw := 0.0
var dist := 36.0
var pitch := deg_to_rad(56.0)
var limit: float = Data.MAP * Data.CELL


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 55.0
	cam.near = 0.5
	cam.far = 700.0
	add_child(cam)
	cam.current = true
	apply()


func apply() -> void:
	focus.x = clampf(focus.x, 14.0, limit - 14.0)
	focus.z = clampf(focus.z, 14.0, limit - 14.0)
	dist = clampf(dist, 14.0, 95.0)
	var off := Vector3(0, sin(pitch), cos(pitch)).rotated(Vector3.UP, yaw) * dist
	cam.position = focus + off
	cam.look_at(focus, Vector3.UP)


func pan(delta_px: Vector2) -> void:
	var s: float = dist * 0.0017
	var right := Vector3.RIGHT.rotated(Vector3.UP, yaw)
	var fwd := Vector3(0, 0, -1).rotated(Vector3.UP, yaw)
	focus -= right * delta_px.x * s
	focus += fwd * delta_px.y * s / sin(pitch)
	apply()


func zoom_by(factor: float) -> void:
	dist *= factor
	apply()


func rotate_by(a: float) -> void:
	yaw += a
	apply()
