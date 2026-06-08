extends Node

var cena_principal_path = "res://game_shell.tscn"

var limite_ingredientes: int = 2
var has_key = false

# --- NOVA LÓGICA DE SEQUÊNCIA ---
var fila_de_minijogos: Array = []
var total_minijogos_na_sequencia: int = 0
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


var collected_items: Array = []

func mark_item_collected(item_id: String) -> void:
	if not collected_items.has(item_id):
		collected_items.append(item_id)


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

func obter_jogo_preparacao(ingrediente: String) -> String:
	match ingrediente:
		"Slime":
			return "res://microgames/Cenas/Microgames/Microgame_Geleia.tscn"
		"Bat Wings", "Bat Meat":
			return "res://microgames/Cenas/Microgames/microgame_bat_carne.tscn"
		"Fish Meat":
			return "res://microgames/Cenas/Microgames/microgame_peixe.tscn"
		"Bones":
			return "res://microgames/Cenas/Microgames/Microgame_Bone.tscn"
		_:
			return "res://microgames/Cenas/Microgames/Microgame_Carne.tscn"

func iniciar_sequencia_minijogos(metodo: String = ""):
	pontuacao_total = 0.0 # Reinicia a pontuação
	sequencia_minijogos_cancelada = false
	metodo_atual = metodo
	
	fila_de_minijogos = []
	
	# 1. Preparação (moscas/limpeza) para os ingredientes escolhidos
	for ingrediente in ingredientes_atuais:
		var prep_game = obter_jogo_preparacao(ingrediente)
		if FileAccess.file_exists(prep_game) and not fila_de_minijogos.has(prep_game):
			fila_de_minijogos.append(prep_game)
			
	if fila_de_minijogos.is_empty():
		fila_de_minijogos.append("res://microgames/Cenas/Microgames/Microgame_Carne.tscn")
		
	# 2. Cortar
	var corte_game = "res://microgames/Cenas/Microgames/Microgame_Corte.tscn"
	if FileAccess.file_exists(corte_game):
		fila_de_minijogos.append(corte_game)
		
	# 3. Apanhar
	var apanhar_game = "res://microgames/Cenas/Microgames/Microgame_Apanhar.tscn"
	if FileAccess.file_exists(apanhar_game):
		fila_de_minijogos.append(apanhar_game)
		
	# 4. Temperatura
	var temp_game = "res://microgames/Cenas/Microgames/Microgame_Temperatura.tscn"
	if FileAccess.file_exists(temp_game):
		fila_de_minijogos.append(temp_game)
		
	# 5. Boil -> Stir (Geleia)
	if metodo == "Boil":
		var stir_game = "res://microgames/Cenas/Microgames/Microgame_Geleia.tscn"
		if FileAccess.file_exists(stir_game):
			fila_de_minijogos.append(stir_game)
			
	# 5b. Boil or Roast -> Flambe
	if metodo == "Boil" or metodo == "Roast":
		var flambe_game = "res://microgames/Cenas/Microgames/Microgame_Flambe.tscn"
		if FileAccess.file_exists(flambe_game):
			fila_de_minijogos.append(flambe_game)
			
	# 6. Slime -> Cozinhar
	if ingredientes_atuais.has("Slime"):
		var cozinhar_game = "res://microgames/Cenas/Microgames/Microgame_Cozinhar.tscn"
		if FileAccess.file_exists(cozinhar_game):
			fila_de_minijogos.append(cozinhar_game)
			
	total_minijogos_na_sequencia = fila_de_minijogos.size()
	print("[GameManager] Fila de minijogos gerada: ", fila_de_minijogos)
	
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
	var max_minijogos = float(max(1, total_minijogos_na_sequencia))
	var nota_media = pontuacao_total / max_minijogos
	print("Prato Terminado! Pontuação Total: ", nota_media * 100, "%")
	
	# 4. Descobre a Receita e os Buffs!
	print("Ingredientes usados: ", ingredientes_atuais)
	var prato_info = obter_prato_e_buffs(ingredientes_atuais)
	print("Informações do prato cozinhado: ", prato_info)
	var nome_prato = prato_info["nome"]
	print("Receita Cozinhada: ", nome_prato)
	
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
		if nota_media >= 0.8:
			vel += 100
			cooldown += 0.1
			dur *= 2.0
			vida += 10.0
			fome += 10.0
			nome_prato += " (★★★)"
		elif nota_media >= 0.5:
			nome_prato += " (★★)"
		else:
			vel = int(vel * 0.25)
			cooldown = 0.0
			dur *= 0.6
			vida = max(1.0, vida - 5.0)
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
	var texto_dos_buffs = "Hunger: +" + str(fome)
	if vida > 0:
		texto_dos_buffs += " | HP: +" + str(vida)
	if max_vida > 0:
		texto_dos_buffs += " | MaxHP: +" + str(max_vida)
	if vel > 0:
		texto_dos_buffs += " | Speed: +" + str(vel)
	if dano_causado > 0:
		texto_dos_buffs += " | Damage: +" + str(dano_causado)
	if dano_recebido < 1.0:
		texto_dos_buffs += " | Defense: +" + str(int((1.0 - dano_recebido) * 100)) + "%"
		
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
	# 1. Sus Meat + Sus Meat (The Carnivore)
	["Boil", "Sus Meat", "Sus Meat"]: "Suspicious Stew",
	["Fry", "Sus Meat", "Sus Meat"]: "Crispy Meat Bites",
	["Roast", "Sus Meat", "Sus Meat"]: "Charred Jerky",

	# 2. Slime + Slime (The Weird Alchemist)
	["Boil", "Slime", "Slime"]: "Slime Broth",
	["Fry", "Slime", "Slime"]: "Fried Jelly",
	["Roast", "Slime", "Slime"]: "Roasted Ooze",

	# 3. Moss + Moss (The Forager)
	["Boil", "Moss", "Moss"]: "Herbal Tea",
	["Fry", "Moss", "Moss"]: "Tempura Moss",
	["Roast", "Moss", "Moss"]: "Smoked Herbs",

	# 4. Sus Meat + Slime
	["Boil", "Slime", "Sus Meat"]: "Shady Jelly", 
	["Fry", "Slime", "Sus Meat"]: "Glazed Meatballs",
	["Roast", "Slime", "Sus Meat"]: "Sticky Kabob",

	# 5. Sus Meat + Moss
	["Boil", "Moss", "Sus Meat"]: "Hunter's Pot",
	["Fry", "Moss", "Sus Meat"]: "Herb-Crusted Cutlet",
	["Roast", "Moss", "Sus Meat"]: "Mossy Roast",

	# 6. Slime + Moss
	["Boil", "Moss", "Slime"]: "Swamp Soup",
	["Fry", "Moss", "Slime"]: "Crispy Algae",
	["Roast", "Moss", "Slime"]: "Baked Slime Cake",

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
			var metodo = chave[0] # O primeiro item da chave é o método
			var chave_ordenada = chave.duplicate()
			chave_ordenada.remove_at(0) # Remove o método para comparar só os ingredientes
			chave_ordenada.sort()
			if metodo == metodo_atual and ing_ordenados == chave_ordenada: # Compara só os ingredientes, ignorando o método
				nome_prato = livro_de_receitas[chave]
				break
				
	# Define os atributos base do prato
	var resultado = {
		"nome": nome_prato,
		"vida": 20.0,
		"max_vida": 10.0,
		"fome": 10.0,
		"velocidade": 0,
		"cooldown": 0.0,
		"duracao": 15.0,
		"dano_causado": 0.0,
		"dano_recebido": 1.0
	}
	
	match nome_prato:
		"Mistake":
		# Punishing, but heals 1 HP so it's not entirely useless
			resultado["vida"] = 1.0
			resultado["max_vida"] = 1.0
			resultado["fome"] = 1.0 

		# --- SOUPS & STEWS (BOIL) -> High HP & Hunger ---
		"Suspicious Stew":
			resultado["vida"] = 30.0
			resultado["max_vida"] = 20.0
			resultado["fome"] = 30.0
			resultado["duracao"] = 20.0
		"Hunter's Pot":
			resultado["vida"] = 25.0
			resultado["max_vida"] = 20.0
			resultado["fome"] = 25.0
			resultado["dano_recebido"] = 0.85 # 15% damage reduction
			resultado["duracao"] = 30.0
		"Swamp Soup":
			resultado["vida"] = 25.0
			resultado["max_vida"] = 20.0
			resultado["fome"] = 15.0
			resultado["velocidade"] = 20

		# --- FRIED FOODS (FRY) -> Speed & Cooldowns ---
		"Fried Jelly":
			resultado["vida"] = 10.0
			resultado["max_vida"] = 5.0
			resultado["fome"] = 15.0
			resultado["velocidade"] = 120
			resultado["cooldown"] = 0.15 # Fast attacks
			resultado["duracao"] = 15.0 # Short duration (sugar crash!)
		"Herb-Crusted Cutlet":
			resultado["vida"] = 20.0
			resultado["max_vida"] = 10.0
			resultado["fome"] = 25.0
			resultado["velocidade"] = 60
			resultado["cooldown"] = 0.1
			resultado["duracao"] = 25.0
		"Glazed Meatballs":
			resultado["vida"] = 15.0
			resultado["max_vida"] = 10.0
			resultado["fome"] = 10.0
			resultado["velocidade"] = 80
			resultado["cooldown"] = 0.1
			resultado["dano_causado"] = 5.0
			resultado["duracao"] = 20.0

		# --- ROASTED FOODS (ROAST) -> Damage & Duration ---
		"Charred Jerky":
			resultado["vida"] = 10.0 # Low HP
			resultado["max_vida"] = 5.0
			resultado["fome"] = 20.0
			resultado["dano_causado"] = 8.0 # High damage
			resultado["duracao"] = 60.0 # Lasts a full minute
		"Mossy Roast":
			resultado["vida"] = 25.0
			resultado["max_vida"] = 20.0
			resultado["fome"] = 30.0
			resultado["dano_causado"] = 5.0
			resultado["duracao"] = 45.0
		"Sticky Kabob":
			resultado["vida"] = 20.0
			resultado["max_vida"] = 10.0
			resultado["fome"] = 25.0
			resultado["dano_causado"] = 15.0
			resultado["velocidade"] = 30
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
