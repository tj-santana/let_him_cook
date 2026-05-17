extends Node2D

# --- REFERÊNCIAS AOS NÓS ---
# Garante que os nomes e pastas correspondem exatamente à tua cena!
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

func _ready():
	# 1. Esconder a zona verde logo no início! 
	# Agora é um teste cego baseado nas cores da panela.
	zona_verde.visible = false
	
	# 2. Configurar os limites do termómetro
	slider.min_value = 0
	slider.max_value = 100
	
	# 3. Escolher a temperatura ideal aleatória
	valor_alvo = randf_range(15.0, 85.0)
	
	# 4. GARANTIR QUE NÃO COMEÇAM NO MESMO SÍTIO!
	# Se o alvo for quente (mais de 50), começa no gelado (10)
	# Se o alvo for frio (menos de 50), começa no a ferver (90)
	if valor_alvo > 50.0:
		slider.value = 10.0
	else:
		slider.value = 90.0

# O _process corre dezenas de vezes por segundo para ler o termómetro
func _process(delta):
	# Se já ganhámos, ignora o resto do código para não estragar a vitória
	if jogo_ganho:
		return
		
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

func vencer_jogo():
	jogo_ganho = true
	
	# Mostra a glória do arco-íris
	arco_iris.visible = true
	print("SUCESSO! Sopa Vulcânica Perfeita!")
	
	GameManager.registar_pontuacao_e_avancar(1.0)
	
