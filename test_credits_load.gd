extends SceneTree

func _ready():
	# Test if credits screen can be loaded
	print("Testing credits screen preload...")
	var credits_scene = preload("res://ui/credits_screen.tscn")
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
	
	# Test main menu preload
	print("Testing main menu preload...")
	var main_menu = preload("res://ui/main_menu.gd")
	if main_menu:
		print("✅ Main menu preloaded successfully")
	else:
		print("❌ Failed to preload main menu")
	
	quit()
