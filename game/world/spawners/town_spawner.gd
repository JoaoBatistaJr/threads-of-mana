## Posiciona os NPCs da cidade inicial numa roda ao redor do spawn (0, 0), virados para o centro.
## Adicione como filho do mundo e arraste os [NpcData] para [member npcs].
class_name TownSpawner
extends Node3D

@export var npcs: Array[NpcData] = []
## Distância (m) dos NPCs ao centro da cidade.
@export var ring_radius: float = 16.0
## Cena colocada no centro da roda (fogueira). Vazio = usa res://entities/world_objects/campfire.tscn.
@export var center_scene: PackedScene
## Posições dos NPCs depois de criados (servidor usa para interação).
var spawned: Array[Npc] = []


func _ready() -> void:
	await get_tree().process_frame
	_spawn()


func _spawn() -> void:
	var wg := get_tree().get_first_node_in_group("world_generator") as WorldGenerator
	var count: int = npcs.size()
	for i in count:
		var data: NpcData = npcs[i]
		if data == null:
			continue
		var angle: float = TAU * float(i) / float(count) + PI * 0.5
		var x: float = cos(angle) * ring_radius
		var z: float = sin(angle) * ring_radius
		var y: float = wg.get_height(x, z) if wg != null else 0.0
		var npc := Npc.new()
		npc.data = data
		add_child(npc)
		spawned.append(npc)
		npc.global_position = Vector3(x, y, z)
		npc.look_at(Vector3(0.0, y, 0.0), Vector3.UP)
	_spawn_center(wg)


func _spawn_center(wg: WorldGenerator) -> void:
	var scene: PackedScene = center_scene
	if scene == null:
		scene = load("res://entities/world_objects/campfire.tscn") as PackedScene
	if scene == null:
		return
	var node := scene.instantiate() as Node3D
	add_child(node)
	var y: float = wg.get_height(0.0, 0.0) if wg != null else 0.0
	node.global_position = Vector3(0.0, y, 0.0)
