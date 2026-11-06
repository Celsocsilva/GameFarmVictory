# TerraBela Farm — Definição da colheita de tomates (FV-HARVEST-001)

## Loop de gameplay
1. Personagem entra no alcance de uma célula `RIPE` de tomate.
2. O `HarvestController` verifica espaço disponível na mochila e reserva os frutos que podem ser coletados.
3. A planta fica em estado `HARVESTING`, sem permitir uma segunda coleta simultânea.
4. Um número limitado de tomates visuais se desprende da planta e percorre um arco de atração até `HarvestIntakeMarker` na mochila, acompanhando a posição atual do personagem enquanto ele caminha.
5. Ao completar a animação, confirmar as unidades no inventário, atualizar visual da pilha de caixas e consumir somente a quantidade reservada de frutos na célula.
6. A planta passa para `HARVESTED` ao esgotar seus frutos; a lógica de novo plantio é de outro sistema. Se a capacidade lotar no meio da colheita, os frutos restantes continuam disponíveis.
7. Com sete caixas completas, suspender novas coletas e orientar o jogador a descarregar na bancada (integração futura).

## Parâmetros iniciais — calibrar com câmera real
| Campo | Valor de teste | Descrição |
| --- | --- | --- |
| `harvest_radius` | 1.25 × distância entre centros de células | Raio de ativação, em unidades do mundo. |
| `harvest_interval` | 0.12 s | Intervalo mínimo entre as novas reservas. |
| `flight_duration` | 0.35–0.60 s | Duração de um tomate atraído. |
| `flight_arc_height` | 0.3–0.6 × largura da célula | Curva de atração. |
| `visible_tomatoes_per_crop` | 3–5 | Somente VFX, não determina unidades de inventário. |
| `yield_per_crop` | 6 unidades | Valor ilustrativo, configurável por cultura. |
| `tomatoes_per_crate` | 8 unidades | Valor inicial para balanceamento. |
| `max_crates` | 7 | Limite visual e de capacidade. |
| `inventory_capacity` | 56 unidades | Exemplo = 8 × 7; não fixar em várias classes. |

## Controle de capacidade
- `count == 0`: nenhuma caixa na mochila (ou suporte vazio, caso já exista).
- `count == 1..7`: uma caixa parcialmente preenchida.
- `count == 8`: uma caixa completa.
- `count == 9`: primeira caixa completa + segunda parcial.
- `count == 56`: sete caixas completas, sem permitir novas reservas.
- Visual: montar pilha repetindo `crate_empty.png` e `crate_full.png`; não usar uma imagem de sete caixas como implementação principal.
- Para mostrar preenchimento parcial, sobrepor indicadores de tomates ou pequenos sprites dentro da caixa vazia; não apresentar caixa cheia quando a carga ainda não foi completada.

## Convenções de desenho e posicionamento
- A planta se ancora na posição 3D da célula de cultivo; nunca mover a planta diretamente para a mochila.
- As frutas voadoras são instâncias visuais temporárias independentes da planta original.
- Capturar a origem em `CropPlant.HarvestOriginMarker` (ou nó equivalente).
- A meta é um `HarvestIntakeMarker` que se move junto com o personagem. Atualizar seu `global_position` durante todo o voo; não salvar apenas uma posição de destino fixa.
- Ao renderizar caixas com `Sprite3D`, manter transparência e uma ordem física 3D correta; ajustar tamanho em unidades de mundo após testar pela câmera real.
- Pilha ancorada atrás do fazendeiro em um `BackpackStackRoot`. Crates não colidem com o jogador.
- Sete caixas devem ser visíveis e legíveis sem encobrir a câmera ou atravessar o personagem. Ajustar a profundidade e o deslocamento conforme a orientação do fazendeiro.
- Rastro de sucção (`harvest_suction_trail.png`) e brilho (`harvest_pickup_spark.png`) são opcionais: usar pouco e preferir animar escala/opacidade no tempo para não poluir a tela.

## Estado e integridade
`RIPE -> HARVESTING -> HARVESTED` quando todos os frutos disponíveis forem recolhidos.
Se houver coleta parcial, retorna a `RIPE` após subtrair quantidade confirmada.
Reservar capacidade antes de criar os sprites de voo. Confirmar na chegada; desfazer a reserva em cancelamento, troca de cena ou erro. Não duplicar unidades ao interromper o VFX.
Para retomada, serializar inventário, quantidade de frutas restante e estado por célula.

## Contratos sugeridos
```
HarvestController.request_collect(cell_id: StringName) -> bool
HarvestInventory.try_reserve(item_id: StringName, amount: int) -> Reservation
TomatoPickupFX.launch(origin: Vector3, intake: Node3D, visual_count: int, on_complete: Callable)
BackpackCrates.set_amount(item_id: StringName, amount: int)
CropGrowthManager.set_remaining_yield(cell_id: StringName, units: int)
```
Adaptar à arquitetura existente após inspecionar o projeto; não duplicar gestores.

## Critérios de aceite
- Coletar pelo menos dez plantas em sequência durante o deslocamento, sem parar, sem duplicação.
- Plantas no fundo/meio/frente do campo funcionam igualmente.
- Nenhum tomate voador passa por baixo da textura do terreno ou nasce fora da célula associada.
- Frutos acompanham o destino móvel quando o fazendeiro muda de direção.
- Inventário total e número de caixas correspondem exatamente à capacidade configurada.
- Confirmar visualmente os estados de mochila com 0, 1, 8, 9, 55 e 56 unidades.
- Ao atingir 56 unidades, novos frutos permanecem nas plantas, não são perdidos.
- Caso o jogador saia do campo ou a animação seja cancelada, reservas pendentes são revertidas sem gerar duplicações.
- Não modificar câmera, textura do terreno, mapeamento das células ou movimento do fazendeiro para esconder defeitos.
- Capturas e gravação curta da cena em execução mostram coleta de planta da frente e do fundo e pilha chegando a sete caixas.

## Orientações para os assets
PNG RGBA já recortados na pasta `assets/`:
- `tomato_ripe.png` — visual de fruto isolado para a trajetória de coleta.
- `crate_empty.png` — base reutilizável da caixa parcial.
- `crate_full.png` — base reutilizável da caixa completa.
- `harvest_suction_trail.png` — arco/brilho de sucção opcional; pode ser substituído por VFX procedural.
- `harvest_pickup_spark.png` — brilho de chegada opcional.
- `crate_stack_7_reference.png` — somente referência visual da capacidade máxima; **não** usar como pilha dinâmica.

Estes sprites são artes 2D transparentes. O posicionamento, a profundidade, a animação, o inventário e a validação de runtime ainda precisam ser implementados no Godot. É obrigatório conferir a escala final na câmera do projeto.
