extends RigidBody2D

signal defeated
@export var damage_amount = 10.0


# Called when the node enters the scene tree for the first time.
func _ready():
	var mob_types = Array($AnimatedSprite2D.sprite_frames.get_animation_names())
	$AnimatedSprite2D.animation = mob_types.pick_random()
	$AnimatedSprite2D.play()

func take_hit():
	defeated.emit()
	queue_free()

func damage_player():
	get_parent().take_damage(damage_amount)

func _on_visible_on_screen_notifier_2d_screen_exited():
	queue_free()
