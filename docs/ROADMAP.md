# Roadmap

Fases do [documento de design](GDD.md), para uma pessoa em meio período.

## Pré-produção (2 semanas): **feita, em rascunho**

Os "Próximos passos" do documento:

- [x] Logo com as letras trocando de caixa (`scripts/ui/logo_label.gd`)
- [x] Confirmar o motor (Godot 4.7) e testar o shader PS1 numa sala de teste (`ps1_test_room.tscn`)
- [x] Montar em cenário cinza os aposentos de Thurston e o ateliê de Wilcox
- [x] Modelar a silhueta de Cthulhu e testar o Julgamento cedo (gerada por código; falta o modelo do Blender)
- [x] Rascunhos do canto, do coração e do som maléfico (sintetizados; falta gravar de verdade)
- [x] Roteiro das falas da fatia vertical ([ROTEIRO.md](ROTEIRO.md)) e lista de cenários e objetos ([CENAS_E_OBJETOS.md](CENAS_E_OBJETOS.md))

## Teste do final (1 semana, cedo): **rascunho pronto para jogar**

O Julgamento roda do começo ao fim no platô (F8 ou Capítulos → O Julgamento).
Precisa de 3 a 5 pessoas jogando para validar o ritmo:

- Os 12 segundos do olhar pesam ou cansam?
- Dá para sentir que o botão de fechar os olhos falhou? (Hoje ele simplesmente não responde, como pede o documento.)
- O coração parando aos 40 s é percebido?
- Alguém fica frustrado por não poder reagir? Se sim, reforçar o corpo frágil e as visões que cortam antes do clímax.

## Fatia vertical (4 semanas): Prólogo e Capítulo I completos

- [ ] Ladeira do porto (Providence) com o marinheiro que observa e some
- [ ] Mural de recortes: ordenar os relatos por data (até 5 minutos)
- [ ] Modelos low-poly no Blender para o quarto, o ateliê, Wilcox e as esculturas
- [ ] Gravar a voz de Thurston (ids das falas em [ROTEIRO.md](ROTEIRO.md); arquivos em `assets/audio/final/voice/`)
- [ ] Gravar ou refinar canto, coração, chuva e passos (`assets/audio/final/`)
- [ ] Fontes livres incluídas no projeto (máquina de escrever e letra à mão)
- [ ] Texturas desenhadas à mão (Krita ou Aseprite) no lugar dos rascunhos gerados
- [ ] Tela de pausa com "Continuar do último ponto"

## Produção (4 a 5 meses)

- [ ] Capítulo II — Legrasse: escritório, fonógrafo, estatueta e a visão do pântano com furtividade leve
- [ ] Capítulo III — o museu de Paterson, as cartas da viagem, Oslo, o barco e a visão de R'lyeh
- [ ] Ato final — o quarto de Boston que se deforma enquanto Thurston escreve, ligando ao sonho de R'lyeh
- [ ] Modelo de Cthulhu no Blender (até 3.000 triângulos), mantendo a regra: nunca cabe no quadro

## Polimento e testes (3 a 4 semanas)

- [ ] 5 a 10 jogadores de teste; medir a duração (meta: 60 a 90 minutos)
- [ ] Ritmo dos sustos (no máximo três de volume no jogo inteiro)
- [ ] Acessibilidade: tamanho da legenda, remapear controles na tela de opções
- [ ] Exportar para Windows e Linux e publicar no itch.io (excluir `tests/` da exportação)

## Escopo mínimo, se faltar tempo

Prólogo, Capítulo I e Ato final, cerca de 30 minutos. Os capítulos II e III viram documentos e uma única
visão curta do pântano. O que já existe aqui cobre boa parte disso em cenário cinza.
