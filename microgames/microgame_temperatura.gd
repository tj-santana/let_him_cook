extends Node2D

# --- REFERÊNCIAS AOS NÓS ---
@onready var zona_verde = $Fundo/BarraTemperatura/ZonaVerde
@onready var slider = $Fundo/BarraTemperatura/Slider
@onready var panela_visual = $PanelaVisual
@onready var fogo_visual = $FogoVisual
@onready var arco_iris = $ArcoIrisVisual

# --- VARIÁVEIS DO JOGO ---
var valor_alvo: float = 0.0
var margem_acerto: float = 5.0 # Tamanho da zona verde (10% da barra)
var tempo_na_zona: float = 0.0  # Cronómetro de 1 segundo
var jogo_ganho: bool = false    

# --- NOVAS VARIÁVEIS DE TEMPO ---
var tempo_limite: float = 5.0
var tempo_restante: float = 5.0

func _ready():
	# Começa o jogo com o tempo inicializado
	tempo_restante = tempo_limite
	
	# 1. Esconder a zona verde logo no início! 
	# Agora é um teste cego baseado nas cores da panela.
	zona_verde.visible = false
	
	# 2. Configurar os limites do termómetro
	slider.min_value = 0
	slider.max_value = 100
	
	# 3. Escolher a temperatura ideal aleatória
	valor_alvo = randf_range(15.0, 85.0)
	
	# 4. GARANTIR QUE NÃO COMEÇAM NO MESMO SÍTIO!
	if valor_alvo > 50.0:
		slider.value = 10.0
	else:
		slider.value = 90.0

# O _process corre dezenas de vezes por segundo para ler o termómetro
func _process(delta):
	# Se já ganhámos ou perdemos, ignora o resto do código
	if jogo_ganho:
		return
		
	# --- GESTÃO DE TEMPO ---
	tempo_restante -= delta
	
	if tempo_restante <= 0.0:
		tempo_restante = 0.0
		finalizar_por_tempo()
		return # Sai do _process para não continuar a avaliar as cores
		
	# --- 1. A MAGIA DO TAMANHO DO FOGO ---
	var percentagem_fogo = slider.value / 100.0
	var tamanho_minimo = 0.5 # Tamanho do fogo no frio máximo
	var tamanho_maximo = 2.5 # Tamanho do fogo no calor máximo
	
	# Calcula a escala horizontal
	var escala_atual = tamanho_minimo + (percentagem_fogo * (tamanho_maximo - tamanho_minimo))
	
	# Muda apenas o eixo X (horizontal) e mantém o Y (altura) a 1.0 (tamanho original)
	fogo_visual.scale = Vector2(escala_atual, 1.0)
	
	# --- 2. A MAGIA DAS CORES DA PANELA ---
	var diferenca = slider.value - valor_alvo
	var limite = margem_acerto / 2.0 
	
	if diferenca > limite:
		# DEMASIADO QUENTE!
		panela_visual.modulate = Color(1.0, 0.2, 0.2) # Vermelho
		tempo_na_zona = 0.0 # Zera o cronómetro
		
	elif diferenca < -limite:
		# DEMASIADO FRIO!
		panela_visual.modulate = Color(0.2, 0.5, 1.0) # Azul
		tempo_na_zona = 0.0 # Zera o cronómetro
		
	else:
		# PERFEITO! NA ZONA VERDE!
		panela_visual.modulate = Color(1.0, 1.0, 1.0) # Cor original
		tempo_na_zona += delta # Adiciona milissegundos ao cronómetro
		
		# Se aguentou 1 segundo inteiro na temperatura certa...
		if tempo_na_zona >= 1.0:
			vencer_jogo()

# --- CÁLCULO DE PONTUAÇÃO (VITÓRIA) ---
func vencer_jogo():
	jogo_ganho = true
	
	# Mostra a glória do arco-íris
	arco_iris.visible = true
	
	var pontuacao_final: float = 0.0
	
	if tempo_restante >= 3.0:
		pontuacao_final = 1.0
		print("Controlo Perfeito! Sobraram ", snapped(tempo_restante, 0.1), "s. (+1.0 pt)")
	else:
		pontuacao_final = 0.5
		print("No limite! Sobraram ", snapped(tempo_restante, 0.1), "s. (+0.5 pts)")
	
	GameManager.registar_pontuacao_e_avancar(pontuacao_final)

# --- CÁLCULO DE PONTUAÇÃO (DERROTA / TEMPO ESGOTADO) ---
func finalizar_por_tempo():
	jogo_ganho = true # Usamos a mesma variável para parar a lógica do _process
	
	print("Tempo esgotado! A mistura arruinou-se! (+0.0 pts)")
	GameManager.registar_pontuacao_e_avancar(0.0)
