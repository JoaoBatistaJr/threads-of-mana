class_name Const
extends RefCounted

# Rede
const SERVER_NAME := "Mana-1"   # nome exibido ao jogador (o endereço fica oculto)
const DEFAULT_ADDRESS := "127.0.0.1"
const DEFAULT_PORT := 7777
const MAX_CLIENTS := 100
const STATUS_EVERY := 15.0       # s entre envios de status ao site
const CH_RELIABLE := 0
const CH_INPUT := 1
const CH_SNAPSHOT := 2

# Personagens
const SLOT_COUNT := 3
const NAME_MIN := 3
const NAME_MAX := 16

# Simulação (servidor e cliente usam o mesmo passo fixo; project.godot: 30 ticks/s)
const DT := 1.0 / 30.0
const SNAPSHOT_EVERY := 2          # ticks -> 15 snapshots/s
const MAX_QUEUE := 8               # inputs pendentes por jogador (anti-flood)
const QUEUE_KEEP := 3

# Movimento
const WALK_SPEED := 4.0
const RUN_SPEED := 7.5
const GROUND_ACCEL := 45.0
const AIR_ACCEL := 12.0
const JUMP_VELOCITY := 7.0
const GRAVITY := 22.0
const TURN_RATE := 14.0
const MAX_SLOPE := 1.0             # inclinação máxima caminhável (tangente; 1.0 = 45°)
const SNAP_DOWN := 0.6             # desce degraus/declives até esta altura colado ao chão

# Mundo (uma região de ~1 km²; ver mundo-e-zonas)
const PROTOCOL := 2                # incrementar quando cliente e servidor deixarem de ser compatíveis
const ZONE_SEED := 20261124
const ZONE_HALF := 512.0           # metros do centro até a borda
const CHUNK_SIZE := 64.0
const CHUNK_CELLS := 32            # células por chunk (64 m / 32 = 2 m)
const VIEW_CHUNKS := 4             # raio de chunks desenhados
const CHUNKS_PER_FRAME := 3

# Coleta de recursos (autoridade do servidor)
const GATHER_RANGE := 2.5          # m até o recurso
const GATHER_TIME := 2.0           # s por coleta
const NODE_HITS := 3               # coletas até esgotar o recurso
const NODE_RESPAWN := 30.0         # s para o recurso voltar
const MODE_COMBAT := 0
const MODE_GATHER := 1

# Cliente
const INTERP_DELAY := 0.12         # s, atraso de interpolação dos outros jogadores
const SMOOTH_RATE := 12.0          # suavização visual das correções
const SNAP_DISTANCE := 3.0         # erro acima disso = teleporte sem suavizar
