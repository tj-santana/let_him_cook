extends Node2D

@onready var barra_tempo = $UI/BarraTempo
@onready var faca = $Faca
@onready var ingrediente = $Ingrediente
@onready var feedback_label = $UI/FeedbackLabel
@onready var progresso_label = $UI/ProgressoLabel

var tempo_restante: float = 7.0
var jogo_ativo: bool = true
var hits: int = 0
var hits_needed: int = 3
var direction: float = 1.0
var speed: float = 350.0

# Pool of textures to pick randomly for ingredients being chopped (meats and veggies only)
var texturas_comida = [
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

func _ready():
	# Choose a random food texture
	if texturas_comida.size() > 0:
		var tex_path = texturas_comida.pick_random()
		ingrediente.texture = load(tex_path)
		
	if barra_tempo:
		barra_tempo.max_value = tempo_restante
		barra_tempo.value = tempo_restante
		
	feedback_label.text = ""
	_update_progresso_label()
	
	# Position the knife at the center target X coordinate
	faca.global_position.x = 576.0 # Center of a standard 1152x648 viewport
	faca.global_position.y = 280.0
	ingrediente.global_position = Vector2(100.0, 380.0)

func _process(delta):
	if not jogo_ativo:
		return
		
	# Update timer
	tempo_restante -= delta
	if barra_tempo:
		barra_tempo.value = tempo_restante
		
	if tempo_restante <= 0:
		finalizar_jogo(float(hits) / float(hits_needed))
		return
		
	# Move the ingredient back and forth
	ingrediente.global_position.x += speed * direction * delta
	
	# Bounce off screen boundaries
	if ingrediente.global_position.x >= 1052.0:
		direction = -1.0
		ingrediente.global_position.x = 1052.0
	elif ingrediente.global_position.x <= 100.0:
		direction = 1.0
		ingrediente.global_position.x = 100.0

func _input(event):
	if not jogo_ativo:
		return
		
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		tentar_cortar()

func tentar_cortar():
	# Visual knife chop animation (quick drop and return)
	var tween = create_tween()
	tween.tween_property(faca, "global_position:y", 340.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(faca, "global_position:y", 280.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Check distance on X axis between ingredient and knife
	var distance = abs(ingrediente.global_position.x - faca.global_position.x)
	var perfect_zone = 45.0 # pixels tolerance
	
	if distance <= perfect_zone:
		# HIT!
		hits += 1
		_update_progresso_label()
		_show_feedback("PERFECT CHOP!", Color.GREEN)
		
		# Change ingredient visual state (e.g. scale or squish it temporarily)
		var scale_tween = create_tween()
		scale_tween.tween_property(ingrediente, "scale", Vector2(4.5, 1.5), 0.1)
		scale_tween.tween_property(ingrediente, "scale", Vector2(3.0, 3.0), 0.1)
		
		# Respawn ingredient on the opposite side to continue
		if hits < hits_needed:
			ingrediente.global_position.x = 100.0 if direction < 0 else 1052.0
			direction *= -1.0
			speed += 75.0 # Speed up slightly for the next hit!
			
			# Pick another random food texture for variety
			if texturas_comida.size() > 0:
				ingrediente.texture = load(texturas_comida.pick_random())
		else:
			finalizar_jogo(1.0)
	else:
		# MISS!
		_show_feedback("MISS!", Color.RED)
		tempo_restante = max(0.0, tempo_restante - 0.8) # Lose time penalty

func _show_feedback(text: String, color: Color):
	feedback_label.text = text
	feedback_label.self_modulate = color
	var label_tween = create_tween()
	label_tween.tween_property(feedback_label, "scale", Vector2(1.3, 1.3), 0.15)
	label_tween.tween_property(feedback_label, "scale", Vector2(1.0, 1.0), 0.15)

func _update_progresso_label():
	progresso_label.text = "Chops: %d/%d" % [hits, hits_needed]

func finalizar_jogo(nota: float):
	jogo_ativo = false
	if nota >= 1.0:
		_show_feedback("RECIPE READY!", Color.GOLD)
		print("Chop microgame perfect! (+1.0 pt)")
	else:
		_show_feedback("TIME'S UP!", Color.CRIMSON)
		print("Chop microgame ended. Score: ", nota)
		
	await get_tree().create_timer(1.0).timeout
	GameManager.registar_pontuacao_e_avancar(nota)
