extends Node2D

@onready var barra_tempo = $UI/BarraTempo
@onready var texto_ajuda = $UI/TextoAjuda

@onready var linha_visual = $LinhaVisual
@onready var pasta_pontos = $PontosDeCorte

var tempo_limite: float = 10.0
var tempo_restante: float = 10.0
var jogo_ativo: bool = true

# Variáveis do Corte
var cortando: bool = false
var pontos_total: int = 0
var pontos_cortados: int = 0

func _ready():
	if barra_tempo:
		barra_tempo.max_value = tempo_limite
		barra_tempo.value = tempo_restante
		
	linha_visual.clear_points()
	
	# Agora apenas conta quantos pontos tens, sem ligar sinais!
	for ponto in pasta_pontos.get_children():
		if ponto is Area2D:
			pontos_total += 1

func _process(delta):
	if not jogo_ativo: return
	
	tempo_restante -= delta
	if barra_tempo: barra_tempo.value = tempo_restante
	
	if tempo_restante <= 0:
		finalizar_jogo(0.0)

	# --- A LÓGICA DE DESENHAR E CORTAR ---
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if not cortando:
			cortando = true
			linha_visual.clear_points()
			reiniciar_pontos() 
			
		linha_visual.add_point(linha_visual.get_local_mouse_position())
		
		# NOVA MAGIA: Mede a distância do rato a todos os pontos ativos!
		var pos_rato = get_global_mouse_position()
		for ponto in pasta_pontos.get_children():
			if ponto is Area2D and ponto.visible:
				# Se a distância entre o rato e o centro do ponto for menor que 30 pixeis, CORTA!
				if pos_rato.distance_to(ponto.global_position) < 30.0:
					cortar_ponto(ponto)
	else:
		if cortando:
			cortando = false
			linha_visual.clear_points()
			reiniciar_pontos()

# Nova função para registar o corte
func cortar_ponto(ponto: Area2D):
	ponto.visible = false 
	pontos_cortados += 1
	
	if pontos_cortados >= pontos_total:
		finalizar_jogo(1.0)

func reiniciar_pontos():
	pontos_cortados = 0
	for ponto in pasta_pontos.get_children():
		if ponto is Area2D:
			ponto.visible = true

func finalizar_jogo(nota):
	jogo_ativo = false
	if nota == 1.0:
		print("Corte perfeito! (+1.0 pt)")
	else:
		print("Fim do tempo! O corte não ficou concluído. (+0.0 pts)")
		
	await get_tree().create_timer(1.0).timeout
	GameManager.registar_pontuacao_e_avancar(nota)
