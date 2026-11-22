class_name Const
extends RefCounted

# Rede
const DEFAULT_ADDRESS := "127.0.0.1"
const DEFAULT_PORT := 7777
const MAX_CLIENTS := 100
const CH_INPUT := 1
const CH_SNAPSHOT := 2

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
const WORLD_HALF_SIZE := 100.0

# Cliente
const INTERP_DELAY := 0.12         # s, atraso de interpolação dos outros jogadores
const SMOOTH_RATE := 12.0          # suavização visual das correções
const SNAP_DISTANCE := 3.0         # erro acima disso = teleporte sem suavizar
