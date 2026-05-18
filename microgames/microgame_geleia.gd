extends Node2D

var voltas_completas: int = 0
var voltas_necessarias: int = 5
var pontos_tocados: Array = [false, false, false, false]

# --- NOVAS VARIÁVEIS DE TEMPO E ESTADO ---
var tempo_limite: float = 10.0
var tempo_restante: float = 10.0
var jogo_ativo: bool = true

# Variável para o texto
@onready var texto_progresso = $TextoProgresso

# Opcional: Se quiseres mostrar o tempo no ecrã, podes criar uma Label "TextoTempo" na cena
# @onready var texto_tempo = $TextoTempo

func _ready():
	# Começa o jogo com o tempo e o texto inicializados
	tempo_restante = tempo_limite
	if texto_progresso:
		texto_progresso.text = "Mexidas: 0 / " + str(voltas_necessarias)

func _process(delta):
	# Se o jogo já acabou (ganhou ou perdeu), o tempo para de contar
	if not jogo_ativo:
		return
		
	# Reduz o tempo a cada frame
	tempo_restante -= delta
	
	# Opcional: Atualiza o ecrã com o tempo restante (descomenta se tiveres a Label)
	# if texto_tempo:
	# 	texto_tempo.text = "Tempo: " + str(snapped(tempo_restante, 0.1)) + "s"
		
	# Verifica se o tempo acabou
	if tempo_restante <= 0.0:
		tempo_restante = 0.0
		finalizar_por_tempo()

func tocar_ponto(indice: int):
	# Só regista toques se o jogo ainda estiver a decorrer
	if not jogo_ativo:
		return
		
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

# --- CÁLCULO DE PONTUAÇÃO (VITÓRIA) ---
func vencer_minijogo():
	jogo_ativo = false # Para o relógio e os cliques
	var pontuacao_final: float = 0.0
	
	if tempo_restante >= 5.0:
		pontuacao_final = 1.0 # Perfeito
		print("Perfeito! Sobraram ", snapped(tempo_restante, 0.1), "s. (+1.0 pt)")
	elif tempo_restante >= 2.0:
		pontuacao_final = 0.75 # Bom
		print("Muito Bem! Sobraram ", snapped(tempo_restante, 0.1), "s. (+0.75 pts)")
	else:
		pontuacao_final = 0.5 # À rasca
		print("Ufa! Sobraram apenas ", snapped(tempo_restante, 0.1), "s. (+0.5 pts)")
		
	GameManager.registar_pontuacao_e_avancar(pontuacao_final)

# --- CÁLCULO DE PONTUAÇÃO (DERROTA / TEMPO ESGOTADO) ---
func finalizar_por_tempo():
	jogo_ativo = false
	# Ganha 0.1 por cada volta completa
	var pontuacao_final: float = voltas_completas * 0.1 
	
	print("Tempo esgotado! Conseguiste ", voltas_completas, " mexidas. (+", pontuacao_final, " pts)")
	GameManager.registar_pontuacao_e_avancar(pontuacao_final)

# --- SINAIS DOS PONTOS ---
func _on_ponto_1_mouse_entered(): tocar_ponto(0)
func _on_ponto_2_mouse_entered(): tocar_ponto(1)
func _on_ponto_3_mouse_entered(): tocar_ponto(2)
func _on_ponto_4_mouse_entered(): tocar_ponto(3)
