# Arquitetura do TerraBela Farm

## Princípios

- Mobile-first: toque, landscape, safe areas e performance são requisitos de base.
- Domínios independentes: estado, regras, apresentação e plataforma não se misturam.
- Dados configuráveis: culturas, economia e progressão usam Resources ou arquivos versionados.
- Regras de farming, inventory, commerce e economy devem ser testáveis sem renderização.

## Domínios

Core coordena ciclo de vida e eventos. World controla mapa e câmera. Player controla movimento. Farming implementa culturas. Inventory separa produtos, lotes e caixas. Commerce trata bancada, pedidos e clientes. Economy trata pagamentos e saldo. Progression trata desbloqueios. UI trata HUD e touchscreen. Persistence trata saves. Platform encapsula Android/iOS.

Fluxo do vertical slice:

Input -> Player -> Farming/Commerce -> Inventory -> Economy -> Persistence

Apresentação observa mudanças por sinais e não decide regras econômicas. O limite visual de sete caixas nunca substitui a validação do inventário lógico.
