extends Control

@onready var player_name_input = $Panel/VBoxContainer/PlayerManagement/PlayerNameInput
@onready var ban_button = $Panel/VBoxContainer/PlayerManagement/BanButton
@onready var fly_button = $Panel/VBoxContainer/ToolsSection/FlyButton
@onready var give_axe_button = $Panel/VBoxContainer/ToolsSection/GiveAxeButton
@onready var give_sword_button = $Panel/VBoxContainer/ToolsSection/GiveSwordButton
@onready var give_shield_button = $Panel/VBoxContainer/ToolsSection/GiveShieldButton
@onready var close_button = $Panel/VBoxContainer/CloseButton

var banned_players: Array = []
var fly_mode_enabled: bool = false

func _ready():
	print("Admin panel _ready() called")
	
	# Add to admin_panel group for easy finding
	add_to_group("admin_panel")
	
	# Connect button signals
	ban_button.pressed.connect(_on_ban_pressed)
	fly_button.pressed.connect(_on_fly_pressed)
	give_axe_button.pressed.connect(_on_give_axe_pressed)
	give_sword_button.pressed.connect(_on_give_sword_pressed)
	give_shield_button.pressed.connect(_on_give_shield_pressed)
	close_button.pressed.connect(_on_close_pressed)
	
	print("Admin panel initialized")
	
	# Load banned players list
	load_banned_players()

func load_banned_players():
	var ban_file = FileAccess.open("user://banned_players.json", FileAccess.READ)
	if ban_file:
		var json_string = ban_file.get_as_text()
		ban_file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		
		if parse_result == OK:
			banned_players = json.data

func save_banned_players():
	var ban_file = FileAccess.open("user://banned_players.json", FileAccess.WRITE)
	if ban_file:
		var json_string = JSON.stringify(banned_players)
		ban_file.store_string(json_string)
		ban_file.close()

func _on_ban_pressed():
	var player_name = player_name_input.text.strip_edges()
	
	if player_name == "":
		print("Please enter a player name to ban")
		return
	
	if player_name in banned_players:
		print("Player %s is already banned" % player_name)
		return
	
	banned_players.append(player_name)
	save_banned_players()
	print("Player %s has been banned" % player_name)
	
	# In a multiplayer game, you would disconnect the banned player here
	# For now, we'll just log it
	
	player_name_input.text = ""

func _on_fly_pressed():
	fly_mode_enabled = !fly_mode_enabled
	
	var player_node = find_player_node()
	if player_node:
		print("Found player node, toggling fly mode")
		if fly_mode_enabled:
			enable_fly_mode(player_node)
			fly_button.text = "Disable Fly Mode"
		else:
			disable_fly_mode(player_node)
			fly_button.text = "Enable Fly Mode"
	else:
		print("ERROR: No player node found for fly mode")

func enable_fly_mode(player_node: Node):
	# Interface with the new FlyComponent
	var fly_component = find_fly_component(player_node)
	if fly_component:
		if not fly_component.active:
			fly_component.toggle()
			print("Fly mode enabled via admin panel (FlyComponent)")
	else:
		# Fallback to old method
		if player_node.has_method("toggle_fly_mode"):
			if not player_node.fly_mode_enabled:
				player_node.toggle_fly_mode()
				print("Fly mode enabled via admin panel (fallback)")
		else:
			print("ERROR: Could not find FlyComponent or toggle_fly_mode method")

func disable_fly_mode(player_node: Node):
	# Interface with the new FlyComponent
	var fly_component = find_fly_component(player_node)
	if fly_component:
		if fly_component.active:
			fly_component.toggle()
			print("Fly mode disabled via admin panel (FlyComponent)")
	else:
		# Fallback to old method
		if player_node.has_method("toggle_fly_mode"):
			if player_node.fly_mode_enabled:
				player_node.toggle_fly_mode()
				print("Fly mode disabled via admin panel (fallback)")
		else:
			print("ERROR: Could not find FlyComponent or toggle_fly_mode method")

func find_fly_component(player_node: Node) -> FlyComponent:
	# Find the FlyComponent child node
	if player_node:
		var fly_comp = player_node.get_node_or_null("FlyComponent")
		if fly_comp and fly_comp is FlyComponent:
			return fly_comp
	return null

func _on_give_axe_pressed():
	give_weapon_to_player("axe")

func _on_give_sword_pressed():
	give_weapon_to_player("sword")

func _on_give_shield_pressed():
	give_weapon_to_player("shield")

func give_weapon_to_player(weapon_type: String):
	var player_node = find_player_node()
	if player_node:
		print("Found player node, giving weapon: %s" % weapon_type)
		if player_node.has_method("give_weapon"):
			player_node.give_weapon(weapon_type)
			print("Successfully gave %s to player" % weapon_type)
		else:
			print("ERROR: Player node doesn't have give_weapon method")
	else:
		print("ERROR: No player node found for weapon giving")

func find_player_node() -> Node:
	# Try to find the player node in the current scene
	var tree = get_tree()
	if tree and tree.current_scene:
		# Look for CharacterBodySoulsBase nodes
		var players = tree.get_nodes_in_group("player")
		if players.size() > 0:
			return players[0]
		
		# Fallback: search through scene tree
		return search_for_player(tree.current_scene)
	
	return null

func search_for_player(node: Node) -> Node:
	# Search for player node in scene tree
	if node.is_in_group("player"):
		return node
	
	for child in node.get_children():
		var result = search_for_player(child)
		if result:
			return result
	
	return null

func _on_close_pressed():
	queue_free()
