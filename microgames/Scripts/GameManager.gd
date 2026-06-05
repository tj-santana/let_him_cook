extends Node

var cena_principal_path = "res://game_shell.tscn"

# --- NOVA LÓGICA DE SEQUÊNCIA ---
var fila_de_minijogos: Array = []
var pontuacao_total: float = 0.0
var sequencia_minijogos_cancelada := false
var popup_ativo := false
var buff_pendente = false
var buff_velocidade = 0
var buff_cooldown = 0.0
var buff_duracao = 0.0
var buff_fome: float = 0.0
var buff_vida_recuperada: float = 0.0
var buff_max_vida_recuperada: float = 0.0
var buff_dano_causado: float = 0.0
var buff_dano_recebido: float = 1.0


# O NOSSO LIVRO DE RECEITAS DESBLOQUEADAS
var receitas_desbloqueadas: Array = []
var pratos_cozinhados: Array = []

# Métodos de Culinária e os seus respetivos microgames
var microgames_boil: Array = [
	"res://microgames/Cenas/Microgames/Microgame_Cozinhar.tscn",
	"res://microgames/Cenas/Microgames/Microgame_Temperatura.tscn",
	"res://microgames/Cenas/Microgames/Microgame_Apanhar.tscn"
]
var microgames_fry: Array = [
	"res://microgames/Cenas/Microgames/Microgame_Geleia.tscn",
	"res://microgames/Cenas/Microgames/microgame_peixe.tscn",
	"res://microgames/Cenas/Microgames/Microgame_Bone.tscn",
	"res://microgames/Cenas/Microgames/Microgame_Corte.tscn"
]
var microgames_roast: Array = [
	"res://microgames/Cenas/Microgames/Microgame_Carne.tscn",
	"res://microgames/Cenas/Microgames/Microgame_Bat_Wing.tscn",
	"res://microgames/Cenas/Microgames/microgame_bat_carne.tscn",
	"res://microgames/Cenas/Microgames/Microgame_Corte.tscn"
]
var metodo_atual: String = ""

# Coloca aqui os caminhos EXATOS das tuas cenas
var todas_as_cenas_minijogos: Array = [
	"res://microgames/Cenas/Microgames/Microgame_Cozinhar.tscn",
	"res://microgames/Cenas/Microgames/Microgame_Temperatura.tscn",
	"res://microgames/Cenas/Microgames/Microgame_Geleia.tscn",
	"res://microgames/Cenas/Microgames/Microgame_Carne.tscn",
	"res://microgames/Cenas/Microgames/Microgame_Corte.tscn",
	"res://microgames/Cenas/Microgames/Microgame_Apanhar.tscn"
]


func obter_cena_cozinha_principal() -> String:
	var caminho_novo = "res://microgames/Cenas/CozinhaPrincipal.tscn"
	if FileAccess.file_exists(caminho_novo):
		return caminho_novo
	var caminho_antigo = "res://microgames/Cenas/CozinhaPrincipal.tscn"
	if FileAccess.file_exists(caminho_antigo):
		return caminho_antigo
	return caminho_novo


func obter_fila_minijogos_disponiveis() -> Array:
	var fila: Array = []
	for caminho in todas_as_cenas_minijogos:
		if FileAccess.file_exists(caminho) and not fila.has(caminho):
			fila.append(caminho)
	return fila

func iniciar_sequencia_minijogos(metodo: String = ""):
	pontuacao_total = 0.0 # Reinicia a pontuação
	sequencia_minijogos_cancelada = false
	metodo_atual = metodo
	
	var todas_cenas = []
	if metodo == "boil":
		todas_cenas = microgames_boil
	elif metodo == "fry":
		todas_cenas = microgames_fry
	elif metodo == "roast":
		todas_cenas = microgames_roast
	else:
		todas_cenas = todas_as_cenas_minijogos
		
	# CRIAR A FILA: Copiamos apenas as cenas válidas para a fila
	fila_de_minijogos = []
	for caminho in todas_cenas:
		if FileAccess.file_exists(caminho) and not fila_de_minijogos.has(caminho):
			fila_de_minijogos.append(caminho)
	
	# Arranca para o primeiro da lista
	avancar_para_proximo_minijogo()
	
