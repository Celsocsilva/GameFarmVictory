# Architecture policy

- Fixar Godot 4.7.2 Standard e GDScript tipado quando apropriado.
- Renderer Mobile é padrão; Compatibility só após medição.
- Separar Core, World, Player, Farming, Inventory, Commerce, Economy, Progression, Animals, UI, Persistence e Platform.
- Usar Scenes, Nodes, Resources e signals; evitar autoloads injustificados e dependências circulares.
- Estado e regras devem ser testáveis sem renderização.
- Saves versionados em user://; iOS não pode depender de API exclusiva de Android.
