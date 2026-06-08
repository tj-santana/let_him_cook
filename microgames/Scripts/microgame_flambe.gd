extends Node2D

# --- REFERÊNCIAS AOS NÓS ---
@onready var panela_visual = $PanelaVisual
@onready var fogo_visual = $FogoVisual
@onready var tampa_visual = $TampaVisual
@onready var barra_tempo = $UI/BarraTempo
@onready var texto_ajuda = $UI/TextoAjuda
@onready var indicador_temp = $UI/Termometro/Indicador
@onready var zona_verde_ui = $UI/Termometro/ZonaVerde

# --- VARIÁVEIS DE CONFIGURAÇÃO ---
var min_y: float = 180.0 # Tampa totalmente levantada (oxigénio máximo)
var max_y: float = 350.0 # Tampa totalmente fechada (abafado)

var intensidade_fogo: float = 20.0 # Começa a 20%
var taxa_crescimento: float = 55.0 # Velocidade a que o fogo cresce sem tampa
var taxa_abafamento: float = 75.0 # Velocidade a que o fogo diminui tapado

var tempo_na_zona: float = 0.0
var tempo_limite: float = 5.0
var tempo_restante: float = 5.0

var jogo_ativo: bool = true
var jogo_ganho: bool = false
var jogo_cancelado: bool = false

# Dragging variables
var is_dragging: bool = false
var drag_offset_y: float = 0.0
var clank_cooldown: bool = false

func _ready():
	tempo_restante = tempo_limite
	if barra_tempo:
		barra_tempo.max_value = tempo_limite
		barra_tempo.value = tempo_restante
		
	# Coloca a tampa na posição inicial
	tampa_visual.global_position.y = min_y
	
	# Anima o texto de ajuda inicial
	animar_texto()

func _process(delta):
	if Input.is_action_just_pressed("escape"):
		cancelar_minijogo()
		return

	if not jogo_ativo:
		return

	# 1. Gestão do tempo
	tempo_restante -= delta
	if barra_tempo:
		barra_tempo.value = tempo_restante
		
	if tempo_restante <= 0.0:
		tempo_restante = 0.0
		finalizar_jogo(0.0, "Tempo esgotado! A comida arruinou-se!")
		return

	# 2. Atualizar posição da tampa se estiver a arrastar
	if is_dragging:
		var mouse_y = get_global_mouse_position().y
		tampa_visual.global_position.y = clamp(mouse_y - drag_offset_y, min_y, max_y)
		
		# Som de clank satisfatório ao bater na panela
		if tampa_visual.global_position.y >= max_y - 2.0:
			if not clank_cooldown:
				clank_cooldown = true
				var am = get_node_or_null("/root/AudioManager")
				if am:
					am.play_sfx_path("res://assets/kenney_rpg-audio/Audio/metalPot2.ogg", 2.0, randf_range(0.9, 1.1))
		else:
			clank_cooldown = false

	# 3. Lógica de intensidade do fogo
	# percent_open: 1.0 (aberto/alto), 0.0 (fechado/baixo)
	var percent_open = (max_y - tampa_visual.global_position.y) / (max_y - min_y)
	
	# O fogo cresce se estiver aberto, encolhe se estiver tapado
	var mudanca = (taxa_crescimento * percent_open - taxa_abafamento * (1.0 - percent_open)) * delta
	intensidade_fogo = clamp(intensidade_fogo + mudanca, 0.0, 100.0)

	# 4. Atualizar visual do fogo e da panela
	if intensidade_fogo <= 0.0:
		fogo_visual.visible = false
		finalizar_jogo(0.0, "O fogo apagou-se completamente!")
		return
	elif intensidade_fogo >= 100.0:
		fogo_visual.scale = Vector2(2.5, 2.5)
		finalizar_jogo(0.0, "O fogo explodiu! Queimaste a comida!")
		return
	else:
		fogo_visual.visible = true
		# Escala proporcional à intensidade
		var scale_factor = 0.3 + (intensidade_fogo / 100.0) * 1.5
		fogo_visual.scale = Vector2(scale_factor, scale_factor)

	# 5. Atualizar o termómetro UI
	# O termómetro vertical vai de Y=500 (intensidade 0) a Y=200 (intensidade 100)
	if indicador_temp:
		var termometro_min_y = 500.0
		var termometro_max_y = 200.0
		indicador_temp.global_position.y = termometro_min_y - (intensidade_fogo / 100.0) * (termometro_min_y - termometro_max_y)

	# 6. Avaliar se está na zona ideal (40% a 60%)
	if intensidade_fogo >= 40.0 and intensidade_fogo <= 60.0:
		# Na zona ideal! Feedback visual verde na panela
		panela_visual.modulate = Color(1.0, 1.0, 1.0)
		tempo_na_zona += delta
		if tempo_na_zona >= 1.5:
			finalizar_jogo(1.0, "Flambé Perfeito! Temperatura estabilizada!")
	else:
		# Fora da zona
		tempo_na_zona = 0.0
		if intensidade_fogo > 60.0:
			# Demasiado quente! Panela vermelha
			panela_visual.modulate = Color(1.0, 0.4, 0.4)
		else:
			# Demasiado frio! Panela azul
			panela_visual.modulate = Color(0.4, 0.6, 1.0)

