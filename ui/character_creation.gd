extends Control

signal character_created(slot_index: int, character_info: Dictionary)

@onready var name_input = $Panel/VBoxContainer/NameInput
@onready var male_button = $Panel/VBoxContainer/GenderContainer/MaleButton
@onready var female_button = $Panel/VBoxContainer/GenderContainer/FemaleButton
@onready var create_button = $Panel/VBoxContainer/ButtonContainer/CreateButton
@onready var cancel_button = $Panel/VBoxContainer/ButtonContainer/CancelButton

var slot_index: int = 0
var selected_gender: String = ""

func _ready():
	male_button.pressed.connect(_on_male_selected)
	female_button.pressed.connect(_on_female_selected)
	create_button.pressed.connect(_on_create_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	
	# Initially disable create button
	create_button.disabled = true

func _on_male_selected():
	selected_gender = "male"
	male_button.disabled = true
	female_button.disabled = false
	update_create_button()

func _on_female_selected():
	selected_gender = "female"
	female_button.disabled = true
	male_button.disabled = false
	update_create_button()

func update_create_button():
	var name_valid = name_input.text.strip_edges() != ""
	var gender_selected = selected_gender != ""
	create_button.disabled = !(name_valid and gender_selected)

func _on_create_pressed():
	var character_name = name_input.text.strip_edges()
	
	if character_name == "" or selected_gender == "":
		return
	
	var character_info = {
		"name": character_name,
		"gender": selected_gender,
		"level": 1,
		"health": 100,
		"max_health": 100,
		"weapons": ["axe"],
		"material_path": "res://assets/characters/skin_" + selected_gender[0] + ".tres",
		"created_time": Time.get_unix_time_from_system()
	}
	
	character_created.emit(slot_index, character_info)
	queue_free()

func _on_cancel_pressed():
	queue_free()

func _on_name_input_text_changed(_new_text: String):
	update_create_button()
