extends Control

signal back_to_main_menu()

@onready var back_button = $BackButton
@onready var buy_button = $BuyButton
@onready var status_label = $ContentContainer/StatusContainer/StatusLabel
@onready var instructions = $ContentContainer/StatusContainer/Instructions

var has_death_plus = false

func _ready():
	back_button.pressed.connect(_on_back_pressed)
	buy_button.pressed.connect(_on_buy_pressed)
	
	# Check if player already has Death Plus
	load_death_plus_status()

func load_death_plus_status():
	# Check if Death Plus is already purchased
	var save_file = FileAccess.open("user://death_plus.save", FileAccess.READ)
	if save_file:
		has_death_plus = true
		save_file.close()
		update_ui_for_purchased()

func _on_buy_pressed():
	# Free purchase - no money deduction
	has_death_plus = true
	
	# Save the purchase
	var save_file = FileAccess.open("user://death_plus.save", FileAccess.WRITE)
	if save_file:
		save_file.store_string("purchased")
		save_file.close()
	
	# Update UI
	update_ui_for_purchased()
	
	# Give the perks immediately
	Global.death_plus_purchased = true

func update_ui_for_purchased():
	status_label.text = "Status: PURCHASED"
	status_label.modulate = Color(1, 0.8, 0.3, 1)  # Gold color
	instructions.text = "Red Glowing Big Skull Sword equipped! Press R in-game to use."
	buy_button.text = "PURCHASED"
	buy_button.disabled = true

func _on_back_pressed():
	back_to_main_menu.emit()
	queue_free()
