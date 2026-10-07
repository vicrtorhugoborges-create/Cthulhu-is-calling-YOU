class_name DocumentData
extends Resource
## Um documento legível (carta, jornal, manuscrito, diário de outra pessoa).
## Ler é opcional, mas alimenta o Conhecimento e o diário de Thurston.

enum Kind { TYPED, HANDWRITTEN, NEWSPAPER, TELEGRAM }

@export var id := ""
@export var title := ""
@export var kind := Kind.TYPED
## Cada item é uma página. Use [b], [i] e [center] (BBCode) se precisar.
@export_multiline var pages: PackedStringArray = []
## Quanto o Conhecimento sobe na primeira leitura.
@export_range(0.0, 20.0, 0.5) var knowledge := 4.0
## Entrada do diário acrescentada ao fechar o documento (id em DiaryEntries).
@export var diary_id := ""
## Fala de Thurston ao fechar o documento (id em NarrationLines).
@export var narration_after := ""
## Flag ligada ao terminar a leitura.
@export var sets_flag := ""
