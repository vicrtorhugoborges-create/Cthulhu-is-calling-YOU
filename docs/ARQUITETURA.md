# Arquitetura

Projeto Godot 4.7, renderizador **Compatibility** (OpenGL 3.3, roda em PCs modestos e no Linux), GDScript.

## Pastas

```
autoload/      sistemas globais (um por arquivo, registrados em project.godot)
data/          roteiro de falas, diário e documentos (.tres)
scenes/        main/ (cena principal), player/, levels/
scripts/       código das cenas: core/, player/, interaction/, world/, ui/, levels/, judgment/, data/
shaders/       visual PS1, céu, água, Cthulhu, pós-processo
materials/     materiais PS1 prontos (um por textura)
assets/        audio/draft, audio/final, textures/draft (rascunhos gerados por tools/)
tests/         testes (test_*.gd) e capturas de tela (capture.tscn)
tools/         geradores dos rascunhos de som e textura (Node.js, sem dependências)
```

## Como uma partida roda

`scenes/main/main.tscn` é a cena principal e nunca sai da tela:

```
Main
├── WorldContainer (SubViewportContainer, material = ps1_post)
│   └── WorldViewport (SubViewport 320x240)
│       └── LevelRoot ── o nível atual + o jogador
├── CorruptionDirector (efeitos do Conhecimento)
├── UI (CanvasLayer, base 640x480: legendas, diário, documentos, menus)
└── Fade (CanvasLayer acima de tudo)
```

O mundo 3D é desenhado em 320×240 e ampliado sem suavização. O pós-processo (`shaders/ps1_post.gdshader`)
roda sobre essa imagem pequena: cor de 15 bits com pontilhado, grão, vinheta, olhos fechados e o
escurecimento do mundo. A interface fica por cima, em resolução maior, para os textos serem legíveis.

Trocar de nível é `Game.load_level("prologo", "start")`: a tela escurece, o nível é instanciado em
`LevelRoot`, o jogador nasce no `Marker3D` do grupo `spawn` com aquele nome e o nível salva o ponto.
Rodar um nível pelo editor (F6) recarrega a cena principal com aquele nível.

## Autoloads

| Nome | Arquivo | Papel |
|---|---|---|
| `Settings` | `autoload/settings.gd` | opções de conforto (salvas em `user://settings.cfg`) e mapa de controles |
| `GameState` | `autoload/game_state.gd` | Conhecimento (0–100) e faixas, flags, diário, olhos fechados |
| `Audio` | `autoload/audio_director.gd` | barramentos, ambiências, canto ligado ao Conhecimento, coração, gotas, silêncio |
| `Narration` | `autoload/narration.gd` | fila de falas; escolhe a variante pela faixa; toca a gravação se existir |
| `SaveSystem` | `autoload/save_system.gd` | salvamento automático em `user://autosave.json` |
| `Game` | `autoload/game.gd` | fachada: níveis, documentos, cartões de texto, fluxo título/novo jogo/continuar |

## Peças para montar níveis

| Peça | Script | Para quê |
|---|---|---|
| `Level` | `scripts/world/level.gd` | raiz de todo nível: neblina, ambiência, canto, lampião, Conhecimento mínimo |
| `GrayBox` | `scripts/world/graybox.gd` | bloco de cenário cinza com malha subdividida e colisão; muda no Inspetor |
| `Statue` | `scripts/world/statue.gd` | escultura gerada por código, com poses e versão "mórbida" |
| `NpcFigure` | `scripts/world/npc_figure.gd` | personagem sentado que respira e acompanha o jogador a 12 fps |
| `ReadableDocument` | `scripts/interaction/readable_document.gd` | abre um `DocumentData` em tela cheia |
| `ExaminableItem` | `scripts/interaction/examinable_item.gd` | objeto que gira na mão; detalhe escondido; pode ser pego |
| `UseTarget` | `scripts/interaction/use_target.gd` | algo que exige uma flag (caixa trancada, porta) |
| `Talker` | `scripts/interaction/talker.gd` | personagem com blocos de falas |
| `LevelExit` | `scripts/interaction/level_exit.gd` | porta para outro nível |
| `StoryTrigger` | `scripts/world/story_trigger.gd` | volume que dispara silêncio, fala, diário, flag, Conhecimento, save |
| `ShiftyObject` | `scripts/world/shifty_object.gd` | muda pose ou lugar de um objeto quando ninguém olha |
| `TentacleShadowSpot` | `scripts/world/tentacle_shadow_spot.gd` | sombra de tentáculo na visão periférica (Conhecimento 51+) |
| `FogZone` | `scripts/world/fog_zone.gd` | neblina própria de um trecho |
| `CameraTiltZone` | `scripts/world/camera_tilt_zone.gd` | câmera inclinada: a rampa que parece subir mas desce |
| `ImpossibleCorridor` | `scripts/world/impossible_corridor.gd` | devolve o jogador sem emenda: corredor maior por dentro |
| `JudgmentSequence` | `scripts/judgment/judgment_sequence.gd` | os 56 segundos do Julgamento |

Interagíveis são `Area3D` na camada 3 com um `CollisionShape3D`. O raio de mira (1,8 m) parte da câmera.

## O Conhecimento

`GameState.add_knowledge(valor, fonte)` soma uma vez por fonte (ler o mesmo documento de novo não conta).
As faixas valem para todos os sistemas:

| Faixa | Conhecimento | Efeito | Onde |
|---|---|---|---|
| 0 | 0–25 | mundo normal | — |
| 1 | 26–50 | canto no limite da audição; objetos mudam fora da vista | `Audio.chant_params`, `ShiftyObject` |
| 2 | 51–75 | textura troca por um instante; sombras de tentáculo | `CorruptionDirector`, `TentacleShadowSpot` |
| 3 | 76–100 | geometria errada; narração abalada | `CorruptionDirector.distortion_for`, `NarrationLines.pick` |

Com os olhos fechados, `CorruptionDirector` zera as distorções e nada muda de lugar.

## Shaders e materiais

`shaders/ps1_common.gdshaderinc` concentra o tremor, a neblina por vértice e a "geometria errada". Os valores
globais (`ps1_jitter`, `ps1_fog_*`, `world_distortion`, `corruption_flash`) ficam em `project.godot`,
seção `[shader_globals]`. Os materiais de `materials/` usam `world_uv_density`: a textura é projetada pelo
mundo, então um `GrayBox` de qualquer tamanho fica com a textura na escala certa.

## Como acrescentar…

- **Uma fala**: em `data/narration_lines.gd`, com variantes `calm`/`uneasy`/`shaken` se quiser. No máximo duas frases.
- **Uma anotação de diário**: em `data/diary_entries.gd`; use o id em `diary_id` de documentos e gatilhos.
- **Um documento**: crie um `DocumentData` em `data/documents/<id>.tres` (o nome do arquivo é o id) e ponha um `ReadableDocument` na cena.
- **Um som**: ponha o arquivo em `assets/audio/final/` e chame `Audio.play_sfx("nome")`. Variações `nome_1`, `nome_2`… são sorteadas.
- **Um nível**: nova cena com raiz `Node3D` e script que estende `Level`; um `Marker3D` chamado `start` no grupo `spawn`; registre o id em `Game.LEVELS`.

Depois rode os testes: eles acusam falas, sons, diário, dicas e documentos citados que não existem.
