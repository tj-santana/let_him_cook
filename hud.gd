extends CanvasLayer

# Notifies `Main` node that the button has been pressed
signal start_game

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func show_message(text):
	$Message.text = text
	$Message.show()
	$MessageTimer.start()

func update_health(current_health: float, max_health: float):
	$HealthBar.value = (current_health / max_health) * 100.0
	$HealthBar/Label.text = "%d" % current_health + "/%d" % max_health

func update_hunger(current_hunger: float, max_hunger: float):
	$HungerBar.value = (current_hunger / max_hunger) * 100.0
	$HungerBar/Label.text = "%d" % current_hunger + "/%d" % max_hunger

func update_ingredients(ingredients):
	$IngredientsLabel.text = "Ingredients: %s" % ingredients
	
func show_game_over():
	show_message("Game Over")
	# Wait until the MessageTimer has counted down.
	await $MessageTimer.timeout

	$Message.text = "Dodge the Creeps!"
	$Message.show()
	# Make a one-shot timer and wait for it to finish.
	await get_tree().create_timer(1.0).timeout
	$StartButton.show()
	
func update_score(score):
	$ScoreLabel.text = "Time: %s" % score

func _on_start_button_pressed():
	$StartButton.hide()
	start_game.emit()

func _on_message_timer_timeout():
	$Message.hide()
