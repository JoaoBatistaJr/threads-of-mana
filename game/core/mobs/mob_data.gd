## Definição de uma criatura (Resource). Guardar em res://resources/mobs/ e arrastar para
## [member EnemySpawnPoint.mob_pool]. O [member id] é o usado em missões de caça
## e a tradução do nome vem da chave "entity_mob_<id>".
extends Resource
class_name MobData

@export var id: String = "mob"
@export_enum("animal", "monster", "construct", "humanoid") var category: String = "animal"
## Nível base (o do mob jovem). O nível real sobe com a idade e ao matar jogadores (ver "Evolução").
@export var level: int = 1

@export_group("Vida e defesa")
@export var max_health: float = 30.0
## Regeneração por segundo fora de combate.
@export var regen: float = 1.0
@export var defense: float = 0.0
## Chance de esquivar golpes do jogador (0 a 0.6).
@export_range(0.0, 0.6, 0.01) var dodge_chance: float = 0.05
## Resistência por tipo de dano, de 0 a 1 (ex.: {"fire": 0.5}). Valores negativos = fraqueza.
@export var resistances: Dictionary = {}

@export_group("Ataque")
@export var attack_damage: float = 4.0
@export var attack_interval: float = 1.5
## Distância (plano XZ) em que o mob começa a bater.
@export var attack_range: float = 1.8
@export var damage_type: String = "physical"

@export_group("Movimento")
@export var walk_speed: float = 1.5
@export var run_speed: float = 4.5

@export_group("IA")
@export var behavior: AiBehavior
## Raio ao redor do ponto de origem em que ele anda quando ocioso.
@export var idle_radius: float = 8.0
## Distância em que percebe o jogador (hostis) ou em que desiste da perseguição (defensivos).
@export var detection_range: float = 10.0
## Distância máxima do alvo: além disso o mob desiste da perseguição.
@export var chase_range: float = 40.0
## Distância máxima do ponto de origem antes de desistir e voltar (bem maior que o raio ocioso).
@export var leash_range: float = 60.0
## O mob só pensa e se move com um jogador a menos dessa distância.
@export var activation_range: float = 70.0
## Raio em que criaturas da mesma espécie entram na luta quando esta começa a perseguir (0 = age sozinha).
@export var assist_radius: float = 0.0

@export_group("Habilidades")
## Habilidades especiais da luta (gatilho + ação). Ver [MobAbility].
@export var abilities: Array[MobAbility] = []

@export_group("Recompensas")
## XP de personagem concedido a quem der o golpe final (multiplicado pela Sabedoria).
@export var xp: float = 20.0
@export var drops: Array[MobDrop] = []

@export_group("Evolução (idade e nível)")
## Se o mob ganha idade e nível (com o tempo e ao matar jogadores). Desligue para mobs fixos.
@export var evolves: bool = true
## Nível máximo; ao chegar nele o mob vira chefe.
@export_range(2, 30) var max_level: int = 20
## Segundos de vida em que começa cada estágio: jovem, adulto, maduro, velho, ancião.
@export var age_thresholds: PackedFloat32Array = PackedFloat32Array([0.0, 1800.0, 5400.0, 10800.0, 21600.0])
## Multiplicador do XP de nível ganho só por tempo de vida.
@export var passive_xp_mult: float = 1.0
## Multiplicador do XP de nível ganho ao matar jogadores (o primeiro abate sempre sobe 1 nível).
@export var kill_xp_mult: float = 1.0

@export_group("Aparência")
## Cena alternativa (precisa usar o script Mob). Vazio = usa a do EnemySpawnPoint.
@export var scene: PackedScene
## Pinta o mesh provisório com [member color] e aplica [member body_scale].
@export var tint_placeholder: bool = true
@export var color: Color = Color(0.6, 0.6, 0.6)
@export_range(0.3, 4.0, 0.05) var body_scale: float = 1.0


## Chave de tradução do nome.
func name_key() -> String:
	return "entity_mob_" + id


## Nome traduzido (usa o id formatado se a chave não existir).
func display_name() -> String:
	var key: String = name_key()
	var text: String = TranslationServer.translate(key)
	return id.capitalize() if text == key else text
