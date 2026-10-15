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

## Warna visual fighter untuk membedakan antar fighter di arena
@export var fighter_color: Color = Color(0.18, 0.8, 0.44, 1)

func _ready() -> void:
	current_hp = max_hp
	print("[%s (ID: %d)] Memasuki arena dengan HP: %0.1f/%0.1f" % [fighter_name, fighter_id, current_hp, max_hp])
	
	# Terapkan warna visual jika ada
	var visual: ColorRect = get_node_or_null("Visual")
	if visual:
		visual.color = fighter_color
	
	# Konfigurasi contact monitor untuk mendeteksi tabrakan fisik
	contact_monitor = true
	max_contacts_reported = 4
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	# Menerapkan impuls seketika pada pusat massa (center of mass)
	apply_central_impulse(initial_impulse)

## Parameter Combat & Tabrakan
@export var min_impact_velocity: float = 150.0
@export var base_damage: float = 10.0
@export var damage_velocity_scaling: float = 0.02
@export var combat_cooldown: float = 0.5
@export var knockback_impulse: float = 300.0
var _last_combat_time: float = -999.0

## Handler saat terjadi kontak fisik dengan body lain
func _on_body_entered(body: Node) -> void:
	# Abaikan jika kontak dengan diri sendiri atau fighter ini sudah tereliminasi
	if body == self or is_eliminated:
		return
	
	# Verifikasi apakah body yang ditabrak adalah sesama fighter
	if not (body is RigidBody2D and body.has_method("take_damage")):
		return
	
	# Fighter yang sudah tereliminasi tidak dapat diserang atau memicu combat
	if "is_eliminated" in body and body.is_eliminated:
		return
	
	# Evaluasi cooldown combat pada kedua pihak untuk mencegah multi-hit saat kontak berlanjut
	var current_time: float = Time.get_ticks_msec() / 1000.0
	if current_time - _last_combat_time < combat_cooldown:
		return
	if "_last_combat_time" in body and (current_time - body._last_combat_time < combat_cooldown):
		return
	
	# Hitung kecepatan relatif tabrakan
	var relative_velocity: float = (linear_velocity - body.linear_velocity).length()
	
	# Jika benturan tidak cukup kuat (di bawah threshold), abaikan damage
	if relative_velocity < min_impact_velocity:
		return
	
	# Catat waktu combat aktif pada kedua fighter agar sinkron dalam cooldown
	_last_combat_time = current_time
	if "_last_combat_time" in body:
		body._last_combat_time = current_time
	
	# Hitung jumlah damage berdasarkan intensitas tabrakan
	var damage: float = snappedf(base_damage + (relative_velocity - min_impact_velocity) * damage_velocity_scaling, 0.1)
	
	var target_name: String = body.fighter_name if "fighter_name" in body else body.name
	print("[%s] & [%s] Bertabrakan! (Kecepatan Relatif: %0.1f) -> Mutual damage: %0.1f" % [fighter_name, target_name, relative_velocity, damage])
	
	# Berikan damage ke kedua belah pihak (mutual damage)
	take_damage(damage)
	body.take_damage(damage)
	
	# Terapkan knockback aktif menggunakan arah relatif posisi antar fighter
	var push_dir: Vector2 = (global_position - body.global_position).normalized()
	if push_dir.is_zero_approx():
		push_dir = Vector2.UP
	
	apply_central_impulse(push_dir * knockback_impulse)
	if body is RigidBody2D:
		body.apply_central_impulse(-push_dir * knockback_impulse)
	print("[%s] Menerapkan knockback mutual %0.1f sepanjang sumbu benturan" % [fighter_name, knockback_impulse])

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
