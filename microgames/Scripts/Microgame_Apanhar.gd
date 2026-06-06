extends Node2D

@onready var barra_progresso = $ProgressBar
@onready var barra_tempo = $UI/BarraTempo
@onready var panela = $Panela
@onready var feedback_label = $UI/FeedbackLabel
@onready var help_label = $UI/TextoAjuda

var tempo_restante: float = 7.0
var jogo_ativo: bool = true
var progresso: float = 0.0
var progresso_max: float = 100.0

var spawn_timer: float = 0.0
var spawn_interval: float = 0.4

# Good ingredients pool (meats and veggies only)
var good_textures = [
	"res://microgames/Assets/Food/Isolated Food/sus_meat.tres",
	"res://microgames/Assets/Food/Isolated Food/BatCarne.tres",
	"res://microgames/Assets/Food/Isolated Food/orc_Meat.tres",
	"res://microgames/Assets/Food/Isolated Food/fish_meat.tres",
	"res://microgames/Assets/Food/Isolated Food/mush_meat.tres",
	"res://microgames/Assets/Food/Isolated Food/Big_Leaf.tres",
	"res://microgames/Assets/Food/Isolated Food/Carrots.tres",
	"res://microgames/Assets/Food/Isolated Food/Onion.tres",
	"res://microgames/Assets/Food/Isolated Food/Potatoe.tres",
	"res://microgames/Assets/Food/Isolated Food/Roots.tres",
	"res://microgames/Assets/Food/Isolated Food/garlic.tres",
	"res://microgames/Assets/Food/Isolated Food/lettuce.tres"
]

# Hazard textures (uses the fly asset!)
var hazard_texture = "res://microgames/Assets/mosca.png"

# Array to keep track of active falling items
var falling_items: Array = []

func _ready():
	barra_progresso.max_value = progresso_max
	barra_progresso.value = 0
	
	if barra_tempo:
		barra_tempo.max_value = tempo_restante
		barra_tempo.value = tempo_restante
		
	feedback_label.text = ""
	panela.global_position = Vector2(576.0, 560.0)

func _process(delta):
	if not jogo_ativo:
		return
		
	# Update timer
	tempo_restante -= delta
	if barra_tempo:
		barra_tempo.value = tempo_restante
		
	if tempo_restante <= 0:
		finalizar_jogo(progresso / progresso_max)
		return
		
	# Move the pot smoothly following the mouse X
	var target_x = clamp(get_global_mouse_position().x, 100.0, 1052.0)
	panela.global_position.x = lerp(panela.global_position.x, target_x, 0.25)
	
	# Spawn falling items
	spawn_timer += delta
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		_spawn_item()
		
	# Update and move all falling items
	_update_falling_items(delta)

func _spawn_item():
	var is_hazard = randf() < 0.35
	var x_pos = randf_range(150.0, 1000.0)
	
	var item_sprite = Sprite2D.new()
	item_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	if is_hazard:
		item_sprite.texture = load(hazard_texture)
		item_sprite.set_meta("is_hazard", true)
	else:
		var tex = good_textures.pick_random()
		item_sprite.texture = load(tex)
		item_sprite.set_meta("is_hazard", false)
		
	# Dynamically scale texture (flies are 130x130, ingredients are 100x100)
	var target_size = Vector2(130.0, 130.0) if is_hazard else Vector2(100.0, 100.0)
	if item_sprite.texture != null:
		var tex_size = item_sprite.texture.get_size()
		if tex_size.x > 0 and tex_size.y > 0:
			item_sprite.scale = Vector2(target_size.x / tex_size.x, target_size.y / tex_size.y)
			
	item_sprite.global_position = Vector2(x_pos, 50.0)
	add_child(item_sprite)
	falling_items.append(item_sprite)

func _update_falling_items(delta):
	var speed = 360.0
	var pot_y = panela.global_position.y
	var pot_x = panela.global_position.x
	var catch_radius_x = 48.0
	var catch_radius_y = 20.0
	
	var items_to_remove = []
	
	for item in falling_items:
		if not is_instance_valid(item):
			continue
			
		item.global_position.y += speed * delta
		
		# Check distance/catch
		var dist_x = abs(item.global_position.x - pot_x)
		var dist_y = abs(item.global_position.y - pot_y)
		
		if dist_y < catch_radius_y and dist_x < catch_radius_x:
			# Caught!
			items_to_remove.append(item)
			var is_hazard = item.get_meta("is_hazard")
			
			if is_hazard:
				# BAD! Caught a fly
				progresso = max(0.0, progresso - 25.0)
				_show_feedback("FLY IN THE SOUP!", Color.RED)
				_shake_pot()
			else:
				# GOOD! Caught an ingredient
				progresso = min(progresso_max, progresso + 20.0)
				_show_feedback("YUM!", Color.GREEN)
				_bounce_pot()
				
			barra_progresso.value = progresso
			
			if progresso >= progresso_max:
				finalizar_jogo(1.0)
				return
				
		elif item.global_position.y > 680.0:
			# Fell offscreen
			items_to_remove.append(item)
			
	for item in items_to_remove:
		falling_items.erase(item)
		item.queue_free()

func _show_feedback(text: String, color: Color):
	feedback_label.text = text
	feedback_label.self_modulate = color
	var tween = create_tween()
	tween.tween_property(feedback_label, "scale", Vector2(1.3, 1.3), 0.1)
	tween.tween_property(feedback_label, "scale", Vector2(1.0, 1.0), 0.1)

func _bounce_pot():
	var tween = create_tween()
	tween.tween_property(panela, "scale", Vector2(1.7, 1.2), 0.08)
	tween.tween_property(panela, "scale", Vector2(1.5, 1.5), 0.08)

func _shake_pot():
	var tween = create_tween()
	tween.tween_property(panela, "position:x", panela.position.x - 15, 0.05)
	tween.tween_property(panela, "position:x", panela.position.x + 15, 0.05)
	tween.tween_property(panela, "position:x", panela.position.x - 15, 0.05)
	tween.tween_property(panela, "position:x", panela.position.x, 0.05)

func finalizar_jogo(nota: float):
	jogo_off()
	
	if nota >= 1.0:
		_show_feedback("GREAT SOUP!", Color.GOLD)
		print("Catch microgame perfect! (+1.0 pt)")
	else:
		_show_feedback("TIME'S UP!", Color.CRIMSON)
		print("Catch microgame ended. Score: ", nota)
		
	await get_tree().create_timer(1.0).timeout
	GameManager.registar_pontuacao_e_avancar(nota)

func jogo_off():
	jogo_ativo = false
	for item in falling_items:
		if is_instance_valid(item):
			item.queue_free()
	falling_items.clear()
