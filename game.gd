extends Node

@export var mob_scene: PackedScene
@export var hunger_drain_rate = 3.0
@export var hit_health_damage = 10.0
@export var hit_max_health_damage = 5.0
@export var min_max_health = 25.0
@export var game_over_timer = 2.0

var score
var ingredients
var health = 100.0
var max_health = 100.0
var hunger = 100.0
var max_hunger = 100.0
var is_game_over = false
var is_playing = false
var player_inventory = {
	"Sus Meat": 0,
	"Slime": 0,
	"Essence": 0
}

# Simple wave system: list of dictionaries {count, interval}
var waves = [
	{"count": 5, "interval": 0.8},
	{"count": 8, "interval": 0.7},
	{"count": 12, "interval": 0.6}
]
var current_wave = 0
var mobs_left_to_spawn = 0
var mobs_alive = 0


func _refresh_inventory_hud() -> void:
	if $HUD.has_method("update_inventory"):
		$HUD.update_inventory(player_inventory)


# Called when the node enters the scene tree for the first time.
func _ready():
	# If there's a saved state from the cooking flow, restore it.
	if typeof(GameManager) != TYPE_NIL and GameManager.obter_estado_principal() != null:
		var s = GameManager.obter_estado_principal()
		# Restore numeric state
		score = s.get("score", 0)
		health = s.get("health", max_health)
		max_health = s.get("max_health", max_health)
		hunger = s.get("hunger", max_hunger)
		max_hunger = s.get("max_hunger", max_hunger)
		player_inventory = s.get("player_inventory", player_inventory).duplicate()

		# Update HUD
		$HUD.update_score(score)
		$HUD.update_health(health, max_health)
		$HUD.update_hunger(hunger, max_hunger)
		_refresh_inventory_hud()

		# Apply any pending food buffs from cooking
		if typeof(GameManager) != TYPE_NIL and GameManager.get("buff_pendente"):
			print("--- APPLYING FOOD BUFFS ---")
			if $Player.has_method("aplicar_buff_comida"):
				$Player.aplicar_buff_comida(
					GameManager.get("buff_velocidade"),
					GameManager.get("buff_cooldown"),
					GameManager.get("buff_duracao")
				)
			else:
				print("ERRO: O script do Jogador não tem a função aplicar_buff_comida!")
			
			# Recover some health and hunger from eating
			hunger = min(hunger + 10.0, max_hunger)
			health = min(health + 20.0, max_health)
			$HUD.update_hunger(hunger, max_hunger)
			$HUD.update_health(health, max_health)
			
			# Clear the pending buff flag
			GameManager.buff_pendente = false
			print("Buffs aplicados com sucesso!")
		
		# Place player back where they were
		if s.has("player_pos"):
			$Player.start(s.get("player_pos"))

		# Restart timers if the game was playing
		if s.get("is_playing", false):
			$MobTimer.start()
			$ScoreTimer.start()
			is_playing = true
			$Player.is_playing = true

		# Clear saved state
		GameManager.limpar_estado_principal()
	else:
		new_game()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_game_over:
		return

	if is_playing and hunger > 0:
		hunger -= hunger_drain_rate * delta
		hunger = max(hunger, 0.0)
		$HUD.update_hunger(hunger, max_hunger)

	if hunger <= 0 or health <= 0:
		game_over()

	# If we returned from the cooking scene, the autoload GameManager may
	# carry an updated inventory. Merge it into our local inventory and
	# refresh the HUD once. (Assumes GameManager is autoloaded.)
	if not Engine.is_editor_hint() and typeof(GameManager) != TYPE_NIL:
		if GameManager.inventario_jogador:
			player_inventory = GameManager.inventario_jogador.duplicate()
			_refresh_inventory_hud()



func game_over():
	if is_game_over:
		return

	is_game_over = true
	is_playing = false
	$Player.is_playing = false
	$ScoreTimer.stop()
	$MobTimer.stop()
	$Player.die()
	get_tree().call_group("mobs", "queue_free")
	if typeof(GameManager) != TYPE_NIL:
		GameManager.limpar_estado_principal()
	$HUD.get_node("GameOver").show()
	await get_tree().create_timer(game_over_timer).timeout
	get_tree().change_scene_to_file("res://MainMenu.tscn")

func new_game():
	is_game_over = false
	is_playing = false
	score = 0
	ingredients = 0
	max_health = 100.0
	health = max_health
	hunger = max_hunger
	player_inventory = {
		"Sus Meat": 0,
		"Slime": 0,
		"Essence": 0
	}
	$HUD.update_score(score)
	$HUD.update_health(health, max_health)
	$HUD.update_hunger(hunger, max_hunger)
	if $HUD.has_node("Message"):
		$HUD.get_node("Message").hide()
	if $HUD.has_node("StartButton"):
		$HUD.get_node("StartButton").hide()
	if $HUD.has_node("MessageTimer"):
		$HUD.get_node("MessageTimer").stop()
	$Player.start($StartPosition.position)
	$StartTimer.start()

	# initialize waves
	current_wave = 0
	mobs_left_to_spawn = 0
	mobs_alive = 0
	# prepare first wave when start timer fires

	# refresh HUD for inventory
	_refresh_inventory_hud()
	if typeof(GameManager) != TYPE_NIL:
		GameManager.inventario_jogador = player_inventory.duplicate()

