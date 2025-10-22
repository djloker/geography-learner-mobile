extends Node

@export var label_distance := 0.55
@export var label_hide_threshold := 0.7
@export var label_code_threshold := 1.4

@export var camera: Camera3D
@export var raycast: RayCast3D
@onready var solve_sound_player: AudioStreamPlayer = $SolveSoundPlayer

@export var country_ids: Texture2D
@export var country_list: CountryList

@onready var planet_3d: Node3D = $Planet3D
@onready var planet_labels: Node3D = %PlanetLabels


@onready var settings_button: BaseButton = %SettingsButton
@onready var word_bank_button: BaseButton = %WordBankButton

@onready var show_labels_button: BaseButton = %ShowLabelsButton
@onready var show_solved_button: BaseButton = %ShowSolvedButton
@onready var audio_button: BaseButton = %AudioButton

@onready var settings: Control = %Settings
@onready var word_bank: PanelContainer = %WordBank

@onready var country_input_dialog: Control = %CountryInputDialog

var selected_id: int
var solved_countries: Array[bool]
var solved_capitals: Array[bool]

func save_state() -> void:
	var save_file := FileAccess.open("user://solved_state.save", FileAccess.WRITE)
	# JSON provides a static method to serialized JSON string.
	var json_string := JSON.stringify({
		"solved_countries": solved_countries,
		"solved_capitals": solved_capitals
	})
	# Store the save dictionary as a new line in the save file.
	save_file.store_line(json_string)

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("planet", "show_solved", show_solved_button.button_pressed)
	config.set_value("planet", "render_mode", settings.get_render_mode())
	config.set_value("planet", "show_labels", show_labels_button.button_pressed)
	config.set_value("sound", "muted", audio_button.button_pressed)
	
	var error := config.save("user://config.cfg")
	if error != OK:
		%DEV_LABEL.text = "Config save error: %s" % error_string(error)
		printerr("Config save error: %s" % error_string(error))

func load_state() -> void:
	var save_file := FileAccess.open("user://solved_state.save", FileAccess.READ)
	var json_string := save_file.get_line()
	var json := JSON.new()
	if not json.parse(json_string) == OK:
		printerr("JSON Parse Error: %s in %s at line %d" % [json.get_error_message(), json_string, json.get_error_line()])
		return
	solved_countries.assign(json.data["solved_countries"])
	solved_capitals.assign(json.data["solved_capitals"])
	_refresh_solved()

func load_settings() -> void:
	var config := ConfigFile.new()
	var error := config.load("user://config.cfg")
	if error != OK:
		%DEV_LABEL.text = "Config load error: %s" % error_string(error)
		printerr("Config load error: %s" % error_string(error))
	else:
		show_solved_button.button_pressed = config.get_value("planet", "show_solved", false)
		show_labels_button.button_pressed = config.get_value("planet", "show_labels", true)
		var render_mode: int = config.get_value("planet", "render_mode", 0)
		audio_button.button_pressed = config.get_value("sound", "muted", false)
		settings.set_render_mode_silent(render_mode)
		planet_3d.set_render_mode(render_mode)

func _ready() -> void:
	planet_labels.visible = show_labels_button.button_pressed
	planet_3d.set_show_solved(show_solved_button.button_pressed)
	
	solved_countries.resize(country_list.size)
	solved_capitals.resize(country_list.size)
	
	settings.visible = settings_button.button_pressed
	
	word_bank.initialize(country_list)
	word_bank.visible = word_bank_button.button_pressed
	
	_initialize_labels()
	
	load_settings()
	load_state()
	
	for i in range(country_list.size):
		if country_list.countries[i].capital == "":
			solved_capitals[i] = true

func _notification(what):
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			save_settings()
			save_state()
		NOTIFICATION_APPLICATION_PAUSED:
			save_settings()
			save_state()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			## see: Application > Config > Quit On Go Back
			save_settings()
			save_state()

func solve_countries() -> void:
	for i in range(len(solved_countries)):
		solved_countries[i] = true
	_refresh_solved()
	_refresh_input()

func solve_capitals() -> void:
	for i in range(len(solved_capitals)):
		solved_capitals[i] = true
	_refresh_solved()
	_refresh_input()

