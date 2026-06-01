extends Node2D

@export var cena_da_mosca: PackedScene
@export var numero_de_moscas: int = 5 

var min_x = 400
var max_x = 750
var min_y = 150
var max_y = 450

var moscas_restantes = 0

# --- AS REFERÊNCIAS À TUA UI ---
@onready var texto_ajuda = $UI/TextoAjuda
@onready var barra_tempo = $UI/BarraTempo
@onready var arco_iris = $ArcoIrisVisual

# --- VARIÁVEIS DE TEMPO ---
var tempo_maximo = 5.0
var tempo_atual = 5.0
var jogo_ativo = true # Para o tempo parar quando ganhas ou perdes
var jogo_cancelado := false

func _ready():
	moscas_restantes = numero_de_moscas
	tempo_atual = tempo_maximo
	
	# Prepara a barra de tempo visualmente
	barra_tempo.max_value = tempo_maximo
	barra_tempo.value = tempo_atual
	
	for i in range(numero_de_moscas):
		spawn_mosca()
		
	animar_texto()

# O Godot chama esta função dezenas de vezes por segundo
func _process(delta):
	if Input.is_action_just_pressed("escape"):
		cancelar_minijogo()
		return

	if jogo_ativo:
		# Subtrai o tempo que passou e atualiza a barra verde
		tempo_atual -= delta
		barra_tempo.value = tempo_atual
		
		# Se a barra chegar a zero, acabou o tempo!
		if tempo_atual <= 0:
			perdeu_jogo()

func perdeu_jogo():
	jogo_ativo = false
	if jogo_cancelado:
		return
	print("Tempo esgotado! A carne ficou cheia de moscas...")
	
	# Dá 0 pontos e avança para o próximo minijogo
	GameManager.registar_pontuacao_e_avancar(0.0)

func ganhou_jogo():
	jogo_ativo = false
	if jogo_cancelado:
		return
	mostrar_arco_iris()
	print("Sucesso! Carne limpa a tempo!")
	
	# Dá 1 ponto e avança para o próximo minijogo
	await get_tree().create_timer(1.5).timeout
	if jogo_cancelado:
		return
	GameManager.registar_pontuacao_e_avancar(1.0)


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
	texto_ajuda.pivot_offset = texto_ajuda.size / 2
	texto_ajuda.scale = Vector2.ZERO
	
	var tween = create_tween()
	tween.tween_property(texto_ajuda, "scale", Vector2(1, 1), 0.3).set_trans(Tween.TRANS_BOUNCE)
	tween.tween_interval(1.0)
	tween.tween_property(texto_ajuda, "scale", Vector2.ZERO, 0.2)

func spawn_mosca():
	var nova_mosca = cena_da_mosca.instantiate()
	var x_aleatorio = randf_range(min_x, max_x)
	var y_aleatorio = randf_range(min_y, max_y)
	nova_mosca.position = Vector2(x_aleatorio, y_aleatorio)
	nova_mosca.input_event.connect(_on_mosca_clicada.bind(nova_mosca))
	add_child(nova_mosca)

func _on_mosca_clicada(viewport, event, shape_idx, mosca_clicada):
	# O clique só funciona se o jogo ainda estiver a contar o tempo
	if jogo_ativo and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		mosca_clicada.queue_free()
		moscas_restantes -= 1
		
		if moscas_restantes <= 0:
			ganhou_jogo()
