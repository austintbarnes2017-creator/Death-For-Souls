extends Control

@onready var character_slots = $VBoxContainer/CharacterSlots
@onready var admin_button = $VBoxContainer/AdminButton
@onready var quit_button = $VBoxContainer/QuitButton

const MAX_CHARACTER_SLOTS = 3
const SAVE_FILE_PATH = "user://characters.json"

var character_data = {}

func _ready():
	load_character_data()
	update_character_slots()
	
	# Connect button signals
	for i in range(MAX_CHARACTER_SLOTS):
		var slot_button = character_slots.get_child(i)
		slot_button.pressed.connect(_on_character_slot_pressed.bind(i))
	
	admin_button.pressed.connect(_on_admin_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func load_character_data():
	if FileAccess.file_exists(SAVE_FILE_PATH):
		var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var parse_result = json.parse(json_string)
			
			if parse_result == OK:
				character_data = json.data
			else:
				print("Error parsing character data")

func save_character_data():
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(character_data)
		file.store_string(json_string)
		file.close()

func update_character_slots():
	for i in range(MAX_CHARACTER_SLOTS):
		var slot_button = character_slots.get_child(i)
		var slot_key = "slot_" + str(i + 1)
		
		if slot_key in character_data and character_data[slot_key]:
			var char_info = character_data[slot_key]
			slot_button.text = "Character %d: %s (%s)" % [i + 1, char_info.name, char_info.gender.capitalize()]
		else:
			slot_button.text = "Character Slot %d - Empty" % (i + 1)

func _on_character_slot_pressed(slot_index: int):
	var slot_key = "slot_" + str(slot_index + 1)
	
	if slot_key in character_data and character_data[slot_key]:
		# Load existing character
		load_character(slot_index)
	else:
		# Create new character
		open_character_creation(slot_index)

func load_character(slot_index: int):
	var slot_key = "slot_" + str(slot_index + 1)
	var char_info = character_data[slot_key]
	
	# Store character data for the game scene to load
	# This will be loaded by the player controller when the scene starts
	var character_file = FileAccess.open("user://current_character.json", FileAccess.WRITE)
	if character_file:
		var json_string = JSON.stringify(char_info)
		character_file.store_string(json_string)
		character_file.close()
	
	# Change to game scene
	get_tree().change_scene_to_file("res://demo_level/world_castle.tscn")

func open_character_creation(slot_index: int):
	# Load character creation scene
	var creation_scene = preload("res://ui/character_creation.tscn").instantiate()
	creation_scene.slot_index = slot_index
	creation_scene.character_created.connect(_on_character_created)
	
	add_child(creation_scene)
	visible = false

func _on_character_created(slot_index: int, character_info: Dictionary):
	var slot_key = "slot_" + str(slot_index + 1)
	character_data[slot_key] = character_info
	save_character_data()
	update_character_slots()
	visible = true

func _on_admin_pressed():
	var admin_panel = preload("res://ui/admin_panel.tscn").instantiate()
	add_child(admin_panel)
	visible = false

func _on_quit_pressed():
	get_tree().quit()
