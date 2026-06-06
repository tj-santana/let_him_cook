extends Node2D

# --- REFERÊNCIAS AOS NÓS ---
@onready var barra_progresso = $BarraProgresso 
@onready var barra_tempo = $UI/BarraTempo
@onready var texto_ajuda = $UI/TextoAjuda         
@onready var slime_visual = $SlimeArea/Slime
@onready var arco_iris = $ArcoIrisVisual 

var cliques: float = 0.0
var max_cliques: float = 15.0 # Tem de clicar 15 vezes em 3 segundos!

# --- VARIÁVEIS DE TEMPO E ESTADO ---
var tempo_limite: float = 3.0
var tempo_restante: float = 3.0
var jogo_ativo: bool = true
var jogo_cancelado: bool = false

func _ready():
	tempo_restante = tempo_limite
	
	# Prepara a barra de progresso (cliques)
	barra_progresso.max_value = max_cliques
	barra_progresso.value = 0
	
	# Prepara a barra de tempo (verde)
	barra_tempo.max_value = tempo_limite
	barra_tempo.value = tempo_restante
		
	animar_texto()
	
func _process(delta):
	if Input.is_action_just_pressed("escape"):
		cancelar_minijogo()
		return

	if not jogo_ativo:
		return
		
	# Reduz o tempo
	tempo_restante -= delta
	
	# Atualiza a barra verde no fundo do ecrã (agora sem o 'if')
	barra_tempo.value = tempo_restante
	
	if tempo_restante <= 0.0:
		tempo_restante = 0.0
		finalizar_jogo()

# --- A NOVA FUNÇÃO DE CLIQUE NO SLIME ---
func _on_slime_area_input_event(_viewport, event, shape_idx):
	if not jogo_ativo:
		return
		
	# Deteta o clique esquerdo do rato
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		cliques += 1.0
		barra_progresso.value = cliques
		
		# Efeito visual de amassar o slime
		amassar_slime()
		
		if cliques >= max_cliques:
			finalizar_jogo()

func amassar_slime():
	# Cancela animações anteriores para não bugar se o jogador clicar muito rápido
	var tween = create_tween()
	
	# O slime encolhe na vertical e estica na horizontal (Squish!)
	tween.tween_property(slime_visual, "scale", Vector2(1.2, 0.8), 0.05)
	
	# Volta ao tamanho normal (Bounce)
	tween.tween_property(slime_visual, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_BOUNCE)

func finalizar_jogo():
	jogo_ativo = false
	if jogo_cancelado:
		return
	
	var desempenho = cliques / max_cliques
	if desempenho > 1.0:
		desempenho = 1.0
		
	if desempenho == 1.0:
		print("INCRÍVEL! Massa perfeita! (+1.0 pt)")
		mostrar_arco_iris()
	else:
		print("Fim do tempo! Conseguiste ", int(desempenho * 100), "% da massa. (+", snapped(desempenho, 0.01), " pts)")
		
	await get_tree().create_timer(1.5).timeout
	if jogo_cancelado:
		return
	GameManager.registar_pontuacao_e_avancar(desempenho)


func cancelar_minijogo() -> void:
	if jogo_cancelado:
		return

	jogo_cancelado = true
	jogo_ativo = false
	GameManager.cancelar_sequencia_minijogos()

func mostrar_arco_iris():
	arco_iris.visible = true
	
	# Coloca o arco-íris minúsculo no início
	arco_iris.scale = Vector2.ZERO 
	
	# Faz o arco-íris saltar e esticar com aquele efeito de mola brutal!
	var tween = create_tween()
	tween.tween_property(arco_iris, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_BOUNCE)
	
func animar_texto():
	if texto_ajuda:
		texto_ajuda.pivot_offset = texto_ajuda.size / 2
		texto_ajuda.scale = Vector2.ZERO
		var tween = create_tween()
		tween.tween_property(texto_ajuda, "scale", Vector2(1, 1), 0.3).set_trans(Tween.TRANS_BOUNCE)
		tween.tween_interval(1.0)
		tween.tween_property(texto_ajuda, "scale", Vector2.ZERO, 0.2)
