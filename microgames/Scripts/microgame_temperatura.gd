extends Node2D

# --- REFERÊNCIAS AOS NÓS ---
@onready var zona_verde = $Fundo/BarraTemperatura/ZonaVerde
@onready var slider = $Fundo/BarraTemperatura/Slider
@onready var panela_visual = $PanelaVisual
@onready var fogo_visual = $FogoVisual
@onready var arco_iris = $ArcoIrisVisual
@onready var texto_ajuda = $UI/TextoAjuda
@onready var barra_tempo = $UI/BarraTempo

# --- VARIÁVEIS DO JOGO ---
var valor_alvo: float = 0.0
var margem_acerto: float = 5.0
var tempo_na_zona: float = 0.0 
var jogo_ganho: bool = false    

# --- NOVAS VARIÁVEIS DE TEMPO ---
var tempo_limite: float = 5.0
var tempo_restante: float = 5.0
var jogo_cancelado: bool = false

func _ready():
	# Começa o jogo com o tempo inicializado
	tempo_restante = tempo_limite
	
	# Prepara a barra visual de tempo
	barra_tempo.max_value = tempo_limite
	barra_tempo.value = tempo_restante
	
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
		
	# Chama a animação do texto do WarioWare!
	animar_texto()

# O _process corre dezenas de vezes por segundo para ler o termómetro
func _process(delta):
	if Input.is_action_just_pressed("escape"):
		cancelar_minijogo()
		return

	# Se já ganhámos ou perdemos, ignora o resto do código
	if jogo_ganho:
		return
		
	# --- GESTÃO DE TEMPO ---
	tempo_restante -= delta
	
	# Atualiza a barra verde no ecrã!
	barra_tempo.value = tempo_restante
	
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
	if jogo_cancelado:
		return
	
	# Mostra a glória do arco-íris
	arco_iris.visible = true
	
	var pontuacao_final: float = 0.0
	
	if tempo_restante >= 3.0:
		pontuacao_final = 1.0
		mostrar_arco_iris()
		print("Controlo Perfeito! Sobraram ", snapped(tempo_restante, 0.1), "s. (+1.0 pt)")
	else:
		pontuacao_final = 0.5
		mostrar_arco_iris()
		print("No limite! Sobraram ", snapped(tempo_restante, 0.1), "s. (+0.5 pts)")
	
	# Pausa de 1 segundo para o jogador festejar antes de mudar de cena
	await get_tree().create_timer(1.0).timeout
	if jogo_cancelado:
		return
	GameManager.registar_pontuacao_e_avancar(pontuacao_final)

func mostrar_arco_iris():
	arco_iris.visible = true
	
	# Coloca o arco-íris minúsculo no início
	arco_iris.scale = Vector2.ZERO 
	
	# Faz o arco-íris saltar e esticar com aquele efeito de mola brutal!
	var tween = create_tween()
	tween.tween_property(arco_iris, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_BOUNCE)
	
# --- CÁLCULO DE PONTUAÇÃO (DERROTA / TEMPO ESGOTADO) ---
func finalizar_por_tempo():
	jogo_ganho = true # Usamos a mesma variável para parar a lógica do _process
	if jogo_cancelado:
		return
	
	print("Tempo esgotado! A mistura arruinou-se! (+0.0 pts)")
	
	# Pausa de 1 segundo para o jogador perceber que perdeu antes de mudar
	await get_tree().create_timer(1.0).timeout
	if jogo_cancelado:
		return
	GameManager.registar_pontuacao_e_avancar(0.0)


func cancelar_minijogo() -> void:
	if jogo_cancelado:
		return

	jogo_cancelado = true
	jogo_ganho = true
	GameManager.cancelar_sequencia_minijogos()

# --- FUNÇÃO DE ANIMAÇÃO DO TEXTO ---
func animar_texto():
	# Centra o eixo do texto para ele crescer a partir do meio
	texto_ajuda.pivot_offset = texto_ajuda.size / 2
	texto_ajuda.scale = Vector2.ZERO
	
	var tween = create_tween()
	tween.tween_property(texto_ajuda, "scale", Vector2(1, 1), 0.3).set_trans(Tween.TRANS_BOUNCE)
	tween.tween_interval(1.0)
	tween.tween_property(texto_ajuda, "scale", Vector2.ZERO, 0.2)
