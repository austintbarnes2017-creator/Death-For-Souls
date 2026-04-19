extends Control

signal back_to_main_menu()

const MAX_CHARACTER_SLOTS = 3
const SAVE_FILE_PATH = "user://characters.json"

@onready var character_grid = $CharacterGrid
@onready var back_button = $BackButton

var character_data = {}

func _ready():
	load_character_data()
	update_character_slots()
	
	# Connect button signals
	for i in range(MAX_CHARACTER_SLOTS):
		var slot_button = character_grid.get_child(i)
		slot_button.pressed.connect(_on_character_slot_pressed.bind(i))
	
	back_button.pressed.connect(_on_back_pressed)

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
		var slot_button = character_grid.get_child(i)
		var slot_key = "slot_" + str(i + 1)
		
		if slot_key in character_data and character_data[slot_key]:
			# Show existing character info
			var char_info = character_data[slot_key]
			slot_button.text = "SLOT " + str(i + 1) + "\n" + char_info.name + "\nLv. " + str(char_info.level)
		else:
			# Show empty slot
			slot_button.text = "SLOT " + str(i + 1) + "\nNEW CHARACTER"

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
	var character_file = FileAccess.open("user://current_character.json", FileAccess.WRITE)
	if character_file:
		var json_string = JSON.stringify(char_info)
		character_file.store_string(json_string)
		character_file.close()
	
	# Change to game scene
	get_tree().change_scene_to_file("res://demo_level/world_castle.tscn")

func open_character_creation(slot_index: int):
	print("Opening character creation for slot: ", slot_index)
	
	# Load character creation scene
	var creation_scene = preload("res://ui/character_creation.tscn").instantiate()
	if creation_scene:
		creation_scene.slot_index = slot_index
		creation_scene.character_created.connect(_on_character_created)
		
		# Add as child and ensure it's on top
		get_tree().current_scene.add_child(creation_scene)
		creation_scene.visible = true
	else:
		print("ERROR: Failed to instantiate character creation scene!")

func _on_character_created(slot_index: int, character_info: Dictionary):
	var slot_key = "slot_" + str(slot_index + 1)
	character_data[slot_key] = character_info
	save_character_data()
	update_character_slots()
	
	# Store character data for game scene to load
	var character_file = FileAccess.open("user://current_character.json", FileAccess.WRITE)
	if character_file:
		var json_string = JSON.stringify(character_info)
		character_file.store_string(json_string)
		character_file.close()
	
	# Load the character into the game world
	load_character(slot_index)

func _on_back_pressed():
	back_to_main_menu.emit()
	queue_free()
