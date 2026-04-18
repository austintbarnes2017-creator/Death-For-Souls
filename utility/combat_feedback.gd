extends Node

## Manages global combat effects like Hit Stop (Time Freeze)

func trigger_hit_stop(duration: float = 0.05, time_scale: float = 0.05):
	Engine.time_scale = time_scale
	await get_tree().create_timer(duration * time_scale).timeout
	Engine.time_scale = 1.0
