extends CharacterBody2D

signal hit(dmg: float)

@onready var audio_player : AudioStreamPlayer = $AudioStreamPlayer
@onready var actionable_finder: Area2D = $ActionableFinder

@export var speed = 400.0 # How fast the player will move (pixels/sec).
@export var max_health = 100.0
@export var attack_dmg = 10.0
@export var attack_range = 70.0
@export var attack_offset = 42.0
@export var attack_cooldown = 0.5
@export var dash_speed = 1200.0
@export var dash_duration = 0.2
@export var dash_cooldown = 0.7
@export var hit_invulnerability = 0.6
@export var debug_attack_preview = true
@export var is_playing = false
@export var attack_collision_mask: int = 4
@export var spork_speed_bonus = 120.0
@export var spork_attack_dmg_bonus = 5.0
@export var spork_attack_cooldown_reduction = 0.15
@export var spork_dash_speed_bonus = 200.0
@export var spork_visual_tint = Color(1.0, 0.92, 0.72, 1.0)

var base_speed = 400.0
var base_attack_dmg = 10.0
var base_attack_cooldown = 0.5
var base_dash_speed = 1200.0
var temp_speed_bonus := 0.0
var temp_attack_dmg_bonus := 0.0
var temp_attack_cooldown_reduction := 0.0
var temp_dash_speed_bonus := 0.0
var temp_damage_taken_multiplier := 1.0
var spork_mode_active := false
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
var _room_invulnerability_token := 0
var _pitfall_sequence_token := 0
var is_in_pitfall_sequence := false
var near_death_active := false
var starving_active := false


func _apply_damage(dmg: float, can_kill: bool = true) -> void:
	if is_dashing or not can_take_hit:
		return

	can_take_hit = false
	var applied_damage = dmg * temp_damage_taken_multiplier
	if not can_kill:
		applied_damage = min(applied_damage, max(0.0, current_health - 1.0))

	current_health -= applied_damage
	hit.emit(applied_damage)
	
	# Death is managed by the master game script (game.gd).
	# The player remains active in near death state until game_over is triggered.
	if get_tree():
		await get_tree().create_timer(hit_invulnerability).timeout
	if visible:
		can_take_hit = true

func _ready():
	screen_size = get_viewport_rect().size
	hide()
	base_speed = speed
	base_attack_dmg = attack_dmg
	base_attack_cooldown = attack_cooldown
	base_dash_speed = dash_speed
	_recalculate_combat_stats()

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


func _recalculate_combat_stats() -> void:
	speed = max(0.0, base_speed + temp_speed_bonus + (spork_speed_bonus if spork_mode_active else 0.0))
	attack_dmg = max(0.0, base_attack_dmg + temp_attack_dmg_bonus + (spork_attack_dmg_bonus if spork_mode_active else 0.0))
	attack_cooldown = max(0.1, base_attack_cooldown - temp_attack_cooldown_reduction - (spork_attack_cooldown_reduction if spork_mode_active else 0.0))
	dash_speed = max(0.0, base_dash_speed + temp_dash_speed_bonus + (spork_dash_speed_bonus if spork_mode_active else 0.0))
	
	if near_death_active:
		speed *= 0.5
		attack_dmg *= 0.5
	elif starving_active:
		speed *= 0.8

	if has_node("AnimatedSprite2D"):
		if near_death_active:
			$AnimatedSprite2D.modulate = Color(1.0, 0.3, 0.3, 1.0)
		elif spork_mode_active:
			$AnimatedSprite2D.modulate = spork_visual_tint
		else:
			$AnimatedSprite2D.modulate = Color.WHITE


func set_near_death_active(active: bool) -> void:
	if near_death_active == active:
		return
	near_death_active = active
	_recalculate_combat_stats()


func set_starving_active(active: bool) -> void:
	if starving_active == active:
		return
	starving_active = active
	_recalculate_combat_stats()


func set_spork_mode_active(active: bool) -> void:
	if spork_mode_active == active:
		return
	spork_mode_active = active
	_recalculate_combat_stats()


