extends Node

func _ready():
	print("Testing credits screen preload...")
	var credits_scene = preload("res://ui/credits_screen_fixed.tscn")
	if credits_scene:
		print("✅ Credits screen preloaded successfully")
		var instance = credits_scene.instantiate()
		if instance:
			print("✅ Credits screen instantiated successfully")
			instance.queue_free()
		else:
			print("❌ Failed to instantiate credits screen")
	else:
		print("❌ Failed to preload credits screen")
	
	get_tree().quit()

