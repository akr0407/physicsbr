extends RigidBody2D

## Signal untuk memberitahu sistem lain ketika HP berubah atau fighter tereliminasi
signal hp_changed(new_hp: float, max_hp: float)
signal eliminated(fighter: RigidBody2D)

## Identitas Fighter
@export var fighter_id: int = 1
@export var fighter_name: String = "Fighter 1"

## Parameter Health (HP)
@export var max_hp: float = 100.0
var current_hp: float = 100.0

## Status Eliminasi
var is_eliminated: bool = false

## Besar dan arah dorongan awal untuk prototype testing (dari Task 01)
@export var initial_impulse: Vector2 = Vector2(800, -500)

func _ready() -> void:
	current_hp = max_hp
	print("[%s (ID: %d)] Memasuki arena dengan HP: %0.1f/%0.1f" % [fighter_name, fighter_id, current_hp, max_hp])
	
	# Menerapkan impuls seketika pada pusat massa (center of mass)
	apply_central_impulse(initial_impulse)

## Mengurangi HP fighter dengan boundary check dan proteksi eliminasi
func take_damage(amount: float) -> void:
	# Jika sudah tereliminasi atau damage tidak valid, abaikan pemrosesan
	if is_eliminated or amount <= 0.0:
		return
	
	# Kurangi HP dan pastikan nilai tidak jatuh di bawah nol
	current_hp = maxf(0.0, current_hp - amount)
	print("[%s] Menerima damage: %0.1f | Sisa HP: %0.1f/%0.1f" % [fighter_name, amount, current_hp, max_hp])
	hp_changed.emit(current_hp, max_hp)
	
	# Evaluasi kondisi eliminasi
	if current_hp == 0.0:
		_eliminate()

## Menangani proses eliminasi (hanya dipicu satu kali)
func _eliminate() -> void:
	is_eliminated = true
	print(">>> [%s (ID: %d)] TERELIMINASI! <<<" % [fighter_name, fighter_id])
	eliminated.emit(self)
	
	# Visual feedback placeholder: redupkan warna fighter
	var visual: CanvasItem = get_node_or_null("Visual")
	if visual:
		visual.modulate = Color(0.4, 0.4, 0.4, 0.6)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.is_echo():
		return
		
	# Task 01: Tekan spasi untuk memberikan dorongan acak baru
	if event.keycode == KEY_SPACE:
		var random_direction = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		apply_central_impulse(random_direction * 800)
	
	# Task 02 Debug Testing: Tekan 'D' untuk simulasi menerima damage 25
	elif event.keycode == KEY_D:
		take_damage(25.0)