func toggle_spork_mode() -> bool:
	set_spork_mode_active(not spork_mode_active)
	return spork_mode_active

func _physics_process(delta):
	if not is_playing:
		return
	var input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input_vector.length() > 0:
		facing = input_vector.normalized()

	if Input.is_action_just_pressed("attack"):
		attack()

	if Input.is_action_just_pressed("dash"):
		dash()
		
	if Input.is_action_just_pressed("interact"):
		var actionables = actionable_finder.get_overlapping_areas()
		if actionables.size() > 0:
			actionables[0].action()
			return
		
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
	if not can_dash or near_death_active:
		return

	can_dash = false
	is_dashing = true
	dash_time_left = dash_duration
	await get_tree().create_timer(dash_cooldown).timeout
	can_dash = true

func _on_hitbox_body_entered(body):
	if body.has_method("take_hit") or body.has_method("damage_player"):
		var dmg = body.damage_amount if "damage_amount" in body else 10.0
		_apply_damage(dmg)

func _on_body_entered(_body):
	_apply_damage(10.0)


func apply_damage(dmg: float) -> void:
	_apply_damage(dmg)


func apply_nonlethal_damage(dmg: float) -> void:
	_apply_damage(dmg, false)


func reset_to_position(target_position: Vector2) -> void:
	call_deferred("_complete_reset_to_position", target_position)


func _complete_reset_to_position(target_position: Vector2) -> void:
	global_position = target_position
	velocity = Vector2.ZERO
	can_take_hit = true
	can_dash = true
	is_dashing = false
	is_attacking = false
	show_attack_preview = false
	current_health = max(current_health, 1.0)


func grant_room_entry_invulnerability(duration: float = 0.25) -> void:
	_room_invulnerability_token += 1
	var token = _room_invulnerability_token
	can_take_hit = false
	call_deferred("_finish_room_entry_invulnerability", duration, token)


func _finish_room_entry_invulnerability(duration: float, token: int) -> void:
	await get_tree().create_timer(duration).timeout
	if token != _room_invulnerability_token:
		return
	if is_inside_tree() and visible:
		can_take_hit = true
	else:
		can_take_hit = true


func begin_pitfall_sequence(target_position: Vector2, freeze_duration: float = 0.35) -> void:
	if is_in_pitfall_sequence:
		return
	is_in_pitfall_sequence = true
	can_take_hit = false
	can_dash = false
	_pitfall_sequence_token += 1
	var token = _pitfall_sequence_token
	call_deferred("_finish_pitfall_sequence", target_position, freeze_duration, token)


func _finish_pitfall_sequence(target_position: Vector2, freeze_duration: float, token: int) -> void:
	var was_playing = is_playing
	is_playing = false
	velocity = Vector2.ZERO
	is_dashing = false
	is_attacking = false
	show_attack_preview = false
	await get_tree().create_timer(freeze_duration).timeout
	if token != _pitfall_sequence_token:
		return
	global_position = target_position
	if was_playing:
		is_playing = true
	can_take_hit = true
	can_dash = true
	is_in_pitfall_sequence = false
		
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

func aplicar_buff_comida(bonus_velocidade: int, reducao_cooldown: float, duracao: float, bonus_dano: float = 0.0, mult_dano_recebido: float = 1.0):
	temp_speed_bonus += bonus_velocidade
	temp_attack_cooldown_reduction += reducao_cooldown
	temp_attack_dmg_bonus += bonus_dano
	temp_damage_taken_multiplier = mult_dano_recebido
	_recalculate_combat_stats()
	
	print("Buff Aplicado! Speed: ", speed, " | Cooldown: ", attack_cooldown, " | Dano: ", attack_dmg, " | Mult Dano Recebido: ", temp_damage_taken_multiplier)
	
	await get_tree().create_timer(duracao).timeout
	
	temp_speed_bonus -= bonus_velocidade
	temp_attack_cooldown_reduction -= reducao_cooldown
	temp_attack_dmg_bonus -= bonus_dano
	temp_damage_taken_multiplier = 1.0
	_recalculate_combat_stats()
	
	print("O Buff acabou! Voltaste ao normal.")
