extends Node
class_name SpawnManager

## Manages spawn points for different areas (starter area vs city)
## This works alongside the existing spawn site system

@export var starter_area_spawn: NodePath
@export var city_area_spawn: NodePath

func _ready():
	# Wait a frame for all nodes to be ready
	call_deferred("_setup_spawn_system")

func _setup_spawn_system():
	# Connect to existing spawn system if available
	var spawn_sites = get_tree().get_nodes_in_group("spawn_site")
	for spawn_site in spawn_sites:
		if spawn_site.has_signal("player_spawned"):
			spawn_site.player_spawned.connect(_on_player_spawned)
			print("Connected to spawn site: ", spawn_site.name)

func _on_player_spawned(player_node):
	# Determine if player should spawn in city based on last position or game state
	# For now, we'll use a simple check - if the player has visited the city before
	if player_node.has_meta("visited_city"):
		# Player has been to city before, spawn at city entrance
		teleport_to_city_spawn(player_node)
	else:
		# First time or normal spawn, use starter area
		print("Player spawned at starter area")

func teleport_to_city_spawn(player_node):
	if city_area_spawn and has_node(city_area_spawn):
		var spawn_point = get_node(city_area_spawn)
		if spawn_point:
			player_node.global_position = spawn_point.global_position
			print("Player teleported to city entrance")
			return true
	return false

# Public function to manually set city as preferred spawn
func set_city_spawn():
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.set_meta("visited_city", true)
		print("City spawn set as preferred")

# Public function to manually set starter area as preferred spawn
func set_starter_spawn():
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.remove_meta("visited_city")
		print("Starter area spawn set as preferred")
