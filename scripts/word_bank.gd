extends Control

@onready var countries: Container = %Countries
@onready var countries_flow: FlowContainer = %CountriesFlow
@onready var countries_title: Label = %CountriesTitle

@onready var capitals: Container = %Capitals
@onready var capitals_flow: FlowContainer = %CapitalsFlow
@onready var capitals_title: Label = %CapitalsTitle

@onready var filter_edit: LineEdit = %FilterEdit
@onready var capitals_check: CheckButton = %CapitalsCheckButton

@export var control_below: Control

var _country_labels: Array[Control]
var _capital_labels: Array[Control]

var _solved_countries: Array[bool]
var _solved_capitals: Array[bool]

var _dragging := false
var _requested_y: float

func _ready() -> void:
	countries.visible = not capitals_check.button_pressed
	capitals.visible = capitals_check.button_pressed
	_requested_y = size.y

func initialize(all_countries: CountryList) -> void:
	#_all_countries = all_countries
	var num_countries := 0
	var num_capitals := 0
	assert(len(_country_labels) == 0)
	countries_flow.get_children().map(countries_flow.remove_child)
	capitals_flow.get_children().map(capitals_flow.remove_child)
	var capital_order := []
	for country in all_countries.countries:
		var country_label := Label.new()
		country_label.text = country.name
		country_label.theme_type_variation = "WordBankLabel"
		countries_flow.add_child(country_label)
		_country_labels.append(country_label)
		num_countries += 1
		
		if country.capital:
			var capital_label := Label.new()
			capital_label.text = country.capital
			capital_label.theme_type_variation = "WordBankLabel"
			capital_order.append(capital_label)
			_capital_labels.append(capital_label)
			num_capitals += 1
		else:
			_capital_labels.append(null)
		_solved_countries.resize(num_countries)
		_solved_capitals.resize(num_countries)
	capital_order.shuffle()
	for capital_label in capital_order:
		capitals_flow.add_child(capital_label)
	
	countries_title.text = "Countries: %d" % num_countries
	capitals_title.text = "Capitals: %d" % num_capitals

func update_solved(solved_countries: Array[bool], solved_capitals: Array[bool]) -> void:
	_solved_countries = solved_countries
	_solved_capitals = solved_capitals
	_refresh_visible(filter_edit.text)
	countries_title.text = "Countries: %d" % solved_countries.count(false)
	capitals_title.text = "Capitals: %d" % solved_capitals.count(false)

func _refresh_visible(filter_text := "") -> void:
	for i in range(len(_country_labels)):
		var label := _country_labels[i]
		label.visible = (label.text.containsn(filter_text) or not filter_text) and not _solved_countries[i]
	for i in range(len(_capital_labels)):
		var label := _capital_labels[i]
		if label:
			label.visible = (label.text.containsn(filter_text) or not filter_text) and not _solved_capitals[i]

func _on_capitals_toggled(toggled_on: bool) -> void:
	capitals.visible = toggled_on
	countries.visible = not toggled_on
	size.y = _requested_y ## TODO: doesn't work!! ineffective!!

func _on_grabber_gui_input(event: InputEvent) -> void:
	var max_y := (control_below.global_position.y if control_below else get_viewport_rect().size.y) - global_position.y
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
	if event is InputEventMouseMotion and _dragging:
		_requested_y = min(max_y, size.y + event.relative.y)
		size.y = _requested_y
	if event is InputEventPanGesture:
		_requested_y = min(max_y, size.y + event.delta.y)
		size.y = _requested_y

func _on_filter_edit_text_changed(new_text: String) -> void:
	_refresh_visible(new_text)