func devolver_ingredientes_para_inventario(ingredientes: Array) -> void:
	if typeof(ingredientes) != TYPE_ARRAY:
		return

	for ingrediente in ingredientes:
		if typeof(ingrediente) != TYPE_STRING:
			continue
		inventario_jogador[ingrediente] = inventario_jogador.get(ingrediente, 0) + 1


func cancelar_sequencia_minijogos() -> void:
	if sequencia_minijogos_cancelada:
		return

	sequencia_minijogos_cancelada = true
	devolver_ingredientes_para_inventario(ingredientes_atuais)
	limpar_dados()
	fila_de_minijogos.clear()
	pontuacao_total = 0.0
	get_tree().change_scene_to_file(obter_cena_cozinha_principal())


func registar_pontuacao_e_avancar(nota: float):
	if sequencia_minijogos_cancelada:
		return

	pontuacao_total += nota
	avancar_para_proximo_minijogo()


func avancar_para_proximo_minijogo():
	if sequencia_minijogos_cancelada:
		return

	if fila_de_minijogos.size() > 0:
		# Tira o primeiro minijogo da FILA e carrega-o
		var proxima_cena = fila_de_minijogos.pop_front() 
		get_tree().change_scene_to_file(proxima_cena)
	else:
		# A fila acabou! Volta para a cozinha e mostra o Popup
		print("Prato Terminado! Pontuação Total: ", pontuacao_total)
		get_tree().change_scene_to_file(obter_cena_cozinha_principal())
		mostrar_popup_resultado()

# --- A TUA NOVA FUNÇÃO DO POPUP ---
func mostrar_popup_resultado():
	# 1. Carrega a cena do Popup (Atenção: verifica se este caminho está correto no teu projeto!)
	var cena_popup = load("res://microgames/Cenas/popup_receita.tscn")
	var popup = cena_popup.instantiate()
	popup_ativo = true
	
	# 2. Cria uma "Camada Superior" para o popup ficar por cima de tudo na cozinha
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	canvas.add_child(popup)
	add_child(canvas) # Fica guardado no GameManager
	
	# 3. Calcula a nota média (Pontuação a dividir pelo nº total de jogos da receita)
	var max_minijogos = todas_as_cenas_minijogos.size()
	if metodo_atual == "boil":
		max_minijogos = microgames_boil.size()
	elif metodo_atual == "fry":
		max_minijogos = microgames_fry.size()
	elif metodo_atual == "roast":
		max_minijogos = microgames_roast.size()
		
	var nota_media = pontuacao_total / float(max_minijogos)
	
	# 4. Descobre a Receita e os Buffs!
	var prato_info = obter_prato_e_buffs(ingredientes_atuais)
	var nome_prato = prato_info["nome"]
	
	var vel = prato_info["velocidade"]
	var cooldown = prato_info["cooldown"]
	var dur = prato_info["duracao"]
	var fome = prato_info["fome"]
	var vida = prato_info["vida"]
	var max_vida = prato_info["max_vida"]
	var dano_causado = prato_info["dano_causado"]
	var dano_recebido = prato_info["dano_recebido"]
	
	# Ajusta os buffs consoante a nota média
	if nome_prato != "Mistake":
		if nota_media >= 2.5:
			vel += 100
			cooldown += 0.1
			dur *= 2.0
			vida += 10.0
			fome += 10.0
			nome_prato += " (★★★)"
		elif nota_media >= 1.5:
			nome_prato += " (★★)"
		else:
			vel = int(vel * 0.5)
			cooldown = 0.0
			dur *= 0.6
			vida = max(1.0, vida - 10.0)
			fome = max(1.0, fome - 5.0)
			nome_prato += " (★)"
			
	# Desbloqueia a receita se não for Mistake e ainda não estiver desbloqueada (com o nome base)
	var nome_limpo = prato_info["nome"]
	if nome_limpo != "Mistake" and not receitas_desbloqueadas.has(nome_limpo):
		receitas_desbloqueadas.append(nome_limpo)
		print("Desbloqueaste a receita: ", nome_limpo)
		
	# Adiciona o prato ao inventário de cozinhados do GameManager
	var novo_prato = {
		"nome": nome_prato,
		"velocidade": vel,
		"cooldown": cooldown,
		"duracao": dur,
		"fome": fome,
		"vida": vida,
		"max_vida": max_vida,
		"dano_causado": dano_causado,
		"dano_recebido": dano_recebido
	}
	pratos_cozinhados.append(novo_prato)
	print("Prato cozinhado guardado no inventário: ", novo_prato)
			
	# 5. Formata o texto dos Buffs para mostrar na UI
	var texto_dos_buffs = "Fome: +" + str(fome)
	if vida > 0:
		texto_dos_buffs += " | Vida: +" + str(vida)
	if max_vida > 0:
		texto_dos_buffs += " | MaxHP: +" + str(max_vida)
	if vel > 0:
		texto_dos_buffs += " | Vel: +" + str(vel)
	if dano_causado > 0:
		texto_dos_buffs += " | Dano: +" + str(dano_causado)
	if dano_recebido < 1.0:
		texto_dos_buffs += " | Def: +" + str(int((1.0 - dano_recebido) * 100)) + "%"
		
	# 6. Manda as informações todas para o script do teu Popup
	popup.mostrar_resultado(nome_prato, nota_media, texto_dos_buffs, true)
	
	# 7. Quando o jogador clicar em "Delicioso!", apagamos o popup inteiro
	popup.botao_continuar.pressed.connect(func(): canvas.queue_free())
	popup.botao_continuar.pressed.connect(func(): popup_ativo = false)
	
	# Limpa a panela para a próxima receita
	limpar_dados()
	
