extends Control

signal loading_complete

@onready var progress_bar = $LoadingPanel/VBoxContainer/ProgressBar
@onready var loading_label = $LoadingPanel/VBoxContainer/LoadingLabel

var loading_progress: float = 0.0
var is_loading_complete: bool = false

func _ready():
	# Start hidden
	visible = false
	progress_bar.value = 0.0

func start_loading():
	visible = true
	loading_progress = 0.0
	is_loading_complete = false
	progress_bar.value = 0.0
	loading_label.text = "Loading Character..."
	
	# Start the loading simulation
	_simulate_loading()

func _simulate_loading():
	# Simulate loading progress over time
	var tween = create_tween()
	tween.tween_method(_update_progress, 0.0, 100.0, 2.5)  # 2.5 seconds to load
	tween.tween_callback(_on_loading_finished)

func _update_progress(progress: float):
	loading_progress = progress
	progress_bar.value = progress
	
	# Update loading text based on progress
	if progress < 25.0:
		loading_label.text = "Loading Character..."
	elif progress < 50.0:
		loading_label.text = "Initializing Assets..."
	elif progress < 75.0:
		loading_label.text = "Preparing World..."
	else:
		loading_label.text = "Almost Ready..."

func _on_loading_finished():
	is_loading_complete = true
	loading_label.text = "Complete!"
	progress_bar.value = 100.0
	
	# Wait a moment then hide and emit signal
	await get_tree().create_timer(0.5).timeout
	visible = false
	loading_complete.emit()

func set_progress(progress: float):
	if progress < 0.0:
		progress = 0.0
	elif progress > 100.0:
		progress = 100.0
	
	_update_progress(progress)
	
	if progress >= 100.0:
		_on_loading_finished()
