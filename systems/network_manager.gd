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
var current_peers: Dictionary = {} # Store basic peer data locally

func _ready():
	# Connect internal signaling to the multiplayer API
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

## PUBLIC API

# Start hosting a server
func host_game(port: int = DEFAULT_PORT) -> Error:
	var error = enet_peer.create_server(port, MAX_CLIENTS)
	if error != OK:
		print("NetworkManager: Failed to start server - ", error)
		return error
	
	multiplayer.multiplayer_peer = enet_peer
	is_server = true
	
	# Add the host as a peer locally
	_on_peer_connected(1)
	
	print("NetworkManager: Server started on port ", port)
	connection_established.emit()
	return OK

# Join an existing server
func join_game(address: String = "127.0.0.1", port: int = DEFAULT_PORT) -> Error:
	var error = enet_peer.create_client(address, port)
	if error != OK:
		print("NetworkManager: Failed to connect to server - ", error)
		return error
	
	multiplayer.multiplayer_peer = enet_peer
	is_server = false
	
	print("NetworkManager: Connection attempt to ", address, ":", port)
	return OK

# Safety function to clean up connections
func disconnect_game():
	if enet_peer:
		enet_peer.close()
	multiplayer.multiplayer_peer = null
	current_peers.clear()
	is_server = false
	print("NetworkManager: Disconnected.")

## INTERNAL CALLBACKS

func _on_peer_connected(id: int):
	print("NetworkManager: Peer connected - ", id)
	current_peers[id] = {"id": id}
	peer_connected.emit(id)

func _on_peer_disconnected(id: int):
	print("NetworkManager: Peer disconnected - ", id)
	current_peers.erase(id)
	peer_disconnected.emit(id)

func _on_connected_to_server():
	print("NetworkManager: Successfully connected to server.")
	connection_established.emit()

func _on_connection_failed():
	print("NetworkManager: Initial connection failed.")
	connection_failed.emit()
	disconnect_game()

func _on_server_disconnected():
	print("NetworkManager: Server has disconnected.")
	server_disconnected.emit()
	disconnect_game()
