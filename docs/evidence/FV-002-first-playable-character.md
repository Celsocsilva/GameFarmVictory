# FV-002 — primeiro personagem controlável

- Branch: feature/FV-002-first-playable-character
- Escopo: FarmWorld 3D, Farmer CharacterBody3D, câmera elevada, terreno, limites, cerca, árvore, construção e joystick virtual.
- Engine: Godot 4.7.2.stable.official.ed1daf0bf

## Implementado

- Movimento 360 graus no plano XZ com acceleration/deceleration em _physics_process(delta).
- Teclado pelas ações ui_* para teste no editor.
- Joystick touchscreen com zona morta, base/knob desenhados e saída fixa no viewport.
- CharacterBody3D com colisões e rotação acompanhando a direção.
- Câmera suave acompanhando o personagem.
- Terreno gramado e quatro limites físicos.
- Obstáculos físicos: cerca, árvore e construção.

## Validação executada

- Godot editor headless/import: PASS.
- FarmWorld headless por 2 segundos: PASS; sem erros críticos reportados.
- Teste automatizado de orquestração: PASS.
- Execução gráfica F5 no checkout correto: PASS; screenshot capturado nesta revisão mostrando terreno, personagem, câmera, obstáculos e joystick.
- Movimento visual por teclado no editor: PASS; personagem deslocou-se e a câmera acompanhou.
- Aproximação visual ao prédio: PASS; personagem permaneceu separado do obstáculo, sem atravessá-lo durante o teste.

## Não executado

- Toque em Android real ou emulador: não executado.
- APK: não gerado; export templates e configuração Android ainda não foram verificados.
- Screenshot/gravação: não disponível nesta execução headless.

## Limitações

O joystick foi implementado para entrada real de InputEventScreenTouch/InputEventScreenDrag e possui caminho de mouse para teste no editor. A confirmação ergonômica em 16:9, 19.5:9 e 20:9 depende de execução visual em dispositivo. A captura gráfica desta revisão foi feita na janela DEBUG Godot em 1280x720.