func reset_solved() -> void:
	for i in range(len(solved_countries)):
		solved_countries[i] = false
	for i in range(len(solved_capitals)):
		solved_capitals[i] = false
	_refresh_solved()
	_refresh_input()

func select(id: int) -> void:
	if id == selected_id:
		country_input_dialog.focus_unsolved()
	else:
		selected_id = id
		planet_3d.set_selected_id(id)
		_refresh_input()

func snap_camera_to(id: int) -> void:
	var country := country_list.countries[id]
	var rad_coord := Utilities.raw_latlong_to_radians(Vector2(country.centroid.x, country.centroid.y))
	var point := Utilities.latlong_to_point(rad_coord.x, rad_coord.y)
	print(country.name, ' ', country.centroid, ' ', rad_coord)
	camera.animate_to(point)

func _initialize_labels() -> void:
	planet_labels.get_children().map(planet_labels.remove_child)
	for i in range(country_list.size):
		var country := country_list.countries[i]
		var rad_coord := Utilities.raw_latlong_to_radians(Vector2(country.centroid.x, country.centroid.y))
		var label := Label3D.new()
		label.text = country.code if camera.cam_distance > label_code_threshold else country.name
		label.position = Utilities.latlong_to_point(rad_coord.x, rad_coord.y) * label_distance
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.set_draw_flag(Label3D.FLAG_FIXED_SIZE, true)
		label.pixel_size = 0.001
		label.hide()
		label.set_meta("country", country)
		planet_labels.add_child(label)

func _is_totally_solved(ID: int) -> bool:
	return solved_countries[ID] and solved_capitals[ID]

func _refresh_solved() -> void:
	var solved_combined: Array[bool]
	solved_combined.resize(len(solved_countries))
	for i in range(0, len(solved_combined)):
		planet_labels.get_child(i).visible = solved_countries[i]
		var solved := _is_totally_solved(i)
		solved_combined[i] = solved
	planet_3d.set_solved_state(solved_combined)
	word_bank.update_solved(solved_countries, solved_capitals)

func _refresh_input() -> void:
	country_input_dialog.load_country(
		selected_id,
		country_list.countries[selected_id],
		solved_countries[selected_id],
		solved_capitals[selected_id]
	)

func _on_camera_3d_world_clicked() -> void:
	country_input_dialog.drop_focus()

func _on_camera_3d_country_selected(UV: Vector2) -> void:
	var ids_image := country_ids.get_image()
	## TODO unsure why width,height -1 here but it was there in the original code...
	var value := ids_image.get_pixel(
		int(UV.x * float(ids_image.get_width())),
		int(UV.y * float(ids_image.get_height()))).r8 - 1
	if value > 0:
		select(value)
	#else:
		#%SelectedLabel.text = "Unselected"

func _on_camera_distance_changed(distance: float, delta: float) -> void:
	planet_labels.visible = show_labels_button.button_pressed and distance > label_hide_threshold
	var was_code := (distance - delta) > label_code_threshold
	var is_code := distance > label_code_threshold
	print(distance)
	if was_code != is_code:
		for child in planet_labels.get_children():
			var country: CountryResource = child.get_meta("country")
			child.text = country.code if is_code else country.name
		

func _on_country_input_dialog_solved_country(ID: int, player_solved: bool) -> void:
	solved_countries[ID] = true
	if player_solved:
		if not audio_button.button_pressed:
			solve_sound_player.play()
	_refresh_solved()
	## TODO: reveal Label3D with country code/name

func _on_country_input_dialog_solved_capital(ID: int, player_solved: bool) -> void:
	solved_capitals[ID] = true
	if player_solved:
		if not audio_button.button_pressed:
			solve_sound_player.play()
	_refresh_solved()

func _on_input_request_goto() -> void:
	snap_camera_to(selected_id)

func _on_input_request_previous() -> void:
	var num_countries: int = country_list.size
	for offset in range(1, num_countries):
		var i := wrapi(selected_id-offset, 0, num_countries)
		if not _is_totally_solved(i):
			select(i)
			snap_camera_to(i)
			break

func _on_input_request_next() -> void:
	var num_countries: int = country_list.size
	for offset in range(1, num_countries):
		var i := wrapi(selected_id+offset, 0, num_countries)
		if not _is_totally_solved(i):
			select(i)
			snap_camera_to(i)
			break
