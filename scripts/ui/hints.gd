class_name Hints
extends RefCounted
## Dicas de controle discretas, mostradas uma única vez cada (não há HUD).
## Podem ser desligadas nas opções.

const TEXT := {
	"move": "WASD — andar   ·   mouse — olhar",
	"examine": "E ou clique — examinar",
	"read": "E ou clique — ler",
	"talk": "E ou clique — conversar",
	"door": "E ou clique — usar",
	"use": "E ou clique — usar",
	"rotate": "mova o mouse para girar   ·   E ou clique direito — largar",
	"document": "clique ou D — próxima página   ·   A — voltar   ·   Esc — fechar",
	"diary": "Tab — diário",
	"close_eyes": "segure Espaço — fechar os olhos",
	"sprint": "Shift — correr (por pouco tempo)",
	"crouch": "Ctrl — agachar",
}


static func text(id: String) -> String:
	return TEXT.get(id, "")
