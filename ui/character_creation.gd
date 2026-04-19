extends Control

signal character_created(slot_index: int, character_info: Dictionary)

@onready var name_input = $Panel/VBoxContainer/NameInput
@onready var male_button = $Panel/VBoxContainer/GenderContainer/MaleButton
@onready var female_button = $Panel/VBoxContainer/GenderContainer/FemaleButton
@onready var create_button = $Panel/VBoxContainer/ButtonContainer/CreateButton
@onready var cancel_button = $Panel/VBoxContainer/ButtonContainer/CancelButton

var slot_index: int = 0
var selected_gender: String = ""
var loading_bar: Control

func _ready():
	print("Character creation _ready() called")
	
	# Ensure the scene is visible and covers the screen
	anchors_preset = Control.PRESET_FULL_RECT  # Full screen
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # Block mouse events
	visible = true
	
	# Force the background to be visible
	var bg = $Background
	if bg:
		bg.visible = true
		bg.color = Color(0.1, 0.1, 0.2, 0.95)
	
	# Force the panel to be visible
	var panel = $Panel
	if panel:
		panel.visible = true
	
	print("Scene anchors set, visible: ", visible)
	
	# Check if nodes are found and ensure all UI elements are visible
	if male_button:
		print("Male button found")
		male_button.visible = true
		male_button.modulate = Color(1, 1, 1, 1)
	else:
		print("ERROR: Male button not found!")
		
	if female_button:
		print("Female button found")
		female_button.visible = true
		female_button.modulate = Color(1, 1, 1, 1)
	else:
		print("ERROR: Female button not found!")
	
	# Ensure all UI elements are visible
	if name_input:
		name_input.visible = true
		name_input.modulate = Color(1, 1, 1, 1)
	
	if create_button:
		create_button.visible = true
		create_button.modulate = Color(1, 1, 1, 1)
	
	if cancel_button:
		cancel_button.visible = true
		cancel_button.modulate = Color(1, 1, 1, 1)
	
	# Ensure labels are visible
	var name_label = $Panel/VBoxContainer/NameLabel
	var gender_label = $Panel/VBoxContainer/GenderLabel
	
	if name_label:
		name_label.visible = true
		name_label.modulate = Color(1, 1, 1, 1)
	
	if gender_label:
		gender_label.visible = true
		gender_label.modulate = Color(1, 1, 1, 1)
	
	male_button.pressed.connect(_on_male_selected)
	female_button.pressed.connect(_on_female_selected)
	create_button.pressed.connect(_on_create_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	name_input.text_changed.connect(_on_name_input_text_changed)
	
	# Initially disable create button
	create_button.disabled = true
	print("Character creation initialized")
	
	# Focus on name input for better UX
	name_input.grab_focus()

func _on_male_selected():
	print("Male button selected")
	selected_gender = "male"
	male_button.disabled = true
	female_button.disabled = false
	update_create_button()
	print("Gender set to: ", selected_gender)

func _on_female_selected():
	print("Female button selected")
	selected_gender = "female"
	female_button.disabled = true
	male_button.disabled = false
	update_create_button()
	print("Gender set to: ", selected_gender)

func update_create_button():
	var name_valid = name_input.text.strip_edges() != ""
	var gender_selected = selected_gender != ""
	create_button.disabled = !(name_valid and gender_selected)

func _on_create_pressed():
	var character_name = name_input.text.strip_edges()
	
	if character_name == "" or selected_gender == "":
		return
	
	# Create and show loading bar
	_create_loading_bar()
	
	# Wait for loading to complete before emitting signal
	if loading_bar:
		loading_bar.loading_complete.connect(_on_loading_complete)
		loading_bar.start_loading()
	else:
		# Fallback if loading bar fails to create
		_on_loading_complete()

func _create_loading_bar():
	var loading_scene = preload("res://ui/character_loading_bar.tscn").instantiate()
	loading_bar = loading_scene
	
	# Add to scene tree
	get_tree().current_scene.add_child(loading_bar)
	
	# Hide character creation UI during loading
	visible = false

func _on_loading_complete():
	# Emit character creation signal
	var character_name = name_input.text.strip_edges()
	
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
	
	# Clean up loading bar
	if loading_bar:
		loading_bar.queue_free()
	
	queue_free()

func _on_cancel_pressed():
	queue_free()

func _on_name_input_text_changed(_new_text: String):
	update_create_button()
