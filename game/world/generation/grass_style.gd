## Estilo da grama em um bioma: altura, densidade e cor. Em WorldConfig > Grama > Grass Styles.
class_name GrassStyle
extends Resource

## Id do bioma (ex.: "forest", "meadow", "desert").
@export var biome: String = "meadow"
## Multiplica a altura dos tufos.
@export_range(0.2, 3.0, 0.05) var height_mult: float = 1.0
## Fração dos tufos mantidos (1 = todos).
@export_range(0.0, 1.0, 0.05) var density_mult: float = 1.0
## Multiplica a cor da grama (branco = sem mudança).
@export var tint: Color = Color(1, 1, 1)