var ingredientes_atuais: Array = []
var desempenho_microgame: float = 0.0

# Estado reservado para salvar o estado da cena principal antes de abrir a cozinha
var estado_principal = null

# O NOSSO INVENTÁRIO
var inventario_jogador: Dictionary = {
	"Sus Meat": 5,
	"Bat Wings": 5,
	"Bat Meat": 5,
	"Fish Meat": 5,
	"Bones": 5,
	"Spider Eyes": 5,
	"Mush Meat": 5,
	"Orc Meat": 5,
	"Mimic Eye": 5,
	"Mimic Tongue": 5,
	"Big Leaf": 5,
	"Roots": 5,
	"Moss": 5,
	"Carrots": 5,
	"Potatoes": 5,
	"Onions": 5,
	"Garlic": 5,
	"Cabbage": 5,
	"Lettuce": 5,
	"Broccoli": 5,
	"Apple": 5,
	"Bread": 5,
	"Slime": 5,
	"Poison Sacs": 5,
	"Ectoplasm": 5,
	"Edible Coins": 5,
	"Essence": 5
}

# O NOSSO LIVRO DE RECEITAS
var livro_de_receitas: Dictionary = {
	["Slime", "Sus Meat"]: "Shady Jelly",
	["Essence", "Sus Meat"]: "Arcane Roast",
	["Sus Meat", "Sus Meat"]: "Suspicious Stew",
	["Bat Wings", "Bat Wings"]: "Roasted Bat Wings",
	["Bones", "Bones"]: "Bone Broth",
	["Mimic Eye", "Any", "Any", "Any"]: "Mimic Eye Rock Soup",
	["Mimic Tongue", "Any", "Any", "Any"]: "Mimic Tongue Picanha"
}

