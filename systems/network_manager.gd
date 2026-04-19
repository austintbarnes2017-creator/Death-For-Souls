extends Node

# NetworkManager.gd - Authoritative Networking Singleton for Godot 4
# Part of the "Death For Souls" Architectural Blueprint - Phase 2

## SIGNALS
signal connection_established
signal connection_failed
signal peer_connected(id: int)
signal peer_disconnected(id: int)
signal server_disconnected

## CONSTANTS
const DEFAULT_PORT = 7777
const MAX_CLIENTS = 8

## PROPERTIES
var enet_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
var is_server: bool = false
var is_solo: bool = true
var current_peers: Dictionary = {} # Store basic peer data locally
var player_scene = preload("res://player/character_body_souls_base.tscn")

# Reference to the node where players will be spawned
var players_container: Node
var world_is_ready: bool = false

func _ready():
	# Connect internal signaling to the multiplayer API
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	# Reset state when scenes change
	get_tree().tree_changed.connect(_on_tree_changed)

## PUBLIC API

# Start hosting a server
func host_game(port: int = DEFAULT_PORT) -> Error:
	var error = enet_peer.create_server(port, MAX_CLIENTS)
	if error != OK:
		print("NetworkManager: Failed to start server - ", error)
		return error
	
	multiplayer.multiplayer_peer = enet_peer
	is_server = true
	is_solo = false
	
	# Track the host as peer ID 1 (don't try to spawn yet - world isn't loaded)
	current_peers[1] = {"id": 1}
	
	var local_ip = get_local_ip()
	print("NetworkManager: Server started on port ", port)
	print("NetworkManager: Local LAN IP: ", local_ip)
	
	connection_established.emit()
	return OK

## Helper to find the local IPv4 address
func get_local_ip() -> String:
	for ip in IP.get_local_addresses():
		# Filter for private IPv4 ranges: 192.168.x.x, 10.x.x.x, 172.16-31.x.x
		if ip.count(".") == 3 and not ip.begins_with("127.") and not ip.begins_with("169.254."):
			if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172."):
				return ip
	return "127.0.0.1"
	return "127.0.0.1"


# Join an existing server
func join_game(address: String = "127.0.0.1", port: int = DEFAULT_PORT) -> Error:
	var error = enet_peer.create_client(address, port)
	if error != OK:
		print("NetworkManager: Failed to connect to server - ", error)
		return error
	
	multiplayer.multiplayer_peer = enet_peer
	is_server = false
	is_solo = false
	
	print("NetworkManager: Connection attempt to ", address, ":", port)
	return OK

# Called by the world scene when it is ready to accept players
func world_ready(container: Node = null):
	players_container = container
	if not players_container:
		players_container = get_tree().current_scene
	
	world_is_ready = true
	print("NetworkManager: World is ready. Container: ", players_container.name)
	
	# Remove the static/placeholder player that was baked into the .tscn
	var static_player = players_container.find_child("PlayerCharacterBodySoulsBase", false, false)
	if static_player and not is_solo:
		static_player.queue_free()
		print("NetworkManager: Removed static placeholder player.")
	
	# Spawn all currently known peers (each peer manages its own scene tree)
	for peer_id in current_peers.keys():
		_spawn_player(peer_id)

# Safety function to clean up connections
func disconnect_game():
	if enet_peer:
		enet_peer.close()
	multiplayer.multiplayer_peer = null
	current_peers.clear()
	is_server = false
	world_is_ready = false
	players_container = null
	print("NetworkManager: Disconnected.")

## INTERNAL CALLBACKS

func _on_tree_changed():
	# Reset world readiness when scenes change
	pass

## CLOCK SYSTEM
var match_tick: int = 0

func _physics_process(_delta: float) -> void:
	# Both server and client advance the match clock.
	# The client's clock is an local prediction that is snapped
	# to truth whenever a server state packet arrives.
	match_tick += 1

func get_tick() -> int:
	return match_tick

func _on_peer_connected(id: int):
	print("NetworkManager: Peer connected - ", id)
	current_peers[id] = {"id": id}
	
	if world_is_ready:
		_spawn_player(id)
	
	peer_connected.emit(id)

func _spawn_player(id: int):
	if not players_container:
		print("NetworkManager ERROR: No players container set!")
		return
	
	# Don't spawn duplicates
	if players_container.has_node(str(id)):
		print("NetworkManager: Player ", id, " already exists, skipping spawn.")
		return
	
	var player_instance = player_scene.instantiate()
	player_instance.name = str(id)
	
	# Find spawn point
	var spawn_points = get_tree().get_nodes_in_group("spawn_points")
	if spawn_points.size() > 0:
		var sp = spawn_points[id % spawn_points.size()]
		player_instance.global_position = sp.global_position
		player_instance.global_rotation = sp.global_rotation
	
	# Set authority BEFORE adding to tree so _ready() sees the correct owner
	player_instance.set_multiplayer_authority(id)
	players_container.add_child(player_instance)

	print("NetworkManager: Spawned player for peer ", id, " at ", player_instance.global_position)

func _on_peer_disconnected(id: int):
	print("NetworkManager: Peer disconnected - ", id)
	current_peers.erase(id)
	
	if players_container:
		var p = players_container.get_node_or_null(str(id))
		if p:
			p.queue_free()
			print("NetworkManager: Removed player for peer ", id)
	
	peer_disconnected.emit(id)

func _on_connected_to_server():
	print("NetworkManager: Successfully connected to server.")
	# Register ourselves so world_ready() will spawn our player
	var my_id = multiplayer.get_unique_id()
	current_peers[my_id] = {"id": my_id}
	if world_is_ready:
		_spawn_player(my_id)
	connection_established.emit()

func _on_connection_failed():
	print("NetworkManager: Initial connection failed.")
	connection_failed.emit()
	disconnect_game()

func _on_server_disconnected():
	print("NetworkManager: Server has disconnected.")
	server_disconnected.emit()
	disconnect_game()
