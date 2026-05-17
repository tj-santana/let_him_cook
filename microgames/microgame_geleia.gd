extends Node2D

var voltas_completas: int = 0
var voltas_necessarias: int = 5
var pontos_tocados: Array = [false, false, false, false]

# Variável para o texto (garante que tens um nó Label chamado TextoProgresso na tua cena!)
@onready var texto_progresso = $TextoProgresso

func _ready():
	# Começa o jogo com o texto a zero
	if texto_progresso:
		texto_progresso.text = "Mexidas: 0 / " + str(voltas_necessarias)

func tocar_ponto(indice: int):
	# Só conta se estiveres a carregar no botão esquerdo do rato a mexer a colher!
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if not pontos_tocados[indice]:
			pontos_tocados[indice] = true
			verificar_volta_completa()

func verificar_volta_completa():
	# Se passou pelos 4 pontos (uma volta inteira)
	if pontos_tocados[0] and pontos_tocados[1] and pontos_tocados[2] and pontos_tocados[3]:
		voltas_completas += 1
		pontos_tocados = [false, false, false, false] # Reset imediato para a próxima volta
		
		# Atualiza o texto no ecrã
		if texto_progresso:
			texto_progresso.text = "Mexidas: " + str(voltas_completas) + " / " + str(voltas_necessarias)
		
		# Vê se já ganhou
		if voltas_completas >= voltas_necessarias:
			vencer_minijogo()

func vencer_minijogo():
	print("GELEIA PRONTA!")
	GameManager.registar_pontuacao_e_avancar(1.0)

# --- SINAIS DOS PONTOS ---
func _on_ponto_1_mouse_entered(): tocar_ponto(0)
func _on_ponto_2_mouse_entered(): tocar_ponto(1)
func _on_ponto_3_mouse_entered(): tocar_ponto(2)
func _on_ponto_4_mouse_entered(): tocar_ponto(3)
