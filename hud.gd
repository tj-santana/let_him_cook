extends CanvasLayer

var pickup_container: VBoxContainer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pickup_container = VBoxContainer.new()
	add_child(pickup_container)
	
	# Anchor it to the bottom right
	pickup_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	pickup_container.offset_right = -20 # 20 pixels away from the right edge
	pickup_container.offset_bottom = -20 # 20 pixels away from the bottom edge
	pickup_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pickup_container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	pickup_container.alignment = BoxContainer.ALIGNMENT_END


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func show_pickup(item_name: String, amount: int = 1) -> void:
	var label = Label.new()
	label.text = "+%d %s" % [amount, item_name]
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.4)) # A nice light green color
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	
	pickup_container.add_child(label)
	
	# Animate the label: hold for 2 seconds, fade out over 1 second, then delete
	var tween = create_tween()
	tween.tween_interval(2.0) 
	tween.tween_property(label, "modulate:a", 0.0, 1.0) 
	tween.tween_callback(label.queue_free)	
	
func update_health(current_health: float, max_health: float):
	$HealthBar.value = max(0.0, (current_health / max_health) * 100.0)
	if current_health <= 0.0:
		$HealthBar.self_modulate = Color(0.4, 0.0, 0.0, 1.0) # Dark red/crimson
		$HealthBar/Label.text = "BLEEDING: %d" % current_health + "/%d" % max_health
	else:
		$HealthBar.self_modulate = Color(0.95, 0.0, 0.0, 1.0) # Bright red
		$HealthBar/Label.text = "%d" % current_health + "/%d" % max_health

func update_hunger(current_hunger: float, max_hunger: float):
	$HungerBar.value = (current_hunger / max_hunger) * 100.0
	$HungerBar/Label.text = "%d" % current_hunger + "/%d" % max_hunger


func update_score(score):
	$ScoreLabel.text = "Time: %s" % score
