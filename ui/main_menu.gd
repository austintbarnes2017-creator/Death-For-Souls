extends Control

@onready var main_buttons = $MainMenuButtons
@onready var title_container = $TitleContainer
@onready var play_button = $MainMenuButtons/PlayButton
@onready var credits_button = $MainMenuButtons/CreditsButton
@onready var death_plus_button = $MainMenuButtons/DeathPlusButton
@onready var admin_button = $AdminButton
@onready var quit_button = $QuitButton
@onready var animated_bg = $Background/AnimatedBackground


const MAX_CHARACTER_SLOTS = 3
const SAVE_FILE_PATH = "user://characters.json"

var character_data = {}
var network_panel: PanelContainer
var ip_input: LineEdit
var selected_slot_index: int = -1

func _ready():
	load_character_data()
	
	# Connect button signals
	play_button.pressed.connect(_on_play_pressed)
	credits_button.pressed.connect(_on_credits_pressed)
	death_plus_button.pressed.connect(_on_death_plus_pressed)
	admin_button.pressed.connect(_on_admin_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	_setup_network_ui()

func _setup_network_ui():
	network_panel = PanelContainer.new()
	network_panel.visible = false
	network_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	network_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	network_panel.anchors_preset = Control.PRESET_CENTER
	
	# Professional Styling
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	stylebox.set_border_width_all(2)
	stylebox.border_color = Color(0.3, 0.3, 0.5)
	stylebox.set_corner_radius_all(10)
	stylebox.content_margin_left = 25

	stylebox.content_margin_right = 25
	stylebox.content_margin_top = 25
	stylebox.content_margin_bottom = 25
	network_panel.add_theme_stylebox_override("panel", stylebox)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)

	network_panel.add_child(vbox)
	
	var label = Label.new()
	label.text = "NETWORK SETUP"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	
	# Host IP Info
	var ip_info = Label.new()
	ip_info.text = "Your Local IP: " + NetworkManager.get_local_ip()
	ip_info.modulate = Color(0.6, 0.8, 1.0)
	ip_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(ip_info)
	
	var host_btn = Button.new()
	host_btn.text = "HOST GAME (Server)"
	host_btn.custom_minimum_size = Vector2(250, 40)
	host_btn.pressed.connect(_on_host_pressed)
	vbox.add_child(host_btn)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)
	
	var join_label = Label.new()
	join_label.text = "Join Address:"
	vbox.add_child(join_label)
	
	ip_input = LineEdit.new()
	ip_input.placeholder_text = "127.0.0.1"
	ip_input.text = "127.0.0.1"
	vbox.add_child(ip_input)
	
	var join_btn = Button.new()
	join_btn.text = "JOIN GAME"
	join_btn.custom_minimum_size = Vector2(250, 40)
	join_btn.pressed.connect(_on_join_pressed)
	vbox.add_child(join_btn)
	
	var solo_btn = Button.new()
	solo_btn.text = "SOLO PLAY"
	solo_btn.pressed.connect(_on_solo_pressed)
	vbox.add_child(solo_btn)
	
	var cancel_btn = Button.new()
	cancel_btn.text = "CANCEL"
	cancel_btn.pressed.connect(func(): network_panel.visible = false; visible = true)
	vbox.add_child(cancel_btn)
	
	add_child(network_panel)

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

func _toggle_main_ui(is_visible: bool):
	main_buttons.visible = is_visible
	title_container.visible = is_visible
	quit_button.visible = is_visible
	admin_button.visible = is_visible
	# Background stays visible as a shared backdrop


func _on_play_pressed():
	# Create character selection screen
	var char_selection_scene = preload("res://ui/character_selection.tscn").instantiate()
	if char_selection_scene:
		char_selection_scene.back_to_main_menu.connect(_on_back_to_main_menu)
		# Wrap selection signal to our networking flow
		if char_selection_scene.has_signal("character_selected"):
			char_selection_scene.character_selected.connect(_on_character_chosen)
		add_child(char_selection_scene)
		_toggle_main_ui(false)


func _on_character_chosen(slot_index: int):
	selected_slot_index = slot_index
	# Store character data for the session
	var slot_key = "slot_" + str(slot_index + 1)
	if character_data.has(slot_key):
		var char_info = character_data[slot_key]
		var character_file = FileAccess.open("user://current_character.json", FileAccess.WRITE)
		if character_file:
			character_file.store_string(JSON.stringify(char_info))
			character_file.close()
	
	# Show network options after character is picked
	network_panel.visible = true

func _on_credits_pressed():
	var credits_scene = preload("res://ui/credits_screen_fixed.tscn").instantiate()
	if credits_scene:
		credits_scene.back_to_main_menu.connect(_on_back_to_main_menu)
		add_child(credits_scene)
		_toggle_main_ui(false)



func _on_death_plus_pressed():
	var death_plus_scene = preload("res://ui/death_plus_screen.tscn").instantiate()
	if death_plus_scene:
		death_plus_scene.back_to_main_menu.connect(_on_back_to_main_menu)
		add_child(death_plus_scene)
		_toggle_main_ui(false)


func _on_host_pressed():
	NetworkManager.host_game()
	start_game()

func _on_join_pressed():
	var target_ip = ip_input.text if ip_input else "127.0.0.1"
	NetworkManager.join_game(target_ip)
	start_game()

func _on_solo_pressed():
	start_game()

func start_game():
	get_tree().change_scene_to_file("res://demo_level/world_castle.tscn")

func _on_back_to_main_menu():
	_toggle_main_ui(true)


func _on_admin_pressed():
	var admin_panel = preload("res://ui/admin_panel.tscn").instantiate()
	add_child(admin_panel)

func _on_quit_pressed():
	get_tree().quit()
