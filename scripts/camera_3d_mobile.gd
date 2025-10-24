extends Camera3D

signal country_selected(UV: Vector2)
signal world_clicked
signal distance_changed(distance: float, delta: float)

@export var min_FOV := 30.0
@export var max_FOV := 90.0

@export var select_time := 0.25

@export var drag_speed := 1.0
@export var drag_zoom_power := 2.0
#@export var zoom_speed := 1.0
@export var cam_distance := 2.0
@export var cam_distance_tick := 0.01
@export var min_distance := 0.55
@export var max_distance := 2.0

@export var animation_speed := 2.0
@export var latitude_offset := 0.0

@onready var raycast: RayCast3D = %RayCast3D

var panning := false
var zooming := false

var latitude := 0.0
var longitude := PI

var mouse_drag := false
var drag_damp := 250.0

var animating := false
var animate_start: Vector3
var animate_target: Vector3
var animation_progress: float

var _dragging_time := 0.0
var _pick_waiting := false
var _pick_UV: Vector2
var _offset_latitude: float

func animate_to(point: Vector3) -> void:
	animating = true
	animate_start = position
	animate_target = point
	var lat_long := Utilities.latlong_from_point(animate_target)
	_offset_latitude = lat_long.x
	latitude = lat_long.x - latitude_offset
	longitude = lat_long.y

func update_position(lat: float, long: float) -> void:
	latitude = clamp(lat, -PI/2.01, PI/2.01)
	_offset_latitude = clamp(lat + latitude_offset, -PI/2.01, PI/2.01)
	longitude = long
	var look_position := Utilities.latlong_to_point(_offset_latitude, longitude)
	look_at_from_position(look_position * cam_distance, Vector3.ZERO)

func update_cam_distance(distance: float) -> void:
	cam_distance = distance
	var look_position := Utilities.latlong_to_point(_offset_latitude, longitude)
	look_at_from_position(look_position * cam_distance, Vector3.ZERO)

func _ready() -> void:
	update_position(latitude, longitude)

func _unhandled_input(event: InputEvent) -> void:
	if animating: return
	var distance_range_size := max_distance - min_distance;
	if event is InputEventMagnifyGesture:
		var previous_distance := cam_distance
		update_cam_distance(clampf(cam_distance / event.factor, min_distance, max_distance))
		var progress := (cam_distance - min_distance) / distance_range_size
		fov = lerpf(min_FOV, max_FOV, progress)
		distance_changed.emit(cam_distance, cam_distance - previous_distance)
	if event is InputEventPanGesture:
		pan_camera(event.delta)
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					_dragging_time = 0.0
					mouse_drag = true
					var projected: Vector3 = project_position(event.position, cam_distance)
					raycast.target_position = raycast.to_local(projected)
					_pick_waiting = true
				else: ## we select on mouse release
					mouse_drag = false
					if _dragging_time < select_time:
						country_selected.emit(_pick_UV)
						world_clicked.emit()
			MOUSE_BUTTON_WHEEL_UP:
				update_cam_distance(clampf(cam_distance - cam_distance_tick, min_distance, max_distance))
				var progress := (cam_distance - min_distance) / distance_range_size
				fov = lerpf(min_FOV, max_FOV, progress)
				distance_changed.emit(cam_distance, -cam_distance_tick)
			MOUSE_BUTTON_WHEEL_DOWN:
				update_cam_distance(clampf(cam_distance + cam_distance_tick, min_distance, max_distance))
				var progress := (cam_distance - min_distance) / distance_range_size
				fov = lerpf(min_FOV, max_FOV, progress)
				distance_changed.emit(cam_distance, cam_distance_tick)
	if event is InputEventMouseMotion:
		if mouse_drag:
			pan_camera(event.relative)

func pan_camera(delta: Vector2) -> void:
	var screenx: float = delta.x / drag_damp
	var screeny: float = delta.y / drag_damp
	var zoomed_speed := drag_speed * pow(cam_distance / max_distance, drag_zoom_power)
	update_position(latitude-(screeny*zoomed_speed), longitude - (screenx*zoomed_speed))

static func sphere_point_to_UV(point: Vector3) -> Vector2:
	var u := (-atan2(point.x, -point.z) + PI) / (2.0 * PI)
	var v := (-asin(point.y) + PI / 2.0) / PI
	return Vector2(u, v)

func _physics_process(delta: float) -> void:
	if animating:
		animation_progress += delta * animation_speed
		var look_position := animate_start.slerp(animate_target * cam_distance, animation_progress)
		look_at_from_position(look_position, Vector3.ZERO)
		if animation_progress >= 1.0:
			animation_progress = 0.0
			animating = false
	if _pick_waiting:
		raycast.force_raycast_update()
		if raycast.is_colliding():
			var sphere_point := raycast.get_collision_point().normalized()
			_pick_UV = sphere_point_to_UV(sphere_point)
		_pick_waiting = false
	if mouse_drag:
		_dragging_time += delta
