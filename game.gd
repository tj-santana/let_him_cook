extends Node

@export var mob_scene: PackedScene
@export var hunger_drain_rate = 4.0
@export var hit_health_damage = 10.0
@export var hit_max_health_damage = 5.0
@export var min_max_health = 25.0

var score
var ingredients
var health = 100.0
var max_health = 100.0
var hunger = 100.0
var max_hunger = 100.0
var is_game_over = false
var game_over_timer = 2
var is_playing = false
var player_inventory = {
	"Sus Meat": 0,
	"Slime": 0,
	"Essence": 0
}


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
		# recompute ingredient count
		ingredients = 0
		for v in player_inventory.values():
			ingredients += int(v)
		$HUD.update_ingredients(ingredients)

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
			ingredients = 0
			for v in player_inventory.values():
				ingredients += int(v)
			$HUD.update_ingredients(ingredients)



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
	$HUD.update_ingredients(ingredients)
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

	# refresh HUD for inventory
	ingredients = 0
	for v in player_inventory.values():
		ingredients += int(v)
	$HUD.update_ingredients(ingredients)
	if typeof(GameManager) != TYPE_NIL:
		GameManager.inventario_jogador = player_inventory.duplicate()

func _on_mob_timer_timeout():
	# Create a new instance of the Mob scene.
	var mob = mob_scene.instantiate()

	# Choose a random location on Path2D.
	var mob_spawn_location = $MobPath/MobSpawnLocation
	mob_spawn_location.progress_ratio = randf()

	# Set the mob's position to the random location.
	mob.position = mob_spawn_location.position

	# Set the mob's direction perpendicular to the path direction.
	var direction = mob_spawn_location.rotation + PI / 2

	# Add some randomness to the direction.
	direction += randf_range(-PI / 4, PI / 4)
	mob.rotation = direction

	# Choose the velocity for the mob.
	var velocity = Vector2(randf_range(150.0, 250.0), 0.0)
	mob.linear_velocity = velocity.rotated(direction)

	# Spawn the mob by adding it to the Main scene.
	add_child(mob)
	mob.defeated.connect(_on_mob_defeated)

func _on_score_timer_timeout():
	score += 1
	$HUD.update_score(score)

func _on_mob_defeated():

	# Add a simple ingredient to the player's inventory. For now we
	# attribute all mob drops to "Sus Meat" so the cooking module has
	# something to consume. This can be refined later.
	player_inventory["Sus Meat"] = player_inventory.get("Sus Meat", 0) + 1

	# Update the visible ingredient count (sum of all ingredient types)
	ingredients = 0
	for v in player_inventory.values():
		ingredients += int(v)
	$HUD.update_ingredients(ingredients)
	GameManager.inventario_jogador = player_inventory.duplicate()

	# Small hunger refund on kill
	hunger += 5.0
	hunger = min(hunger, max_hunger)
	$HUD.update_hunger(hunger, max_hunger)

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
