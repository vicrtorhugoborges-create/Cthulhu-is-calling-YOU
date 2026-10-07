class_name DiaryEntries
extends RefCounted
## Anotações à mão do diário de Thurston. Funcionam como lista de objetivos sem HUD:
## uma entrada aberta é uma pista a seguir; riscada, uma pista resolvida.

const TEXT := {
	# Prólogo
	"d_organizar": "Pôr ordem nos papéis do tio-avô Angell.",
	"d_morte_angell": "O tio caiu na ladeira entre o porto e a Williams Street, depois de esbarrar num marinheiro. \"Coração fraco\", disseram.",
	"d_caixa": "Abrir a caixa trancada do tio. A chave deve estar entre os pertences que ele levava no dia.",
	"d_chaves": "Achei o chaveiro do tio.",
	"d_wilcox_nome": "Verso do baixo-relevo: H. A. Wilcox, 1º de março de 1925.",
	"d_culto": "\"CTHULHU CULT\". O tio colecionava sonhos de estranhos. Procurar Wilcox no Edifício Fleur-de-Lys, Thomas Street, Providence.",
	"d_sonhos_wilcox": "Wilcox delirou de febre de 23 de março a 2 de abril de 1925.",
	"d_relevo_mexeu": "O baixo-relevo não estava onde eu o deixei. Cansaço, só pode ser.",
	# Capítulo I
	"d_wilcox_falar": "Ouvir Wilcox sobre o sonho.",
	"d_wilcox_peca": "Wilcox não toca mais na peça perto da janela. Por quê?",
	"d_estatuas": "As estátuas do ateliê. Não olhar para elas não ajuda.",
	"d_visao": "Eu vi a cidade. Não estava dormindo.",
	"d_legrasse": "Próximo passo: os papéis sobre o inspetor Legrasse, de Nova Orleans.",
	# Ato final
	"d_coordenadas": "47°9' S, 126°43' O.",
	# Sala de teste
	"d_teste": "Sala de teste: girar objetos, ler, fechar os olhos.",
}

## Estado mental de Thurston no topo do diário, por faixa de Conhecimento.
const MOOD := [
	"Cético. Cansado de papelada.",
	"Durmo mal. Sonhos de que não me lembro.",
	"Ouço coisas no limite da audição. Não conto a ninguém.",
	"Sei demais. Já não consigo dormir.",
]


static func text(id: String) -> String:
	return TEXT.get(id, "")


static func mood(tier: int) -> String:
	return MOOD[clampi(tier, 0, MOOD.size() - 1)]
