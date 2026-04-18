extends Control

@onready var admin_button = $AdminButton

func _ready():
	# Connect admin button signal
	admin_button.pressed.connect(_on_admin_pressed)
	
	print("Game HUD initialized")

func _on_admin_pressed():
	print("Admin button pressed in HUD")
	
	# Find the player and call the admin panel toggle
	var player = find_player_node()
	if player and player.has_method("toggle_admin_panel"):
		player.toggle_admin_panel()
	else:
		# Fallback: try to toggle admin panel directly
		toggle_admin_panel_directly()

func find_player_node() -> Node:
	# Try to find the player node
	var tree = get_tree()
	if tree and tree.current_scene:
		# Look for player nodes in group
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

func toggle_admin_panel_directly():
	# Direct admin panel toggle as fallback
	var existing_panel = get_tree().get_nodes_in_group("admin_panel")
	
	if existing_panel.size() > 0:
		# Close existing admin panel
		print("Closing existing admin panel")
		existing_panel[0].queue_free()
	else:
		# Open new admin panel
		print("Opening new admin panel")
		var admin_panel = preload("res://ui/admin_panel.tscn").instantiate()
		if admin_panel:
			admin_panel.add_to_group("admin_panel")
			get_tree().current_scene.add_child(admin_panel)
			print("Admin panel added to scene")
		else:
			print("ERROR: Failed to instantiate admin panel")
