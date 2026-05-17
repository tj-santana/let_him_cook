extends Node2D

var cliques: float = 0.0
var max_cliques: float = 15.0 # Tem que clicar 15 vezes em 5 segundos para nota máxima!

func _ready():
	# Prepara a barra de progresso no início
	$BarraProgresso.max_value = max_cliques
	$BarraProgresso.value = 0

func _on_botao_mexer_pressed():
	cliques += 1.0
	$BarraProgresso.value = cliques

func _on_tempo_jogo_timeout():
	# O tempo acabou! Vamos calcular a nota de 0.0 a 1.0
	var desempenho = cliques / max_cliques
	
	# Se o jogador clicou mais de 15 vezes, a nota não passa de 1.0 (100%)
	if desempenho > 1.0:
		desempenho = 1.0
		
	GameManager.registar_pontuacao_e_avancar(1.0)
