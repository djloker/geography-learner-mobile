extends Node

@export var label_distance := 0.55
@export var label_hide_threshold := 0.7
@export var label_code_threshold := 1.4
@export var country_ids: Texture2D
@export var country_list: CountryList

@export var vkey_tilt_damp := 4.0

@onready var planet_3d: Node3D = %Planet3D
@onready var camera: Camera3D = %Camera3D

@onready var country_input_dialog: Control = %CountryInputDialog
@onready var show_solved_button: BaseButton = %ShowSolvedButton

@onready var settings: Control = %Settings
@onready var settings_button: BaseButton = %SettingsButton
@onready var word_bank: Control = %WordBank
@onready var word_bank_button: BaseButton = %WordBankButton

@onready var planet_labels: Node3D = %PlanetLabels
@onready var show_labels_button: BaseButton = %ShowLabelsButton

@onready var sfx_button: BaseButton = %SFXButton
@onready var solve_sound_player: AudioStreamPlayer = %SolveSoundPlayer
@onready var mute_music_button: TextureButton = %MuteMusicButton
@onready var music_player: AudioStreamPlayer = %MusicPlayer


@onready var has_v_key := DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD)
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
	config.set_value("sound", "sfx_muted", sfx_button.button_pressed)
	config.set_value("sound", "music_muted", mute_music_button.button_pressed)
	
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
		sfx_button.button_pressed = config.get_value("sound", "sfx_muted", false)
		mute_music_button.button_pressed = config.get_value("sound", "music_muted", true)
		settings.set_render_mode_silent(render_mode)
		planet_3d.set_render_mode(render_mode)

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

func select(id: int, force_focus := true) -> void:
	if selected_id != id:
		selected_id = id
		planet_3d.set_selected_id(id)
		_refresh_input()
	if force_focus:
		country_input_dialog.focus_unsolved()

func snap_camera_to(id: int) -> void:
	var country := country_list.countries[id]
	var rad_coord := Utilities.raw_latlong_to_radians(Vector2(country.centroid.x, country.centroid.y))
	var point := Utilities.latlong_to_point(rad_coord.x + camera.latitude_offset, rad_coord.y)
	camera.animate_to(point)

func _ready() -> void:
	planet_labels.visible = show_labels_button.button_pressed
	planet_3d.set_show_solved(show_solved_button.button_pressed)
	
	solved_countries.resize(country_list.size)
	solved_capitals.resize(country_list.size)
	
	country_input_dialog.lineedit_gui_input.connect(_on_lineedit_gui_input)
	country_input_dialog.request_vkey_text.connect(_refresh_vkey_text)
	
	settings.visible = settings_button.button_pressed
	
	word_bank.initialize(country_list)
	word_bank.visible = word_bank_button.button_pressed
	
	_initialize_labels()
	
	load_settings()
	load_state()
	
	for i in range(country_list.size):
		if country_list.countries[i].capital == "":
			solved_capitals[i] = true
	
	if not mute_music_button.button_pressed:
		music_player.play()

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

func _process(_delta: float) -> void:
	if Engine.is_editor_hint(): return
	## https://stackoverflow.com/questions/78633119/how-to-make-virtual-keyboard-show-all-the-time-in-godot-4
	# Without doing all the work my idea would be to make a node, which handles if the virtual keyboard is shown.
	# (Let's call it KeyboardHandler) On ready it looks for every node in the scene that needs a keyboard by iterating
	# the nodes and checking for 'virtual_keyboard_enabled'. It then sets this property to false to make sure only the
	# handler itself triggers the keyboard. Then it conntects a signal to these nodes (e.g focus_entered) to activate
	# the keyboard if it is not visible:
	if has_v_key:
		%VirtualKeyboardSpacer.custom_minimum_size.y = DisplayServer.virtual_keyboard_get_height()
		camera.latitude_offset = (float(DisplayServer.virtual_keyboard_get_height()) / float(get_window().size.y) * camera.cam_distance) / vkey_tilt_damp
		camera.update_position(camera.latitude, camera.longitude)

