extends Node3D

## World scene controller - bridges the scene to the NetworkManager

func _ready():
	# Notify NetworkManager that the world is ready for player spawning
	if NetworkManager and not NetworkManager.is_solo:
		NetworkManager.world_ready(self)
		print("WorldCastle: Notified NetworkManager that world is ready.")
	else:
		print("WorldCastle: Solo mode, no network spawning needed.")
