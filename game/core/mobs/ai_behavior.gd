## Comportamento de IA plugável de uma criatura (Resource). O mesmo recurso serve a vários mobs;
## o estado fica no mob (a lógica roda no servidor). Distâncias e velocidades vêm do [MobData].
##
## PASSIVE: foge quando um jogador chega perto (raio de detecção); se for atacado, revida.
## DEFENSIVE: ignora todos até ser atacado; então persegue e luta.
## HOSTILE: ataca qualquer jogador que entrar no raio de detecção.
## TERRITORIAL: como hostil, mas só persegue dentro do território (leash) ao redor de casa.
extends Resource
class_name AiBehavior

enum Kind { PASSIVE, DEFENSIVE, HOSTILE, TERRITORIAL }
enum State { IDLE, WANDER, CHASE, FLEE, RETURN }

@export var kind: Kind = Kind.PASSIVE
## Anda pelo raio ocioso quando não há ameaça.
@export var wander: bool = true
@export var idle_time_min: float = 2.0
@export var idle_time_max: float = 6.0
## Tempo mínimo de fuga (passivos).
@export var flee_time: float = 6.0
## Segundos sem ser ferido até um passivo/defensivo desistir da luta.
@export var aggro_timeout: float = 12.0