func _centroid_to_point(country: CountryResource) -> Vector3:
	var rad_coord := Utilities.raw_latlong_to_radians(Vector2(country.centroid.x, country.centroid.y))
	return Utilities.latlong_to_point(rad_coord.x, rad_coord.y) * label_distance

func _initialize_labels() -> void:
	planet_labels.get_children().map(planet_labels.remove_child)
	for i in range(country_list.size):
		var country := country_list.countries[i]
		
		var label := Label3D.new()
		label.text = country.code if camera.cam_distance > label_code_threshold else country.name
		label.position = _centroid_to_point(country)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.set_draw_flag(Label3D.FLAG_FIXED_SIZE, true)
		label.pixel_size = 0.001
		label.hide()
		label.set_meta("country", country)
		planet_labels.add_child(label)

## Virtual Keyboard controller
func _is_vkey_open() -> bool:
	return has_v_key and DisplayServer.virtual_keyboard_get_height() > 0

func _refresh_vkey_text(text: String, force_open := false) -> void:
	if has_v_key and (_is_vkey_open() or force_open):
		DisplayServer.virtual_keyboard_show(text)

func _on_lineedit_gui_input(event: InputEvent, input: LineEdit) -> void:
	if not input.editable: return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_refresh_vkey_text(input.text, true)
			#accept_event()

func _on_lineedit_focus_entered(input: LineEdit) -> void:
	if input.editable:
		_refresh_vkey_text(input.text)

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
	if _is_vkey_open():
		country_input_dialog.focus_unsolved()

func _on_camera_3d_world_clicked() -> void:
	pass #country_input_dialog.drop_focus()

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
	if was_code != is_code:
		for child in planet_labels.get_children():
			var country: CountryResource = child.get_meta("country")
			child.text = country.code if is_code else country.name

func _on_country_input_dialog_solved_country(ID: int, player_solved: bool) -> void:
	solved_countries[ID] = true
	if player_solved:
		if not sfx_button.button_pressed:
			solve_sound_player.play()
	_refresh_solved()
	## TODO: reveal Label3D with country code/name

func _on_country_input_dialog_solved_capital(ID: int, player_solved: bool) -> void:
	solved_capitals[ID] = true
	if player_solved:
		if not sfx_button.button_pressed:
			solve_sound_player.play()
	_refresh_solved()

func _on_input_request_goto() -> void:
	snap_camera_to(selected_id)

func _on_input_request_previous() -> void:
	var num_countries: int = country_list.size
	for offset in range(1, num_countries):
		var i := wrapi(selected_id-offset, 0, num_countries)
		if not _is_totally_solved(i):
			select(i, false)
			snap_camera_to(i)
			break

func _on_input_request_next() -> void:
	var num_countries: int = country_list.size
	for offset in range(1, num_countries):
		var i := wrapi(selected_id+offset, 0, num_countries)
		if not _is_totally_solved(i):
			select(i, false)
			snap_camera_to(i)
			break

func _on_mute_music_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		music_player.stop()
	else:
		music_player.play()

func _on_request_near() -> void:
	var min_dist_id := -1
	var min_dist: float = INF
	var current_centroid := country_list.countries[selected_id].centroid
	for i in range(country_list.size):
		if i == selected_id: continue
		elif _is_totally_solved(i): continue
		else:
			var i_centroid := country_list.countries[i].centroid
			var distance := current_centroid.distance_squared_to(i_centroid)
			if distance < min_dist:
				min_dist = distance
				min_dist_id = i
	if min_dist_id > 0:
		select(min_dist_id, false)
		snap_camera_to(min_dist_id)

func _on_request_far() -> void:
	var max_dist_id := -1
	var max_dist: float = -INF
	var current_centroid := _centroid_to_point(country_list.countries[selected_id])
	for i in range(country_list.size):
		if i == selected_id: continue
		elif _is_totally_solved(i): continue
		else:
			var i_centroid := _centroid_to_point(country_list.countries[i])
			var distance := current_centroid.distance_squared_to(i_centroid)
			if distance > max_dist:
				max_dist = distance
				max_dist_id = i
	if max_dist_id > 0:
		select(max_dist_id, false)
		snap_camera_to(max_dist_id)
