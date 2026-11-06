# FV-CUSTOMERS-001 — fila de clientes na bancada

Validação local em 6 de novembro de 2026, Godot 4.7.2 Standard, renderizador Mobile.

## O que mudou

- A bancada de descarga (depósito) foi recuada da cerca: `foot_inset` 3,5 → 11,5. Centro em z = 20,5; o canteiro termina em z = 13,82, sobrando corredor para o fazendeiro descarregar pelo lado da plantação.
- Atrás da bancada (lado +Z, voltado para a cerca) há uma fila dupla: 2 filas × 7 lugares, 2,0 m entre filas e 1,15 m entre clientes. Primeiro lugar em z = 22,8, último em z = 29,7, surgimento em z = 31,2, cerca em z = 32.
- Um cliente surge a cada 10–15 s (sorteado), entra na fila mais curta e caminha até o lugar. Com 5 clientes acumulados o relógio para; quando um sai (`release_front`), um novo intervalo completo de 10–15 s é sorteado e os de trás andam um lugar.
- Cada cliente copia os meshes da cena `farmer.tscn` (corpo e detalhe frontal) com um de 7 esquemas de cores; nenhum usa o azul do fazendeiro. Não têm script de controle nem colisão.
- Câmera, joystick e terreno não foram alterados.

## Teste automático

```powershell
godot --headless --path . -s tools/customer_smoke.gd
```

Saída (semente fixa 20261106):

```
LAYOUT depot_z=20.50 plot_far_edge=13.82 first_slot_z=22.80 last_slot_z=29.70 spawn_z=31.20 fence_z=32.00
SPAWN_TIMES ["10.35", "20.40", "30.70", "43.55", "54.60"] INTERVALS ["10.35", "10.05", "10.30", "12.85", "11.05"]
HOLD_AT_MAX count=5 after 240 s (último em 54.60 s)
REFILL_AFTER_RELEASE wait=13.55 count=5
CUSTOMER_SMOKE_OK lanes=2x7 max=5 intervals=10-15s refill=13.55s
```

O teste também confere: 14 lugares sem sobreposição e dentro da cerca, clientes no lugar ao fim da caminhada, mesmos meshes do fazendeiro com cores diferentes, recusa do 15º cliente e descarga da mochila na bancada recuada. `farm_smoke`, `harvest_smoke` e `depot_smoke` continuam passando.

## Capturas

`godot --path . -s tools/customer_capture.gd -- <pasta>` (sem `--headless`):

- [Cliente chegando à fila](01-cliente-chegando.png)
- [Limite de 5 clientes acumulados](02-cinco-clientes-limite.png)
- [Espaço da fila dupla 2 × 7 preenchido à força](03-espaco-fila-dupla-2x7.png)
- [Visão ampliada (só na captura): canteiro, bancada e fila](04-visao-canteiro-bancada-fila.png)

Ainda não há atendimento/venda: a saída de clientes existe na API para a próxima etapa.
