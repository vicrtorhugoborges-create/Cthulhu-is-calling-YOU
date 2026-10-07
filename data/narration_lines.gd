class_name NarrationLines
extends RefCounted
## Roteiro das falas (ver também docs/ROTEIRO.md).
##
## Regras do documento de design:
## - no máximo duas frases por vez, em tom de diário;
## - Thurston fala nas viradas, nunca para explicar a fase;
## - a narração começa racional e debochada e perde a segurança com o Conhecimento.
##
## Variantes por faixa de Conhecimento: "calm" (padrão), "uneasy" (51 ou mais),
## "shaken" (76 ou mais). "speaker" vazio = narração em off de Thurston.
## O teste tests/test_narration.gd garante o limite de duas frases.

const LINES := {
	# --- Abertura (tela preta, tradução da primeira frase do conto) ---
	"abertura": {"calm": "A coisa mais misericordiosa do mundo, penso eu, é a incapacidade da mente humana de correlacionar tudo o que contém."},

	# --- Prólogo: Os Papéis (Boston, inverno de 1926–27) ---
	"prologo_inicio": {"calm": "Caixas e mais caixas do tio-avô Angell. Como herdeiro e executor, cabe a mim pôr ordem nisso."},
	"prologo_carta": {"calm": "Uma caixa trancada, e ninguém sabe da chave. Bem típico do velho professor."},
	"prologo_obituario": {"calm": "Caiu na ladeira do porto depois de um esbarrão. Aos noventa e dois anos, o coração não aguentou."},
	"prologo_caixa_trancada": {"calm": "Trancada. O tio devia levar a chave consigo."},
	"prologo_chaves": {"calm": "O chaveiro que estava no bolso dele naquele dia. Uma destas há de servir."},
	"prologo_caixa_aberta": {"calm": "Um baixo-relevo de argila e um maço de papéis. Na capa, com a letra do tio: \"CTHULHU CULT\"."},
	"prologo_baixo_relevo": {
		"calm": "Uma figura monstruosa, de traço moderno, obra de algum artista febril. Não consigo decidir o que ela é.",
		"uneasy": "Não consigo decidir o que ela é. Quanto mais olho, menos quero olhar.",
	},
	"prologo_detalhe_relevo": {"calm": "Riscado no verso: \"H. A. Wilcox, 1º de março de 1925\"."},
	"prologo_manuscrito": {
		"calm": "Um homem de ciência acreditando nos sonhos de um escultor. O rapaz deve ter inventado tudo.",
		"uneasy": "Um homem de ciência acreditando nos sonhos de um escultor. Ou o rapaz inventou tudo, ou não inventou nada.",
	},
	"prologo_sonhos_wilcox": {"calm": "Febre de 23 de março a 2 de abril. Delírio de artista, nada mais."},
	"prologo_relevo_mudou": {"calm": "Eu o deixei ao lado da caixa. Tenho certeza de que o deixei ao lado da caixa."},
	"prologo_fim": {"calm": "Amanhã vou a Providence. Quero ouvir esse Wilcox com meus próprios ouvidos."},
	"prologo_porta_cedo": {"calm": "Ainda não. Primeiro os papéis do tio."},

	# --- Capítulo I: O Horror em Argila (ateliê no Fleur-de-Lys, Providence) ---
	"atelie_chegada": {"calm": "Edifício Fleur-de-Lys, Thomas Street. Um ninho de artistas com fachada de imitação francesa."},
	"atelie_desenhos": {"calm": "Esboços da mesma cidade, dezenas deles. Sempre os mesmos ângulos errados."},
	"atelie_estatua_mudou": {
		"calm": "Aquela estátua estava virada para a janela.",
		"uneasy": "Ela se mexeu. Eu sei que ela se mexeu.",
		"shaken": "Elas se mexem quando eu não olho. Então não vou piscar.",
	},
	"atelie_peca": {"calm": "A argila ainda parece úmida, depois de dois anos."},
	"atelie_fim": {"calm": "Os papéis do tio falam de um inspetor de Nova Orleans, Legrasse. É por aí que eu sigo."},
	"atelie_porta_cedo": {"calm": "Vim de Boston para ouvir esse homem. Não vou embora agora."},
	"wilcox_1": {"speaker": "Wilcox", "calm": "O professor Angell? Ele me ouvia como ninguém mais ouviu."},
	"wilcox_2": {"speaker": "Wilcox", "calm": "Fiz aquele baixo-relevo dormindo, na noite do tremor de terra. Acordei com as mãos sujas de argila."},
	"wilcox_3": {"speaker": "Wilcox", "calm": "A cidade do sonho é toda errada. A geometria não fecha, por mais que eu tente."},
	"wilcox_4": {"speaker": "Wilcox", "calm": "E havia uma voz que não era voz. Repetia sempre a mesma coisa."},
	"wilcox_5": {"speaker": "Wilcox", "calm": "A peça está ali, perto da janela. Toque, se quiser; eu não toco mais."},
	"wilcox_repete": {"speaker": "Wilcox", "calm": "Já lhe disse tudo o que sei. Agora me deixe trabalhar."},
	"wilcox_depois_visao": {"speaker": "Wilcox", "calm": "O senhor viu, não viu? Está na sua cara."},

	# --- Visão de Wilcox ---
	"visao_inicio": {"calm": "Pedra verde, maior que qualquer catedral. E o limo escorrendo, como se a pedra suasse."},
	"visao_voz": {"speaker": "…", "calm": "…Cthulhu fhtagn…"},
	"visao_despertar": {"calm": "Acordei no chão do ateliê, com o coração aos saltos. Wilcox nem tinha se levantado da cadeira."},

	# --- Ato final: O Chamado (R'lyeh, em sonho) ---
	"rlyeh_barco": {"calm": "O barco não se move. O mar está liso como vidro."},
	"rlyeh_coordenadas": {"calm": "Quarenta e sete graus e nove minutos sul, cento e vinte e seis e quarenta e três oeste. As coordenadas de Johansen."},
	"rlyeh_angulos": {"calm": "Subo, e a rampa me leva para baixo. Os ângulos aqui não obedecem."},
	"rlyeh_corredor": {"calm": "Este corredor era mais curto por fora. Eu tenho certeza."},
	"rlyeh_porta": {"calm": "A porta. Johansen viu esta porta."},

	# --- Sala de teste ---
	"teste_inicio": {"calm": "Sala de teste do visual PS1. Nada aqui é canônico."},
	"teste_documento": {"calm": "Papel, fonte de máquina e nenhuma pressa."},

	# --- Genéricas ---
	"porta_trancada": {"calm": "Trancada."},
}