func obter_prato_e_buffs(ingredientes: Array) -> Dictionary:
	var ing_ordenados = ingredientes.duplicate()
	ing_ordenados.sort()
	
	var nome_prato = "Mistake"
	
	# Verifica regras especiais primeiro
	if ing_ordenados.size() == 4 and ing_ordenados.has("Mimic Eye"):
		nome_prato = "Mimic Eye Rock Soup"
	elif ing_ordenados.size() == 4 and ing_ordenados.has("Mimic Tongue"):
		nome_prato = "Mimic Tongue Picanha"
	else:
		# Procura por combinação exata no livro
		for chave in livro_de_receitas.keys():
			var chave_ordenada = chave.duplicate()
			chave_ordenada.sort()
			if ing_ordenados == chave_ordenada:
				nome_prato = livro_de_receitas[chave]
				break
				
	# Define os atributos base do prato
	var resultado = {
		"nome": nome_prato,
		"vida": 20.0,
		"max_vida": 0.0,
		"fome": 10.0,
		"velocidade": 100,
		"cooldown": 0.05,
		"duracao": 15.0,
		"dano_causado": 0.0,
		"dano_recebido": 1.0
	}
	
	match nome_prato:
		"Mistake":
			resultado["vida"] = 1.0
			resultado["max_vida"] = 1.0
			resultado["fome"] = 1.0
			resultado["velocidade"] = 0
			resultado["cooldown"] = 0.0
			resultado["duracao"] = 0.0
		"Mimic Eye Rock Soup":
			resultado["vida"] = 30.0
			resultado["fome"] = 25.0
			resultado["velocidade"] = 50
			resultado["cooldown"] = 0.0
			resultado["duracao"] = 45.0
			resultado["dano_recebido"] = 0.3 # 70% de redução de dano!
		"Mimic Tongue Picanha":
			resultado["vida"] = 30.0
			resultado["fome"] = 25.0
			resultado["velocidade"] = 80
			resultado["cooldown"] = 0.15 # Menos 0.15s cooldown
			resultado["duracao"] = 45.0
			resultado["dano_causado"] = 20.0 # +20 de dano!
		"Roasted Bat Wings":
			resultado["velocidade"] = 120
			resultado["cooldown"] = 0.08
			resultado["duracao"] = 20.0
		"Bone Broth":
			resultado["vida"] = 40.0
			resultado["fome"] = 20.0
			resultado["duracao"] = 15.0
		"Shady Jelly":
			resultado["velocidade"] = 150
			resultado["cooldown"] = 0.1
			resultado["duracao"] = 25.0
		"Arcane Roast":
			resultado["velocidade"] = 180
			resultado["cooldown"] = 0.12
			resultado["duracao"] = 30.0
		"Suspicious Stew":
			resultado["vida"] = 50.0
			resultado["fome"] = 30.0
			resultado["duracao"] = 20.0
			
	return resultado

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

# Helper to set a pending buff from microgames and log for debugging
func aplicar_buff(velocidade: int, cooldown: float, duracao: float, fome: float = 0.0) -> void:
	buff_pendente = true
	buff_velocidade = int(velocidade)
	buff_cooldown = float(cooldown)
	buff_duracao = float(duracao)
	buff_fome = float(fome)
	buff_vida_recuperada = 20.0
	buff_max_vida_recuperada = 0.0
	buff_dano_causado = 0.0
	buff_dano_recebido = 1.0
	print("[GameManager] aplicar_buff called. Pending buff set -> vel:", buff_velocidade, ", cooldown:", buff_cooldown, ", dur:", buff_duracao, ", fome:", buff_fome)

func aplicar_buff_detalhado(velocidade: int, cooldown: float, duracao: float, fome: float, vida: float, max_vida: float, dano_causado: float, dano_recebido: float) -> void:
	buff_pendente = true
	buff_velocidade = int(velocidade)
	buff_cooldown = float(cooldown)
	buff_duracao = float(duracao)
	buff_fome = float(fome)
	buff_vida_recuperada = float(vida)
	buff_max_vida_recuperada = float(max_vida)
	buff_dano_causado = float(dano_causado)
	buff_dano_recebido = float(dano_recebido)
	print("[GameManager] aplicar_buff_detalhado called -> vel:", buff_velocidade, ", cooldown:", buff_cooldown, ", dur:", buff_duracao, ", fome:", buff_fome, ", vida:", buff_vida_recuperada, ", max_vida:", buff_max_vida_recuperada, ", dano:", buff_dano_causado, ", dano_rec:", buff_dano_recebido)
