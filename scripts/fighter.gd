extends RigidBody2D

## Besar dan arah dorongan awal untuk prototype testing
@export var initial_impulse: Vector2 = Vector2(800, -500)

func _ready() -> void:
	# Menerapkan impuls seketika pada pusat massa (center of mass)
	apply_central_impulse(initial_impulse)

func _unhandled_input(event: InputEvent) -> void:
	# Opsi praktis: Tekan spasi untuk memberikan dorongan acak baru saat pengujian
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		var random_direction = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		apply_central_impulse(random_direction * 800)