## Linha que fecha o jogo depois do Julgamento (opcional, ver Settings.end_line).
const END_LINE := "Encontrado entre os papéis do falecido Francis Wayland Thurston, de Boston."


static func has_line(id: String) -> bool:
	return LINES.has(id)


static func get_speaker(id: String) -> String:
	return LINES.get(id, {}).get("speaker", "")


## Escolhe a variante pela faixa de Conhecimento (0..3).
static func pick(id: String, tier: int) -> String:
	var line: Dictionary = LINES.get(id, {})
	if line.is_empty():
		return ""
	if tier >= 3 and line.has("shaken"):
		return line["shaken"]
	if tier >= 2 and line.has("uneasy"):
		return line["uneasy"]
	return line.get("calm", "")


const _ABBREVIATIONS := ["sr.", "sra.", "dr.", "dra.", "prof.", "st.", "sto.", "sta.", "nº."]


## Quantas frases um texto tem (usado pelo teste das duas frases).
## Iniciais ("H. A. Wilcox") e abreviações não encerram frase.
static func count_sentences(text: String) -> int:
	var count := 0
	var pending := false
	for raw in text.strip_edges().split(" ", false):
		var core := raw.strip_edges().rstrip("\"'”»)").lstrip("\"'“«(")
		if core.replace("…", "").replace(".", "").is_empty():
			continue
		pending = true
		if core.ends_with(".") or core.ends_with("!") or core.ends_with("?") or core.ends_with("…"):
			var is_initial := core.length() == 2 and core[0] == core[0].to_upper() and core[0] != core[0].to_lower()
			if is_initial or _ABBREVIATIONS.has(core.to_lower()):
				continue
			count += 1
			pending = false
	if pending:
		count += 1
	return count
