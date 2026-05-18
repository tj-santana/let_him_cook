extends Node2D

var cliques: float = 0.0
var max_cliques: float = 15.0 # Tem que clicar 15 vezes em 3 segundos!

# --- NOVAS VARIÁVEIS DE TEMPO E ESTADO ---
var tempo_limite: float = 3.0
var tempo_restante: float = 3.0
var jogo_ativo: bool = true

func _ready():
	# Prepara a barra de progresso e o tempo no início
	tempo_restante = tempo_limite
	$BarraProgresso.max_value = max_cliques
	$BarraProgresso.value = 0

func _process(delta):
	# Se o jogo já acabou, o relógio para
	if not jogo_ativo:
		return
		
	# Reduz o tempo a cada frame
	tempo_restante -= delta
	
	# Se o tempo chegar ao fim, calcula a pontuação que o jogador conseguiu
	if tempo_restante <= 0.0:
		tempo_restante = 0.0
		finalizar_jogo()

func _on_botao_mexer_pressed():
	# Só deixa clicar se o jogo ainda estiver a decorrer
	if not jogo_ativo:
		return
		
	cliques += 1.0
	$BarraProgresso.value = cliques
	
	# Se o jogador chegou aos 100% (15 cliques), o jogo acaba imediatamente!
	if cliques >= max_cliques:
		finalizar_jogo()

func finalizar_jogo():
	jogo_ativo = false
	
	# Calcula a nota de 0.0 a 1.0 (ex: 12 cliques / 15 = 0.8)
	var desempenho = cliques / max_cliques
	
	# Garante que a nota não passa do máximo (1.0)
	if desempenho > 1.0:
		desempenho = 1.0
		
	# Mensagens na consola consoante a prestação
	if desempenho == 1.0:
		print("INCRÍVEL! 100% dos cliques atingidos com tempo de sobra! (+1.0 pt)")
	else:
		# Multiplica por 100 só para mostrar a percentagem de forma bonita no texto
		print("Fim do tempo! Conseguiste ", int(desempenho * 100), "% dos cliques. (+", snapped(desempenho, 0.01), " pts)")
		
	# Agora envia o desempenho real em vez de um "1.0" fixo!
	GameManager.registar_pontuacao_e_avancar(desempenho)
