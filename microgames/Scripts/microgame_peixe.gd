extends Node2D

@onready var barra_progresso = $ProgressBar
@onready var barra_tempo = $UI/BarraTempo
@onready var faca = $Faca 

var progresso: float = 0.0
var progresso_max: float = 100.0 
var tempo_restante: float = 4.0
var jogo_ativo: bool = true
var rato_no_peixe: bool = false

func _ready():
	barra_progresso.max_value = progresso_max
	barra_progresso.value = 0
	
	if barra_tempo:
		barra_tempo.max_value = tempo_restante
		barra_tempo.value = tempo_restante

func _process(delta):
	if not jogo_ativo: 
		return
	
	# O tempo continua a descer, independentemente do rato
	tempo_restante -= delta
	if barra_tempo:
		barra_tempo.value = tempo_restante
	
	# A faca continua a seguir o rato no eixo X
	faca.global_position.x = get_global_mouse_position().x
			
	# Derrota por tempo
	if tempo_restante <= 0:
		finalizar_jogo(0.0)

# Usamos o _input para captar o movimento real e exato do rato
func _input(event):
	if not jogo_ativo:
		return
		
	# Só soma progresso se o rato se estiver efetivamente a mexer E dentro da área do osso
	if rato_no_peixe and event is InputEventMouseMotion:
		# event.relative.x diz-nos os píxeis exatos que o rato andou horizontalmente neste frame
		var movimento_rato = abs(event.relative.x)
		
		# Ajusta este multiplicador (0.1) consoante queiras que o progresso encha mais rápido ou devagar
		progresso += movimento_rato * 0.1 
		
		barra_progresso.value = progresso
		
		if progresso >= progresso_max:
			finalizar_jogo(1.0)

func finalizar_jogo(nota):
	jogo_ativo = false
	if nota == 1.0:
		print("Peixe escamado! (+1.0 pt)")
	else:
		print("Fim do tempo! Faltou escamar. (+0.0 pts)")
		
	# Uma pequena pausa para ver que acabou
	await get_tree().create_timer(1.0).timeout
	GameManager.registar_pontuacao_e_avancar(nota)

# --- FUNÇÕES DOS SINAIS DA ÁREA ---
func _on_peixe_area_mouse_entered():
	rato_no_peixe = true

func _on_peixe_area_mouse_exited():
	rato_no_peixe = false
