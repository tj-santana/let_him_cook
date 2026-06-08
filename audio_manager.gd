extends Node


# Caching loaded audio streams
var _streams = {}
var _pool = []
var _pool_size = 12

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Create pool of players
	for i in range(_pool_size):
		var player = AudioStreamPlayer.new()
		add_child(player)
		_pool.append(player)
	
	# Auto-hook buttons
	get_tree().node_added.connect(_on_node_added)
	_register_existing_buttons(get_tree().root)

# Helper to find an idle player
func _get_idle_player() -> AudioStreamPlayer:
	for player in _pool:
		if not player.playing:
			return player
	# Fallback: steal the oldest playing player
	var oldest = _pool[0]
	return oldest

func play_sfx_path(path: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var stream = _streams.get(path)
	if stream == null:
		if ResourceLoader.exists(path):
			stream = load(path)
			_streams[path] = stream
		else:
			print("SFX not found: ", path)
			return
	
	var player = _get_idle_player()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()

# Button sound registers
func _register_existing_buttons(node: Node):
	if node is Button:
		_connect_button(node)
	for child in node.get_children():
		_register_existing_buttons(child)

func _on_node_added(node: Node):
	if node is Button:
		_connect_button.call_deferred(node)

func _connect_button(node: Button):
	if not node.pressed.is_connected(play_click):
		node.pressed.connect(play_click)
	if not node.mouse_entered.is_connected(_on_button_hover):
		node.mouse_entered.connect(_on_button_hover)

func _on_button_hover():
	play_sfx_path("res://assets/kenney_rpg-audio/Audio/metalClick.ogg", -12.0, 1.2)

# Specific helper methods for easy triggering
func play_footstep():
	var num = randi_range(0, 9)
	var path = "res://assets/kenney_rpg-audio/Audio/footstep0%d.ogg" % num
	play_sfx_path(path, -6.0, randf_range(0.9, 1.1))

func play_swing():
	var num = randi_range(1, 3)
	var path = "res://assets/kenney_rpg-audio/Audio/drawKnife%d.ogg" % num
	play_sfx_path(path, -3.0, randf_range(0.85, 1.15))

func play_slice():
	var suffix = "" if randf() < 0.5 else "2"
	var path = "res://assets/kenney_rpg-audio/Audio/knifeSlice%s.ogg" % suffix
	play_sfx_path(path, 0.0, randf_range(0.9, 1.1))

func play_chop():
	play_sfx_path("res://assets/kenney_rpg-audio/Audio/chop.ogg", 0.0, randf_range(0.95, 1.05))

func play_dash():
	var choice = randi_range(1, 5)
	var path = ""
	if choice <= 4:
		path = "res://assets/kenney_rpg-audio/Audio/cloth%d.ogg" % choice
	else:
		path = "res://assets/kenney_rpg-audio/Audio/clothBelt.ogg"
	play_sfx_path(path, -2.0, randf_range(1.0, 1.2))

func play_creak():
	var num = randi_range(1, 3)
	var path = "res://assets/kenney_rpg-audio/Audio/creak%d.ogg" % num
	play_sfx_path(path, 0.0, randf_range(0.9, 1.1))

func play_door_open():
	var num = randi_range(1, 2)
	var path = "res://assets/kenney_rpg-audio/Audio/doorOpen_%d.ogg" % num
	play_sfx_path(path, 0.0, randf_range(0.95, 1.05))

func play_door_close():
	var num = randi_range(1, 4)
	var path = "res://assets/kenney_rpg-audio/Audio/doorClose_%d.ogg" % num
	play_sfx_path(path, 0.0, randf_range(0.95, 1.05))

func play_coin():
	var suffix = "" if randf() < 0.5 else "2"
	var path = "res://assets/kenney_rpg-audio/Audio/handleCoins%s.ogg" % suffix
	play_sfx_path(path, 0.0, randf_range(0.9, 1.1))

func play_metal_pot():
	var num = randi_range(1, 3)
	var path = "res://assets/kenney_rpg-audio/Audio/metalPot%d.ogg" % num
	play_sfx_path(path, -4.0, randf_range(0.9, 1.1))

func play_click():
	play_sfx_path("res://assets/kenney_rpg-audio/Audio/metalClick.ogg", -4.0, randf_range(0.95, 1.05))

func play_enemy_hit(enemy_name: String):
	var path = ""
	var name_lower = enemy_name.to_lower()
	if "slime" in name_lower:
		path = "res://assets/kenney_rpg-audio/Audio/cloth3.ogg"
	elif "skeleton" in name_lower:
		path = "res://assets/kenney_rpg-audio/Audio/metalLatch.ogg"
	elif "bat" in name_lower:
		path = "res://assets/kenney_rpg-audio/Audio/cloth1.ogg"
	elif "orc" in name_lower:
		path = "res://assets/kenney_rpg-audio/Audio/dropLeather.ogg"
	elif "mimic" in name_lower:
		play_creak()
		return
	else:
		path = "res://assets/kenney_rpg-audio/Audio/cloth2.ogg"
	play_sfx_path(path, 0.0, randf_range(0.9, 1.1))