func _on_mob_timer_timeout():
	var mob_spawn_location = get_node("MobPath/MobSpawnLocation")
	mob_spawn_location.progress_ratio = randf()
	
	var mob = mob_scene.instantiate()
	mob.global_position = mob_spawn_location.global_position
	
	var screen_center = get_viewport().get_visible_rect().size / 2
	var direction_to_center = (screen_center - mob.global_position).normalized()
	
	var random_variance = randf_range(-PI / 4, PI / 4)
	direction_to_center = direction_to_center.rotated(random_variance)
	
	var base_speed = randf_range(mob.speed, mob.chase_speed)
	mob.velocity = direction_to_center * base_speed
	
	add_child(mob)

	mob.defeated.connect(_on_mob_defeated)
	mobs_alive += 1
	if mobs_left_to_spawn > 0:
		mobs_left_to_spawn -= 1
		if mobs_left_to_spawn == 0:
			# stop spawning for this wave
			$MobTimer.stop()

	# If we've spawned all and there are no mobs alive, advance wave
	if mobs_left_to_spawn == 0 and mobs_alive == 0:
		_advance_wave()

func _on_score_timer_timeout():
	score += 1
	$HUD.update_score(score)

func _on_mob_defeated(drop_type: String = "Sus Meat"):

	# Add the dropped ingredient type to the player's inventory
	var key = drop_type if typeof(drop_type) == TYPE_STRING and drop_type != "" else "Sus Meat"
	player_inventory[key] = player_inventory.get(key, 0) + 1

	# Update the visible ingredient count (sum of all ingredient types)
	_refresh_inventory_hud()
	if typeof(GameManager) != TYPE_NIL:
		GameManager.inventario_jogador = player_inventory.duplicate()

	# Small hunger refund on kill
	hunger += 5.0
	hunger = min(hunger, max_hunger)
	$HUD.update_hunger(hunger, max_hunger)

	# track alive mobs for wave progression
	mobs_alive = max(0, mobs_alive - 1)
	if mobs_left_to_spawn == 0 and mobs_alive == 0:
		_advance_wave()

	# update GameManager inventory snapshot
	if typeof(GameManager) != TYPE_NIL:
		GameManager.inventario_jogador = player_inventory.duplicate()


func _on_player_hit():
	if is_game_over:
		return

	max_health = max(max_health - hit_max_health_damage, min_max_health)
	if health != 100.0:
		health = min(health, max_health)
	health = max(health - hit_health_damage, 0.0)
	$HUD.update_health(health, max_health)
	if health <= 0:
		game_over()

func _on_start_timer_timeout():
	$MobTimer.start()
	$ScoreTimer.start()
	is_playing = true
	$Player.is_playing = true
	# Start first wave
	_start_wave(current_wave)


func _start_wave(index: int) -> void:
	if index >= waves.size():
		# no more waves; optionally loop or increase difficulty
		return
	var w = waves[index]
	mobs_left_to_spawn = int(w.get("count", 5))
	$MobTimer.wait_time = float(w.get("interval", 0.8))
	$MobTimer.start()


func _advance_wave() -> void:
	current_wave += 1
	if current_wave < waves.size():
		# small delay then start next wave
		get_tree().create_timer(1.2).timeout.connect(func(): _start_wave(current_wave))
	else:
		# all waves complete -- for now, restart waves
		current_wave = 0
		get_tree().create_timer(2.0).timeout.connect(func(): _start_wave(current_wave))


func _input(event):
	if event.is_action_pressed("interact") and is_playing and not is_game_over:
		# Ensure the autoloaded GameManager knows where to return
		if typeof(GameManager) != TYPE_NIL:
			GameManager.cena_principal_path = "res://game.tscn"
			GameManager.inventario_jogador = player_inventory.duplicate()
			# Save full state so the main scene can be restored after cooking
			GameManager.guardar_estado_principal({
				"score": score,
				"health": health,
				"max_health": max_health,
				"hunger": hunger,
				"max_hunger": max_hunger,
				"player_pos": $Player.global_position,
				"is_playing": is_playing,
				"player_inventory": player_inventory.duplicate()
			})

		# Pause main gameplay
		is_playing = false
		$MobTimer.stop()
		$ScoreTimer.stop()
		$Player.is_playing = false

		# Switch to the cooking UI (microgames)
		get_tree().change_scene_to_file("res://microgames/CozinhaPrincipal.tscn")
