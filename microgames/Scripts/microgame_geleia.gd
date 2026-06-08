extends Node2D

# --- REFERÊNCIAS ---
@onready var panela_visual = $PanelaVisual # O nó central da panela
@onready var barra_tempo = $UI/BarraTempo
@onready var texto_ajuda = $UI/TextoAjuda
@onready var conteudo_mistura = $PanelaVisual/ConteudoMistura # A tua imagem redonda da sopa!

# --- VARIÁVEIS DE TEMPO E ESTADO ---
var tempo_limite: float = 3.0
var tempo_restante: float = 4.0
var jogo_ativo: bool = true
var jogo_cancelado: bool = false

# --- VARIÁVEIS DA MISTURA ---
var voltas_necessarias: float = 7.0
var rotacao_acumulada: float = 0.0
var angulo_anterior: float = 0.0

func _ready():
	tempo_restante = tempo_limite
	if barra_tempo:
		barra_tempo.max_value = tempo_limite
		barra_tempo.value = tempo_restante
		
	animar_texto()
	
	# Regista onde o rato está logo no primeiro frame para não haver "saltos" bruscos
	var rato_pos = get_global_mouse_position()
	angulo_anterior = panela_visual.global_position.angle_to_point(rato_pos)

func _process(delta):
	if Input.is_action_just_pressed("escape"):
		cancelar_minijogo()
		return

	if not jogo_ativo:
		return
		
	# Gestão do tempo
	tempo_restante -= delta
	if barra_tempo:
		barra_tempo.value = tempo_restante
		
	if tempo_restante <= 0.0:
		tempo_restante = 0.0
		finalizar_jogo()

	# --- A MAGIA DE MEXER A PANELA ---
	
	# 1. Onde está o rato agora?
	var rato_pos = get_global_mouse_position()
	
	# 2. Qual é o ângulo do rato em relação ao centro da panela?
	var angulo_atual = panela_visual.global_position.angle_to_point(rato_pos)
	
	# 3. Calcula a diferença entre o ângulo de agora e o do frame anterior
	# O 'wrapf' é um truque para o Godot não se passar quando o ângulo salta de 360º para 0º
	var diferenca = wrapf(angulo_atual - angulo_anterior, -PI, PI)
	
	# 4. Acumula a rotação (usamos 'abs' para contar independentemente se o jogador roda para a esquerda ou direita)
	rotacao_acumulada += abs(diferenca)
	angulo_anterior = angulo_atual
	
	# BÓNUS VISUAL: Faz APENAS a sopa rodar fisicamente com o teu rato!
	conteudo_mistura.rotation += diferenca
	
	# 5. Verifica se ganhámos!
	# No Godot, uma volta completa é a constante matemática TAU (que é 2 * PI)
	var voltas_dadas = rotacao_acumulada / TAU
	
	if voltas_dadas >= voltas_necessarias:
		finalizar_jogo()

func finalizar_jogo():
	jogo_ativo = false
	if jogo_cancelado:
		return
	
	var voltas_dadas = rotacao_acumulada / TAU
	var desempenho = voltas_dadas / voltas_necessarias
	
	if desempenho > 1.0:
		desempenho = 1.0
		
	if desempenho == 1.0:
		print("PERFEITO! Misturaste tudo! (+1.0 pt)")
	else:
		print("Fim do tempo! Misturaste ", int(desempenho * 100), "%. (+", snapped(desempenho, 0.01), " pts)")
		
	await get_tree().create_timer(1.0).timeout
	if jogo_cancelado:
		return
		
	if GameManager.total_minijogos_na_sequencia == 0:
		print("[Geleia] Individual Test Mode: Reloading scene.")
		get_tree().reload_current_scene()
		return
		
	GameManager.registar_pontuacao_e_avancar(desempenho)


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
