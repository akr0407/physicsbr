class_name BattleRoyaleManager
extends Node

## Signal yang dipancarkan saat fighter tereliminasi
signal fighter_eliminated(fighter: RigidBody2D, remaining_alive_count: int)

## Signal akhir pertandingan (Task 05.2)
## winner bernilai RigidBody2D pemenang, atau null jika hasilnya draw
signal game_over(winner: RigidBody2D)

## Konfigurasi Spawning (Task 05.3)
@export_group("Spawning Configuration")
@export var fighter_template: PackedScene = preload("res://scenes/fighter.tscn")
@export var fighter_count: int = 8
@export var auto_spawn: bool = true
@export var arena_center: Vector2 = Vector2(576, 324)
@export var spawn_radius: Vector2 = Vector2(380, 200)
@export var spawn_inward_impulse: float = 250.0

## Konfigurasi Out-of-Bounds (Task 05.4)
@export_group("Arena Bounds")
@export var bounds_enabled: bool = true
@export var arena_rect: Rect2 = Rect2(Vector2(40, 40), Vector2(1072, 568))
@export var physical_walls_enabled: bool = true:
	set(value):
		physical_walls_enabled = value
		_update_physical_walls()

## Palet warna default untuk membedakan visual masing-masing fighter
const DEFAULT_COLORS: Array[Color] = [
	Color(0.2, 0.8, 0.4),    # Hijau (Fighter 1)
	Color(0.9, 0.3, 0.2),    # Merah-Oranye (Fighter 2)
	Color(0.2, 0.6, 0.95),   # Biru (Fighter 3)
	Color(0.95, 0.75, 0.15), # Emas/Kuning (Fighter 4)
	Color(0.65, 0.3, 0.85),  # Ungu (Fighter 5)
	Color(0.15, 0.85, 0.85), # Cyan (Fighter 6)
	Color(0.95, 0.35, 0.65), # Pink (Fighter 7)
	Color(0.95, 0.5, 0.15)   # Oranye Terang (Fighter 8)
]

## Status akhir pertandingan
var is_game_over: bool = false
var winner: RigidBody2D = null

## Penyimpanan internal untuk seluruh fighter terdaftar dan fighter tereliminasi
var _registered_fighters: Array[RigidBody2D] = []
var _eliminated_fighters: Array[RigidBody2D] = []

func _ready() -> void:
	_update_physical_walls()
	
	# Lakukan spawning secara deferred agar tree parent selesai setup
	if auto_spawn and fighter_template != null:
		call_deferred("spawn_fighters")
	else:
		_register_existing_fighters()
		print("[BattleRoyaleManager] Siap. Total fighter terdaftar: %d | Fighter hidup: %d" % [get_total_count(), get_alive_count()])

func _physics_process(_delta: float) -> void:
	# Evaluasi out-of-bounds setiap physics tick untuk seluruh fighter yang masih hidup
	if not bounds_enabled or is_game_over:
		return
	
	_check_out_of_bounds()

## Memeriksa seluruh fighter hidup apakah ada yang keluar dari batas arena
func _check_out_of_bounds() -> void:
	for fighter in _registered_fighters:
		if is_instance_valid(fighter) and is_fighter_alive(fighter):
			if not is_inside_arena_bounds(fighter.global_position):
				_eliminate_out_of_bounds(fighter)

## Menangani eliminasi fighter yang keluar batas arena
func _eliminate_out_of_bounds(fighter: RigidBody2D) -> void:
	if not is_instance_valid(fighter) or not is_fighter_alive(fighter):
		return
	
	var fname: String = fighter.fighter_name if "fighter_name" in fighter else fighter.name
	var fid: String = str(fighter.fighter_id) if "fighter_id" in fighter else "?"
	print("[BattleRoyaleManager] OUT OF BOUNDS! %s (ID: %s) keluar arena di posisi %s!" % [fname, fid, fighter.global_position])
	
	# Gunakan API eliminasi resmi pada fighter
	if fighter.has_method("eliminate"):
		fighter.eliminate()
	elif fighter.has_method("_eliminate"):
		fighter._eliminate()
	else:
		fighter.take_damage(99999.0)

