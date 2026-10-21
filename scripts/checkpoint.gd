class_name Checkpoint
extends Area2D

## Signal dipancarkan saat fighter memasuki area checkpoint
signal fighter_entered(fighter: RigidBody2D, checkpoint: Checkpoint)

## Signal dipancarkan saat fighter meninggalkan area checkpoint
signal fighter_exited(fighter: RigidBody2D, checkpoint: Checkpoint)

@export var checkpoint_id: int = 0
@export var checkpoint_name: String = "Checkpoint"
@export var target_offset: Vector2 = Vector2.ZERO

## Daftar fighter yang saat ini sedang berada di dalam area checkpoint
var _overlapping_fighters: Array[RigidBody2D] = []

func _ready() -> void:
	# Pastikan Area2D dapat mendeteksi body pada collision mask layer 1
	monitoring = true
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

## Mengembalikan posisi world-space target untuk navigasi fighter
func get_target_position() -> Vector2:
	return global_position + target_offset

## Mengecek apakah fighter tertentu sedang berada di dalam checkpoint
func is_fighter_inside(fighter: RigidBody2D) -> bool:
	return _overlapping_fighters.has(fighter)

## Mengembalikan daftar seluruh fighter yang sedang berada di dalam checkpoint
func get_overlapping_fighters() -> Array[RigidBody2D]:
	return _overlapping_fighters.duplicate()

func _on_body_entered(body: Node2D) -> void:
	if not (body is RigidBody2D and body.is_in_group("fighters")):
		return
	
	var fighter: RigidBody2D = body as RigidBody2D
	
	# Hindari pelaporan berulang jika fighter sudah tercatat berada di dalam checkpoint
	if _overlapping_fighters.has(fighter):
		return
	
	_overlapping_fighters.append(fighter)
	fighter_entered.emit(fighter, self)

func _on_body_exited(body: Node2D) -> void:
	if not (body is RigidBody2D and body.is_in_group("fighters")):
		return
	
	var fighter: RigidBody2D = body as RigidBody2D
	if _overlapping_fighters.has(fighter):
		_overlapping_fighters.erase(fighter)
		fighter_exited.emit(fighter, self)
