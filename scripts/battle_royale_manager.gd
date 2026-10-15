class_name BattleRoyaleManager
extends Node

## Signal yang dipancarkan saat fighter tereliminasi
signal fighter_eliminated(fighter: RigidBody2D, remaining_alive_count: int)

## Signal akhir pertandingan (Task 05.2)
## winner bernilai RigidBody2D pemenang, atau null jika hasilnya draw
signal game_over(winner: RigidBody2D)

## Status akhir pertandingan
var is_game_over: bool = false
var winner: RigidBody2D = null

## Penyimpanan internal untuk seluruh fighter terdaftar dan fighter tereliminasi
var _registered_fighters: Array[RigidBody2D] = []
var _eliminated_fighters: Array[RigidBody2D] = []

func _ready() -> void:
	# Daftarkan seluruh fighter yang sudah ada di scene
	_register_existing_fighters()
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
	
	# Debug key 'K': Eliminasi fighter hidup pertama untuk memudahkan visual testing
	if event.keycode == KEY_K:
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
	
	# Debug key 'J': Simulasi eliminasi draw (kedua fighter tereliminasi bersamaan)
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
