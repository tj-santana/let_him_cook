extends Node

var cena_principal_path = "res://game.tscn"

# --- NOVA LÓGICA DE SEQUÊNCIA ---
var fila_de_minijogos: Array = []
var pontuacao_total: float = 0.0

# Coloca aqui os caminhos EXATOS das tuas cenas
var todas_as_cenas_minijogos: Array = [
	"res://microgames/microgame_cozinhar.tscn", 
	"res://microgames/microgame_temperatura.tscn",
    "res://microgames/microgame_geleia.tscn"
]

func iniciar_sequencia_minijogos():
	pontuacao_total = 0.0 # Reinicia a pontuação
	
	# Aqui defines a ordem EXATA em que os minijogos vão ser jogados!
	# (Podes trocar a ordem destas 3 linhas como preferires)
	fila_de_minijogos = [
		"res://microgames/Microgame_Cozinhar.tscn",       # 1º Jogo
		"res://microgames/Microgame_Temperatura.tscn",    # 2º Jogo
		"res://microgames/Microgame_Geleia.tscn"          # 3º Jogo
	]
	
	# Arranca para o primeiro da lista
	avancar_para_proximo_minijogo()
	
	
func registar_pontuacao_e_avancar(nota: float):
	pontuacao_total += nota
	avancar_para_proximo_minijogo()

func avancar_para_proximo_minijogo():
	if fila_de_minijogos.size() > 0:
		# Tira o primeiro minijogo da fila e carrega-o
		var proxima_cena = fila_de_minijogos.pop_front() 
		get_tree().change_scene_to_file(proxima_cena)
	else:
		# A fila acabou! Volta para a cozinha
		print("Prato Terminado! Pontuação Total: ", pontuacao_total)
		get_tree().change_scene_to_file(cena_principal_path)
		
var ingredientes_atuais: Array = []
var desempenho_microgame: float = 0.0

# Estado reservado para salvar o estado da cena principal antes de abrir a cozinha
var estado_principal = null

# O NOSSO INVENTÁRIO
var inventario_jogador: Dictionary = {
	"Sus Meat": 5,
	"Slime": 5,
	"Essence": 5
}

# O NOSSO LIVRO DE RECEITAS
var livro_de_receitas: Dictionary = {
	["Slime", "Sus Meat"]: "Geleia Duvidosa",
	["Essence", "Sus Meat"]: "Guisado Arcano"
}

# Limpa os dados temporários da panela/microgame
func limpar_dados():
	ingredientes_atuais.clear()
	desempenho_microgame = 0.0


func guardar_estado_principal(state):
	estado_principal = state


func obter_estado_principal():
	return estado_principal


func limpar_estado_principal():
	estado_principal = null
