extends Node2D

@onready var barra_progresso = $ProgressBar
@onready var barra_tempo = $UI/BarraTempo
@onready var faca = $Faca 

var progresso: float = 0.0
var progresso_max: float = 100.0 
var tempo_restante: float = 4.0
var jogo_ativo: bool = true

# A NOSSA NOVA VARIÁVEL (O Interruptor)
var rato_no_osso: bool = false

func _ready():
	barra_progresso.max_value = progresso_max
	barra_progresso.value = 0
	
	if barra_tempo:
		barra_tempo.max_value = tempo_restante
		barra_tempo.value = tempo_restante

func _process(delta):
	if not jogo_ativo: 
		return
	
	# O tempo continua a descer, quer estejas no osso ou não
	tempo_restante -= delta
	if barra_tempo:
		barra_tempo.value = tempo_restante
	
	# A faca continua a seguir o rato no eixo X
	var mouse_x = get_global_mouse_position().x
	faca.global_position.x = mouse_x
	
	# SÓ SOMA PROGRESSO SE O RATO ESTIVER EM CIMA DO OSSO!
	if rato_no_osso:
		var velocidade_rato = abs(Input.get_last_mouse_velocity().x)
		progresso += velocidade_rato * delta * 0.02
		
		barra_progresso.value = progresso
		
		if progresso >= progresso_max:
			finalizar_jogo(1.0)
			
	# Derrota por tempo
	if tempo_restante <= 0:
		finalizar_jogo(0.0)

func finalizar_jogo(nota):
	jogo_ativo = false
	if nota == 1.0:
		print("Osso bem afiado! (+1.0 pt)")
	else:
		print("Fim do tempo! Faltou afiar. (+0.0 pts)")
		
	# Uma pequena pausa para ver que acabou
	await get_tree().create_timer(1.0).timeout
	GameManager.registar_pontuacao_e_avancar(nota)

# --- FUNÇÕES DOS SINAIS DA ÁREA ---
func _on_osso_area_mouse_entered():
	rato_no_osso = true

func _on_osso_area_mouse_exited():
	rato_no_osso = false
