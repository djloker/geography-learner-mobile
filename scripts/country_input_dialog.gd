@tool
extends Control

signal solved_country(ID: int, player: bool)
signal solved_capital(ID: int, player: bool)

signal request_goto
signal request_previous
signal request_next

@export var max_width := 200
@export var unsolved_color := Color.RED
@export var solved_color := Color.GREEN
@export var debug_display_ID: bool
#@export var collapsed: bool:
	#set = _set_collapsed

@onready var input_panel: Container = %InputPanel

@onready var buttons_container: HBoxContainer = %ButtonsContainer
@onready var solve_button: BaseButton = %SolveButton
@onready var go_to_button: BaseButton = %GoToButton

@onready var input_grid: GridContainer = %InputGrid

@onready var id_label: Label = %IDLabel
@onready var country_input: LineEdit = %CountryInput
@onready var capital_input: LineEdit = %CapitalInput
@onready var country_color_rect: ColorRect = %SolvedCountryColor
@onready var capital_color_rect: ColorRect = %SolvedCapitalColor

@onready var prev_button: BaseButton = %PrevButton
@onready var next_button: BaseButton = %NextButton

@onready var _has_v_key := DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD)

var current_id: int
var current_country: CountryResource

var _country_is_solved: bool
var _capital_is_solved: bool

func _ready() -> void:
	reset()
	id_label.visible = debug_display_ID
	country_input.focus_entered.connect(_on_input_focus_entered.bind(country_input))
	capital_input.focus_entered.connect(_on_input_focus_entered.bind(capital_input))
	#header_button.icon = texture_collapsed if collapsed else texture_expanded
	go_to_button.pressed.connect(request_goto.emit)
	prev_button.pressed.connect(request_previous.emit)
	next_button.pressed.connect(request_next.emit)
#
func _process(_delta: float) -> void:
	if Engine.is_editor_hint(): return
	## https://stackoverflow.com/questions/78633119/how-to-make-virtual-keyboard-show-all-the-time-in-godot-4
	# Without doing all the work my idea would be to make a node, which handles if the virtual keyboard is shown.
	# (Let's call it KeyboardHandler) On ready it looks for every node in the scene that needs a keyboard by iterating
	# the nodes and checking for 'virtual_keyboard_enabled'. It then sets this property to false to make sure only the
	# handler itself triggers the keyboard. Then it conntects a signal to these nodes (e.g focus_entered) to activate
	# the keyboard if it is not visible:
	if _has_v_key:
		%VirtualKeyboardSpacer.custom_minimum_size.y = DisplayServer.virtual_keyboard_get_height()

func reset() -> void:
	country_input.clear()
	capital_input.clear()
	id_label.text = "NOID"
	country_color_rect.color = unsolved_color
	capital_color_rect.color = unsolved_color
	_country_is_solved = false
	_capital_is_solved = false
	country_input.editable = true
	capital_input.editable = true
	solve_button.disabled = false
	_refresh_vkey_text("")

func load_country(ID: int, country: CountryResource, country_solved: bool, capital_solved: bool) -> void:
	reset()
	current_id = ID
	current_country = country
	if debug_display_ID:
		id_label.text = "ID: %d" % ID
	
	_country_is_solved = country_solved
	_capital_is_solved = capital_solved
	if country_solved: _quiet_solve_country()
	if capital_solved: _quiet_solve_capital()
	
	if country.capital == "": # TODO this shouldn't be necessary
		print_debug("N/A capital, capital_solved: %s" % capital_solved)
		capital_input.text = "N/A"
		capital_input.editable = false
	
	config_solve_button_disabled()
	if _is_vkey_open(): focus_unsolved()

func focus_unsolved() -> void:
	if not _country_is_solved: country_input.grab_focus()
	elif not _capital_is_solved: capital_input.grab_focus()

func drop_focus() -> void:
	country_input.release_focus()
	capital_input.release_focus()

func config_solve_button_disabled() -> void:
	solve_button.disabled = _country_is_solved and _capital_is_solved

func on_player_solved_country() -> void:
	country_color_rect.color = solved_color
	if not _country_is_solved:
		solved_country.emit(current_id, true)
	country_input.editable = false
	_country_is_solved = true
	focus_unsolved()
	config_solve_button_disabled()

func on_player_solved_capital() -> void:
	capital_color_rect.color = solved_color
	if not _capital_is_solved:
		solved_capital.emit(current_id, true)
	capital_input.editable = false
	_capital_is_solved = true
	focus_unsolved()
	config_solve_button_disabled()

func _quiet_solve_country() -> void:
	country_input.text = current_country.name
	country_input.editable = false
	country_color_rect.color = solved_color
	_country_is_solved = true

func _quiet_solve_capital() -> void:
	capital_input.text = current_country.capital if current_country.capital else "N/A"
	capital_input.editable = false
	capital_color_rect.color = solved_color
	_capital_is_solved = true

func _refresh_vkey_text(text: String, force_open := false) -> void:
	if _has_v_key and (_is_vkey_open() or force_open):
		DisplayServer.virtual_keyboard_show(text)

func _is_vkey_open() -> bool:
	return _has_v_key and DisplayServer.virtual_keyboard_get_height() > 0


func _on_country_input_text_changed(new_text: String) -> void:
	if not current_country: return
	for alt_name in [current_country.name] + current_country.alt_names:
		if Utilities.compare_string_nocase_nopunc(new_text, alt_name):
			on_player_solved_country()
			break

func _on_capital_input_text_changed(new_text: String) -> void:
	if not current_country: return
	if Utilities.compare_string_nocase_nopunc(new_text, current_country.capital):
		on_player_solved_capital()

func _on_solve_for_me_button_pressed() -> void:
	if current_country:
		if not _country_is_solved:
			solved_country.emit(current_id, false)
		if not _capital_is_solved:
			solved_capital.emit(current_id, false)
		_quiet_solve_country()
		_quiet_solve_capital()
		config_solve_button_disabled()

func _on_input_focus_entered(input: LineEdit) -> void:
	_refresh_vkey_text(input.text, true)

func _on_country_input_focus_exited() -> void:
	if not capital_input.has_focus() and _has_v_key:
		DisplayServer.virtual_keyboard_hide()

func _on_capital_input_focus_exited() -> void:
	if not country_input.has_focus() and _has_v_key:
		DisplayServer.virtual_keyboard_hide()
