extends CharacterBody2D

signal hit(dmg: float)

@onready var audio_player : AudioStreamPlayer = $AudioStreamPlayer

@export var speed = 400.0 # How fast the player will move (pixels/sec).
@export var max_health = 100.0
@export var attack_dmg = 10.0
@export var attack_range = 70.0
@export var attack_offset = 42.0
@export var attack_cooldown = 0.5
@export var dash_speed = 1100.0
@export var dash_duration = 0.16
@export var dash_cooldown = 0.7
@export var hit_invulnerability = 0.6
@export var debug_attack_preview = true
@export var is_playing = false
@export var attack_collision_mask: int = 4

var can_attack = true
var can_dash = true
var can_take_hit = true
var is_dashing = false
var is_attacking = false
var dash_time_left = 0.0
var current_health = 100.0
var show_attack_preview = false
var facing = Vector2.RIGHT
var screen_size 

func _ready():
	screen_size = get_viewport_rect().size
	hide()

	# Ensure the player's current health starts at the configured max
	current_health = max_health
	if has_node("Hitbox") and not $Hitbox.body_entered.is_connected(_on_hitbox_body_entered):
		$Hitbox.body_entered.connect(_on_hitbox_body_entered)

	# If the Hitbox Area2D defines a collision mask in the scene, prefer that
	if has_node("Hitbox"):
		# read mask from scene so designers can change it in the editor
		var scene_mask = $Hitbox.collision_mask
		if typeof(scene_mask) == TYPE_INT and scene_mask != 0:
			attack_collision_mask = int(scene_mask)

func _physics_process(delta):
	if not is_playing:
		return
	var input_vector = Vector2.ZERO 
	if Input.is_action_pressed("move_right"):
		input_vector.x += 1
	if Input.is_action_pressed("move_left"):
		input_vector.x -= 1
	if Input.is_action_pressed("move_down"):
		input_vector.y += 1
	if Input.is_action_pressed("move_up"):
		input_vector.y -= 1

	if input_vector.length() > 0:
		facing = input_vector.normalized()

	if Input.is_action_just_pressed("attack"):
		attack()

	if Input.is_action_just_pressed("dash"):
		dash()
		
	if Input.is_action_just_pressed("cooking") and Input.is_action_just_pressed("mama"):
		audio_player.play()
		print("COOKING MAMA!")

	if is_dashing:
		velocity = facing * dash_speed
		dash_time_left -= delta
		if dash_time_left <= 0.0:
			is_dashing = false
	else:
		if input_vector.length() > 0:
			velocity = input_vector.normalized() * speed
			$AnimatedSprite2D.play()
		else:
			velocity = Vector2.ZERO
			if is_attacking:
				$AnimatedSprite2D.play()
			else:
				$AnimatedSprite2D.stop()
			
	# move_and_slide and position clamping
	move_and_slide()
	# DO NOT clamp to viewport here — room bounds or camera limits will govern allowed movement

	if debug_attack_preview and show_attack_preview:
		queue_redraw()
	
	if not is_attacking:
		if velocity.x != 0:
			$AnimatedSprite2D.animation = "walk"
			$AnimatedSprite2D.flip_v = false
			$AnimatedSprite2D.flip_h = velocity.x < 0
		elif velocity.y != 0:
			if $AnimatedSprite2D.sprite_frames.has_animation("up"):
				$AnimatedSprite2D.animation = "up"
			else:
				$AnimatedSprite2D.animation = "walk"
			$AnimatedSprite2D.flip_v = false
		else:
			$AnimatedSprite2D.animation = "idle"

func attack():
	if not can_attack:
		return

	can_attack = false
	is_attacking = true
	show_attack_preview = true
	queue_redraw()
		
	if $AnimatedSprite2D.sprite_frames.has_animation("attack"):
		$AnimatedSprite2D.animation = "attack"
	else:
		print("ERROR: 'attack' animation not found!")
	
	var attack_center = global_position + facing.normalized() * attack_offset
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = attack_range
	query.shape = shape
	query.transform = Transform2D(0.0, attack_center)
	query.collide_with_bodies = true
	query.collide_with_areas = true
	query.collision_mask = attack_collision_mask

	var hits = get_world_2d().direct_space_state.intersect_shape(query, 8)
	var hit_mobs = []
	
	for hit_result in hits:
		var body = hit_result["collider"]
		if body != null and body.has_method("take_hit") and not hit_mobs.has(body):
			hit_mobs.append(body)
			body.take_hit(attack_dmg)
			
	if hit_mobs.is_empty() and get_parent():
		for child in get_parent().get_children():
			if child.has_method("take_hit") and child.has_method("damage_player"):
				if child.global_position.distance_to(attack_center) <= attack_range:
					child.take_hit(attack_dmg)

	await get_tree().create_timer(attack_cooldown).timeout
	show_attack_preview = false
	queue_redraw()
	can_attack = true
	is_attacking = false

func dash():
	if not can_dash:
		return

	can_dash = false
	is_dashing = true
	dash_time_left = dash_duration
	await get_tree().create_timer(dash_cooldown).timeout
	can_dash = true

func _on_hitbox_body_entered(body):
	if is_dashing or not can_take_hit:
		return
	if body.has_method("take_hit") or body.has_method("damage_player"):
		can_take_hit = false
		var dmg = body.damage_amount if "damage_amount" in body else 10.0
		current_health -= dmg
		hit.emit()
		if current_health <= 0:
			die()
		else:
			if get_tree():
				await get_tree().create_timer(hit_invulnerability).timeout
			else:
				die()
			if visible:
				can_take_hit = true

func _on_body_entered(_body):
	if is_dashing or not can_take_hit:
		return

	can_take_hit = false
	hit.emit()
	if get_tree():
		await get_tree().create_timer(hit_invulnerability).timeout
	else:
		die()
	if visible:
		can_take_hit = true
	
func start(pos):
	position = pos
	show()
	current_health = max_health
	can_take_hit = true
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", false)

func die():
	hide()
	can_take_hit = false
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)

func _draw():
	if debug_attack_preview and show_attack_preview:
		var center = facing.normalized() * attack_offset
		draw_circle(center, attack_range, Color(1.0, 0.2, 0.2, 0.2))

func aplicar_buff_comida(bonus_velocidade: int, reducao_cooldown: float, duracao: float):
	speed += bonus_velocidade
	attack_cooldown -= reducao_cooldown
	
	if attack_cooldown < 0.1:
		attack_cooldown = 0.1
		
	print("Buff Aplicado! Speed: ", speed, " | Cooldown: ", attack_cooldown)
	
	await get_tree().create_timer(duracao).timeout
	
	speed -= bonus_velocidade
	attack_cooldown += reducao_cooldown
	
	print("O Buff acabou! Voltaste ao normal.")
