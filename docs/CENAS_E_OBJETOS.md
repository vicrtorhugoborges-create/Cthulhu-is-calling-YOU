# Cenários e objetos

Lista de produção do jogo inteiro, a partir do [documento de design](GDD.md).
Estado: **cinza** = montado em cenário cinza e jogável · **rascunho** = existe mas simplificado ·
**falta** = ainda não existe.

## Prólogo — Os Papéis (Boston, inverno de 1926–27) · 8 min

Cena: `scenes/levels/prologue_thurston_room.tscn`. Estado: **cinza**.

| Objeto | Tipo | Estado |
|---|---|---|
| Quarto de Thurston (6 × 5 m), janela com chuva, cama, estante, cabideiro | cenário | cinza |
| Caixas de papéis do tio (6) e papéis soltos | cenário | cinza |
| Mesa com lampião (única luz forte) | cenário/luz | cinza |
| Carta do advogado | documento | cinza |
| Recorte do obituário de Angell | documento | cinza |
| Notas sobre os sonhos de Wilcox | documento | cinza |
| Chaveiro do tio (pega e vira flag) | examinável | cinza |
| Caixa trancada com tampa | uso | cinza |
| Baixo-relevo de argila (13 × 15 cm), verso com nome e data | examinável | cinza |
| Manuscrito "CTHULHU CULT" (4 páginas) | documento | cinza |
| O baixo-relevo muda de lugar na mesa | evento | cinza |
| Porta para Providence | saída | cinza |

## I — O Horror em Argila (Providence) · 15 min

| Cenário / objeto | Tipo | Estado |
|---|---|---|
| Ladeira do porto até a Williams Street; marinheiro que observa e some | cenário/evento | falta |
| Mural de recortes: ordenar relatos por data (23/3 a 2/4/1925) | quebra-cabeça | falta |
| Edifício Fleur-de-Lys: ateliê de Wilcox (`ch1_wilcox_atelier.tscn`) | cenário | cinza |
| Wilcox sentado, três blocos de fala | personagem | cinza (boneco provisório) |
| Esculturas que mudam de pose fora da vista (6) | evento | cinza |
| Estátua mórbida perto da janela | uso | cinza |
| Esboços da cidade na parede | documento | cinza |
| Visão de Wilcox: blocos titânicos, limo, "Cthulhu fhtagn" (`vision_wilcox.tscn`) | visão | cinza |
| Encaixar fragmentos do baixo-relevo | quebra-cabeça | falta |

## II — O Relato do Inspetor Legrasse (Nova Orleans, 1927) · 20 min

| Cenário / objeto | Tipo | Estado |
|---|---|---|
| Escritório de Legrasse | cenário | falta |
| Depoimento do velho Castro | documento | falta |
| Notas do congresso de St. Louis (1908) | documento | falta |
| Cilindro de fonógrafo com o canto | som/uso | falta |
| Estatueta de pedra verde-escura | examinável | falta |
| Visão do pântano em 1º/11/1907: ciprestes, musgo, tambores, clarão vermelho | visão | falta |
| Furtividade leve até a clareira (ser visto acorda e reinicia) | mecânica | falta |
| Clareira: fogueira em anel, monólito, culto girando; todos viram a cabeça | evento | falta |

## III — A Loucura Vinda do Mar · 20 min

| Cenário / objeto | Tipo | Estado |
|---|---|---|
| Depósito do museu de Paterson; Sydney Bulletin de 18/4/1925 forrando a prateleira | cenário/documento | falta |
| Viagem em cartas, telegramas e fotos (São Francisco, Dunedin, Auckland, Sydney) | documentos | falta |
| Oslo: a viúva de Johansen entrega o manuscrito | cenário | falta |
| Barco para Londres: ler com algodão nos ouvidos | cenário | falta |
| Manuscrito de Johansen e as coordenadas | documento/quebra-cabeça | falta |
| Visão de R'lyeh: ângulos côncavo/convexo, a porta começa a ceder, corte seco | visão | falta |
| Gotas d'água que perseguem Thurston (a partir daqui) | som | pronto (`Audio.set_drips`) |

## Ato final — O Chamado · 12 min

| Cenário / objeto | Tipo | Estado |
|---|---|---|
| Boston, 1927: Thurston escreve o relato e o quarto se deforma | cenário/evento | falta |
| Relato de Thurston (o texto que o jogador "escreve") | documento | falta |
| Barco parado a 47°9' S, 126°43' O (`finale_rlyeh.tscn`) | cenário | cinza |
| Rampa que parece subir mas desce | espaço impossível | cinza |
| Corredor maior por dentro do que por fora | espaço impossível | cinza |
| Platô, porta de um acre, pilares e cidadela | cenário | cinza |
| **O Julgamento** (56 s) | sequência | rascunho jogável |
| Silhueta de Cthulhu e garras (geradas por código) | modelo | rascunho |

## Sistemas e interface

| Item | Estado |
|---|---|
| Visual PS1 (320×240, tremor, afim, 15 bits + Bayer, neblina e luz por vértice) | pronto |
| Logo com letras trocando de caixa e tremendo | pronto (fonte do sistema) |
| Diário, documentos, legendas, dicas, ponto de mira | pronto |
| Conhecimento e as quatro faixas de corrupção | pronto |
| Fechar os olhos | pronto |
| Salvamento automático | pronto |
| Opções de conforto e acessibilidade | pronto |
| Aviso de fotossensibilidade na abertura | pronto |
| Sons: canto, coração, som maléfico, ambiências, passos | rascunhos gerados |
| Voz de Thurston gravada | falta |
| Modelos low-poly do Blender (substituir os blocos cinza) | falta |
