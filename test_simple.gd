extends Node

func _ready():
	print("Testing credits screen preload...")
	var credits_scene = preload("res://ui/credits_screen_fixed.tscn")
	if credits_scene:
		print("✅ Credits screen preloaded successfully")
	else:
		print("❌ Failed to preload credits screen")
	
	quit()