func _input(event):
	if not jogo_ativo:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Verifica se clicou na tampa ou perto dela
			var mouse_pos = get_global_mouse_position()
			# A tampa tem cerca de 220px de largura e 40px de altura
			var dx = abs(mouse_pos.x - tampa_visual.global_position.x)
			var dy = abs(mouse_pos.y - tampa_visual.global_position.y)
			
			if dx < 120.0 and dy < 30.0:
				is_dragging = true
				drag_offset_y = mouse_pos.y - tampa_visual.global_position.y
				var am = get_node_or_null("/root/AudioManager")
				if am:
					am.play_sfx_path("res://assets/kenney_rpg-audio/Audio/metalClick.ogg", -4.0, 1.0)
		else:
			if is_dragging:
				is_dragging = false
				var am = get_node_or_null("/root/AudioManager")
				if am:
					am.play_sfx_path("res://assets/kenney_rpg-audio/Audio/metalLatch.ogg", -6.0, 1.1)

func finalizar_jogo(nota: float, mensagem: String):
	jogo_ativo = false
	print("[Flambe] ", mensagem, " Nota: ", nota)
	
	if nota == 1.0:
		_show_victory_feedback()
	else:
		_show_defeat_feedback()
		
	await get_tree().create_timer(1.2).timeout
	if jogo_cancelado:
		return
		
	if GameManager.total_minijogos_na_sequencia == 0:
		print("[Flambe] Individual Test Mode: Reloading scene.")
		get_tree().reload_current_scene()
		return
		
	GameManager.registar_pontuacao_e_avancar(nota)

func _show_victory_feedback():
	texto_ajuda.text = "PERFECT!"
	texto_ajuda.self_modulate = Color.GREEN
	texto_ajuda.scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(texto_ajuda, "scale", Vector2(1.2, 1.2), 0.3).set_trans(Tween.TRANS_BOUNCE)

func _show_defeat_feedback():
	texto_ajuda.text = "BURNT!" if intensidade_fogo >= 100.0 else "TOO COLD!"
	if intensidade_fogo <= 0.0:
		texto_ajuda.text = "OUT!"
	texto_ajuda.self_modulate = Color.RED
	texto_ajuda.scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(texto_ajuda, "scale", Vector2(1.2, 1.2), 0.3).set_trans(Tween.TRANS_BOUNCE)

func cancelar_minijogo() -> void:
	if jogo_cancelado:
		return
	jogo_cancelado = true
	jogo_ativo = false
	GameManager.cancelar_sequencia_minijogos()

func animar_texto():
	if texto_ajuda:
		texto_ajuda.pivot_offset = texto_ajuda.size / 2
		texto_ajuda.scale = Vector2.ZERO
		var tween = create_tween()
		tween.tween_property(texto_ajuda, "scale", Vector2(1, 1), 0.3).set_trans(Tween.TRANS_BOUNCE)
		tween.tween_interval(1.0)
		tween.tween_property(texto_ajuda, "scale", Vector2.ZERO, 0.2)
