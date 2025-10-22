extends Control

signal render_mode_changed(render_mode: int)

signal solve_countries_pressed
signal solve_capitals_pressed
signal reset_all_pressed

@export var planet_3d: MeshInstance3D

@onready var render_mode_option: OptionButton = %RenderModeOption
@onready var solve_countries_button: Button = %SolveCountriesButton
@onready var solve_capitals_button: Button = %SolveCapitalButton
@onready var reset_button: Button = %ResetButton

func _ready() -> void:
	render_mode_option.item_selected.connect(render_mode_changed.emit)
	solve_countries_button.pressed.connect(solve_countries_pressed.emit)
	solve_capitals_button.pressed.connect(solve_capitals_pressed.emit)
	reset_button.pressed.connect(reset_all_pressed.emit)

func get_render_mode() -> int:
	return render_mode_option.selected

func set_render_mode_silent(render_mode: int) -> void:
	render_mode_option.select(render_mode)
