extends CharacterBody2D

signal defeated(drop_type: String)

@export var damage_amount = 10.0
@export var drop_type: String = "Sus Meat"
@export var speed: float = 120.0
@export var chase_speed: float = 200.0
@export var detection_radius: float = 180.0
@export var attack_range: float = 15.0
@export var attack_cooldown: float = 1.0

var _player = null
var _state: String = "idle" 
var _attack_ready: bool = true

func _ready():
	z_index = 1
	var mob_types = Array($AnimatedSprite2D.sprite_frames.get_animation_names())
	$AnimatedSprite2D.animation = mob_types.pick_random()
	$AnimatedSprite2D.play()
	_player = null
	if get_parent() and get_parent().has_node("Player"):
		_player = get_parent().get_node("Player")
	match $AnimatedSprite2D.animation:
		"walk":
			drop_type = "Sus Meat"
		"swim":
			drop_type = "Slime"
		"fly":
			drop_type = "Essence"

func _physics_process(delta: float) -> void:
	if _player == null:
		if get_parent() and get_parent().has_node("Player"):
			_player = get_parent().get_node("Player")
		return

	var to_player = _player.global_position - global_position
	var dist = to_player.length()

	match _state:
		"idle":
			velocity = Vector2.ZERO
			if dist <= detection_radius:
				_state = "chase"
		"chase":
			if dist > detection_radius * 1.5:
				_state = "idle"
				velocity = Vector2.ZERO
			else:
				velocity = to_player.normalized() * chase_speed
				
				if to_player.x != 0:
					$AnimatedSprite2D.flip_h = to_player.x < 0
				
				if dist <= attack_range and _attack_ready:
					_attack_ready = false
					damage_player()
					_start_attack_cooldown()
					
	move_and_slide()

func _start_attack_cooldown() -> void:
	await get_tree().create_timer(attack_cooldown).timeout
	_attack_ready = true

func take_hit():
	defeated.emit(drop_type)
	queue_free()

func damage_player():
	if get_parent() and get_parent().has_method("take_damage_from_enemy"):
		if $AnimatedSprite2D and $AnimatedSprite2D.sprite_frames and $AnimatedSprite2D.sprite_frames.has_animation("attack"):
			$AnimatedSprite2D.animation = "attack"
			$AnimatedSprite2D.play()
		get_parent().call_deferred("take_damage_from_enemy", damage_amount)

func play_attack_animation():
	if $AnimatedSprite2D and $AnimatedSprite2D.sprite_frames and $AnimatedSprite2D.sprite_frames.has_animation("attack"):
		$AnimatedSprite2D.animation = "attack"
		$AnimatedSprite2D.play()
	elif get_parent() and get_parent().has_method("_on_player_hit"):
		if _player and _player.has_method("_on_body_entered"):
			_player.call_deferred("_on_body_entered", self)

func _on_visible_on_screen_notifier_2d_screen_exited():
	queue_free()
