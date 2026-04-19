extends Control

signal back_to_main_menu()

@onready var back_button = $BackButton

func _ready():
	back_button.pressed.connect(_on_back_pressed)

func _on_back_pressed():
	back_to_main_menu.emit()
	queue_free()
