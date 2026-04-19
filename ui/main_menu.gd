extends Control

@onready var play_button = $MainMenuButtons/PlayButton
@onready var credits_button = $MainMenuButtons/CreditsButton
@onready var death_plus_button = $MainMenuButtons/DeathPlusButton
@onready var admin_button = $AdminButton
@onready var quit_button = $QuitButton
@onready var animated_bg = $Background/AnimatedBackground

const MAX_CHARACTER_SLOTS = 3
const SAVE_FILE_PATH = "user://characters.json"

var character_data = {}

func _ready():
	load_character_data()
	
	# Connect button signals
	play_button.pressed.connect(_on_play_pressed)
	credits_button.pressed.connect(_on_credits_pressed)
	death_plus_button.pressed.connect(_on_death_plus_pressed)
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

func _on_admin_pressed():
	var admin_panel = preload("res://ui/admin_panel.tscn").instantiate()
	add_child(admin_panel)
	# Don't hide main menu - admin panel should be overlay

func _on_play_pressed():
	print("Play button pressed - opening character selection")
	open_character_selection()

func _on_credits_pressed():
	print("Credits button pressed - opening credits screen")
	open_credits_screen()

func _on_death_plus_pressed():
	print("Death Plus button pressed - opening Death Plus screen")
	open_death_plus_screen()

func open_character_selection():
	# Create character selection screen
	var char_selection_scene = preload("res://ui/character_selection.tscn").instantiate()
	if char_selection_scene:
		char_selection_scene.back_to_main_menu.connect(_on_back_to_main_menu)
		add_child(char_selection_scene)
		# Hide main menu
		visible = false

func open_credits_screen():
	# Create credits screen
	var credits_scene = preload("res://ui/credits_screen_fixed.tscn").instantiate()
	if credits_scene:
		add_child(credits_scene)
		# Hide main menu
		visible = false

func open_death_plus_screen():
	# Create Death Plus screen
	var death_plus_scene = preload("res://ui/death_plus_screen.tscn").instantiate()
	if death_plus_scene:
		death_plus_scene.back_to_main_menu.connect(_on_back_to_main_menu)
		add_child(death_plus_scene)
		# Hide main menu
		visible = false

func _on_back_to_main_menu():
	# Show main menu when returning from other screens
	visible = true

func _on_quit_pressed():
	get_tree().quit()