## Mengecek apakah posisi berada di dalam batas arena
func is_inside_arena_bounds(pos: Vector2) -> bool:
	return arena_rect.has_point(pos)

## Mengembalikan Rect2 batas arena
func get_arena_rect() -> Rect2:
	return arena_rect

## Mengatur status aktivasi tabrakan fisik dinding pembatas
func _update_physical_walls() -> void:
	var walls_node = get_parent().get_node_or_null("ArenaBounds") if get_parent() else null
	if walls_node:
		for child in walls_node.get_children():
			if child is CollisionShape2D:
				child.set_deferred("disabled", not physical_walls_enabled)

## Menghitung posisi spawn melingkar/elips yang tersebar merata di arena
func get_spawn_positions(count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if count <= 0:
		return positions
	
	var angle_step: float = (2.0 * PI) / float(count)
	for i in range(count):
		# Mulai dari sudut atas (-PI/2) agar simetris
		var angle: float = -PI / 2.0 + (float(i) * angle_step)
		var pos: Vector2 = arena_center + Vector2(cos(angle) * spawn_radius.x, sin(angle) * spawn_radius.y)
		positions.append(pos)
	
	return positions

## Melakukan instansiasi fighter secara otomatis di arena
func spawn_fighters(count: int = -1) -> void:
	if fighter_template == null:
		push_error("[BattleRoyaleManager] fighter_template belum diatur!")
		return
	
	var n: int = count if count > 0 else fighter_count
	var positions: Array[Vector2] = get_spawn_positions(n)
	var target_parent: Node = get_parent() if get_parent() != null else self
	
	print("[BattleRoyaleManager] Melakukan spawning %d fighter ke dalam arena..." % [n])
	
	for i in range(n):
		var fighter = fighter_template.instantiate()
		fighter.fighter_id = i + 1
		fighter.fighter_name = "Fighter %d" % (i + 1)
		fighter.name = "Fighter_%d" % (i + 1)
		fighter.global_position = positions[i]
		
		# Berikan dorongan awal mengarah ke tengah arena
		var impulse_dir: Vector2 = (arena_center - positions[i]).normalized()
		fighter.initial_impulse = impulse_dir * spawn_inward_impulse
		
		# Terapkan warna unik
		if i < DEFAULT_COLORS.size():
			fighter.fighter_color = DEFAULT_COLORS[i]
		else:
			fighter.fighter_color = Color.from_hsv(float(i) / float(n), 0.75, 0.9)
		
		target_parent.add_child(fighter)
		register_fighter(fighter)
	
	print("[BattleRoyaleManager] Siap. Total fighter terdaftar: %d | Fighter hidup: %d" % [get_total_count(), get_alive_count()])

## Mencari dan mendaftarkan fighter yang ada di scene secara non-rapuh
func _register_existing_fighters() -> void:
	# Memanfaatkan grup "fighters" yang sudah menjadi standar proyek
	var group_nodes: Array[Node] = get_tree().get_nodes_in_group("fighters")
	for node in group_nodes:
		if node is RigidBody2D:
			register_fighter(node)
	
	# Fallback aman: periksa child pada node parent (misalnya Main)
	if get_parent():
		for child in get_parent().get_children():
			if child is RigidBody2D and child.has_signal("eliminated"):
				register_fighter(child)

## Mendaftarkan fighter tunggal ke manager
func register_fighter(fighter: RigidBody2D) -> void:
	if not is_instance_valid(fighter):
		return
	if _registered_fighters.has(fighter):
		return
	
	_registered_fighters.append(fighter)
	
	# Hubungkan signal eliminated jika belum tersambung
	if fighter.has_signal("eliminated") and not fighter.eliminated.is_connected(_on_fighter_eliminated):
		fighter.eliminated.connect(_on_fighter_eliminated)
	
	# Sinkronisasi jika fighter sudah tereliminasi sebelum didaftarkan
	if "is_eliminated" in fighter and fighter.is_eliminated:
		if not _eliminated_fighters.has(fighter):
			_eliminated_fighters.append(fighter)
	
	var fighter_name_str: String = fighter.fighter_name if "fighter_name" in fighter else fighter.name
	var fid_str: String = str(fighter.fighter_id) if "fighter_id" in fighter else "?"
	print("[BattleRoyaleManager] Fighter terdaftar: %s (ID: %s)" % [fighter_name_str, fid_str])

## Handler saat signal 'eliminated' dipancarkan oleh seorang fighter
func _on_fighter_eliminated(fighter: RigidBody2D) -> void:
	if not is_instance_valid(fighter):
		return
	
	# Proteksi eliminasi ganda: abaikan jika fighter sudah terdaftar tereliminasi
	if _eliminated_fighters.has(fighter):
		var name_str: String = fighter.fighter_name if "fighter_name" in fighter else fighter.name
		print("[BattleRoyaleManager] Fighter '%s' sudah tereliminasi sebelumnya. Mengabaikan eliminasi ganda." % [name_str])
		return
	
	# Simpan ke daftar tereliminasi
	_eliminated_fighters.append(fighter)
	
	var remaining: int = get_alive_count()
	var total: int = get_total_count()
	var fighter_name_str: String = fighter.fighter_name if "fighter_name" in fighter else fighter.name
	var fid_str: String = str(fighter.fighter_id) if "fighter_id" in fighter else "?"
	
	# Cetak output debug status sisa fighter aktif
	print("[BattleRoyaleManager] Fighter tereliminasi: %s (ID: %s) | Sisa fighter hidup: %d/%d" % [fighter_name_str, fid_str, remaining, total])
	
	# Pancarkan signal eliminasi untuk listener lain
	fighter_eliminated.emit(fighter, remaining)
	
	# Evaluasi kondisi akhir pertandingan
	_evaluate_game_over()

## Evaluasi kondisi kemenangan atau seri saat pertandingan berlangsung
func _evaluate_game_over() -> void:
	# Proteksi agar akhir pertandingan hanya dipicu tepat satu kali
	if is_game_over:
		return
	
	var remaining: int = get_alive_count()
	
	if remaining == 1:
		var alive_list: Array[RigidBody2D] = get_alive_fighters()
		if alive_list.size() == 1:
			var candidate: RigidBody2D = alive_list[0]
			# Pastikan kandidat bukan fighter yang sudah gugur
			if is_fighter_alive(candidate):
				is_game_over = true
				winner = candidate
				var wname: String = winner.fighter_name if "fighter_name" in winner else winner.name
				var wid: String = str(winner.fighter_id) if "fighter_id" in winner else "?"
				print("========================================")
				print("[BattleRoyaleManager] PERTANDINGAN SELESAI!")
				print("[BattleRoyaleManager] PEMENANG: %s (ID: %s)" % [wname, wid])
				print("========================================")
				game_over.emit(winner)
	elif remaining == 0:
		is_game_over = true
		winner = null
		print("========================================")
		print("[BattleRoyaleManager] PERTANDINGAN SELESAI: DRAW!")
		print("[BattleRoyaleManager] Seluruh fighter telah tereliminasi. Tidak ada pemenang.")
		print("========================================")
		game_over.emit(null)

## Mengembalikan jumlah fighter yang masih aktif/hidup
func get_alive_count() -> int:
	var count: int = 0
	for fighter in _registered_fighters:
		if is_instance_valid(fighter) and not _eliminated_fighters.has(fighter):
			if not ("is_eliminated" in fighter and fighter.is_eliminated):
				count += 1
	return count

## Mengembalikan total fighter terdaftar
func get_total_count() -> int:
	return _registered_fighters.size()

## Mengembalikan jumlah fighter yang sudah gugur
func get_eliminated_count() -> int:
	return _eliminated_fighters.size()

## Mengembalikan daftar fighter yang masih hidup
func get_alive_fighters() -> Array[RigidBody2D]:
	var alive_list: Array[RigidBody2D] = []
	for fighter in _registered_fighters:
		if is_instance_valid(fighter) and not _eliminated_fighters.has(fighter):
			if not ("is_eliminated" in fighter and fighter.is_eliminated):
				alive_list.append(fighter)
	return alive_list

## Mengembalikan daftar fighter yang sudah gugur
func get_eliminated_fighters() -> Array[RigidBody2D]:
	return _eliminated_fighters.duplicate()

## Mengecek apakah fighter spesifik masih hidup
func is_fighter_alive(fighter: RigidBody2D) -> bool:
	if not is_instance_valid(fighter):
		return false
	if _eliminated_fighters.has(fighter):
		return false
	if "is_eliminated" in fighter and fighter.is_eliminated:
		return false
	return _registered_fighters.has(fighter)

## Getter untuk status pemenang dan kondisi game over
func get_winner() -> RigidBody2D:
	return winner

func is_match_over() -> bool:
	return is_game_over

func is_draw() -> bool:
	return is_game_over and winner == null

## Kontrol debug keyboard untuk membantu evaluasi visual
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.is_echo():
		return
	
	# Debug key 'O': Lemparkan fighter hidup pertama ke luar arena (Out of Bounds test)
	if event.keycode == KEY_O:
		var alive_list = get_alive_fighters()
		if alive_list.size() > 0:
			var target = alive_list[0]
			var tname = target.fighter_name if "fighter_name" in target else target.name
			print("[BattleRoyaleManager DEBUG] Menekan 'O': Melempar %s ke luar arena (x = -100)..." % [tname])
			target.global_position = Vector2(-100, 324)
		else:
			print("[BattleRoyaleManager DEBUG] Tidak ada fighter hidup yang tersisa.")
	
	# Debug key 'B': Toggle dinding pembatas fisik (memungkinkan ring-out knockback secara alami)
	elif event.keycode == KEY_B:
		physical_walls_enabled = not physical_walls_enabled
		print("[BattleRoyaleManager DEBUG] Toggle Dinding Fisik Arena -> %s" % ["ON (Solid)" if physical_walls_enabled else "OFF (Ring-Out)"])
	
	# Debug key 'K': Eliminasi fighter hidup pertama untuk memudahkan visual testing
	elif event.keycode == KEY_K:
		var alive_list = get_alive_fighters()
		if alive_list.size() > 0:
			var target = alive_list[0]
			var tname = target.fighter_name if "fighter_name" in target else target.name
			print("[BattleRoyaleManager DEBUG] Menekan 'K': Mengeliminasi %s..." % [tname])
			target.take_damage(target.max_hp + 100.0)
		else:
			print("[BattleRoyaleManager DEBUG] Tidak ada fighter hidup yang tersisa.")
	
	# Debug key 'L': Coba pemicuan eliminasi ganda pada fighter tereliminasi pertama
	elif event.keycode == KEY_L:
		if _eliminated_fighters.size() > 0:
			var target = _eliminated_fighters[0]
			var tname = target.fighter_name if "fighter_name" in target else target.name
			print("[BattleRoyaleManager DEBUG] Menekan 'L': Menguji eliminasi ganda pada %s..." % [tname])
			_on_fighter_eliminated(target)
		else:
			print("[BattleRoyaleManager DEBUG] Belum ada fighter yang tereliminasi untuk diuji eliminasi ganda.")
	
	# Debug key 'J': Simulasi eliminasi draw (seluruh fighter tereliminasi bersamaan)
	elif event.keycode == KEY_J:
		if not is_game_over:
			print("[BattleRoyaleManager DEBUG] Menekan 'J': Simulasi DRAW dengan mengeliminasi seluruh fighter...")
			var all_alive = get_alive_fighters()
			for f in all_alive:
				if is_instance_valid(f):
					f.is_eliminated = true
					if not _eliminated_fighters.has(f):
						_eliminated_fighters.append(f)
			_evaluate_game_over()
		else:
			print("[BattleRoyaleManager DEBUG] Pertandingan sudah selesai sebelumnya.")
