@tool
extends Node3D

enum RENDER_MODE {REALISTIC, UNSHADED, COLORIZED}
const NUM_COLORS := 8

@export var render_mode: RENDER_MODE:
	set = set_render_mode
@export var orbit_speed := 1.0
@export var shaded_material: ShaderMaterial
@export var unshaded_material: ShaderMaterial
@export var sun_light: DirectionalLight3D
@export var country_color_overrides: Dictionary[int, int]


@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var sun_progress: float
var sun_direction: Vector3

func _ready() -> void:
	var country_color_indices: PackedInt32Array = unshaded_material.get_shader_parameter("countryColors")
	for i in range(len(country_color_indices)):
		if i in country_color_overrides:
			country_color_indices[i] = country_color_overrides[i]
		else:
			country_color_indices[i] = i % NUM_COLORS
	unshaded_material.set_shader_parameter("countryColors", country_color_indices)

func _process(delta: float) -> void:
	if render_mode == RENDER_MODE.REALISTIC:
		sun_progress += delta * orbit_speed
		sun_direction = Vector3(sin(sun_progress), 0.0, -cos(sun_progress))
		if shaded_material:
			shaded_material.set_shader_parameter("lightDir", sun_direction)
		if sun_light and not Engine.is_editor_hint():
			sun_light.look_at(sun_direction)

func set_selected_id(ID: int) -> void:
	shaded_material.set_shader_parameter("selectedID", ID);
	unshaded_material.set_shader_parameter("selectedID", ID);

func set_show_solved(toggled_on: bool) -> void:
	shaded_material.set_shader_parameter("bordersStrength", 1.0 if toggled_on else 0.0)
	unshaded_material.set_shader_parameter("bordersStrength", 1.0 if toggled_on else 0.0)

func set_solved_state(solved_combined: Array[bool]) -> void:
	shaded_material.set_shader_parameter("countriesSolved", solved_combined)
	unshaded_material.set_shader_parameter("countriesSolved", solved_combined)

func set_render_mode(mode: RENDER_MODE) -> void:
	if render_mode != mode:
		render_mode = mode
		match render_mode:
			RENDER_MODE.REALISTIC:
				mesh_instance.material_override = shaded_material
			RENDER_MODE.UNSHADED:
				unshaded_material.set_shader_parameter("colorizeStrength", 0.0)
				mesh_instance.material_override = unshaded_material
			RENDER_MODE.COLORIZED:
				unshaded_material.set_shader_parameter("colorizeStrength", 1.0)
				mesh_instance.material_override = unshaded_material
			
