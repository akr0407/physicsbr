class_name BaseMatchManager
extends Node

## Signal yang dipancarkan saat fighter tereliminasi
signal fighter_eliminated(fighter: RigidBody2D, remaining_alive_count: int)

## Signal akhir pertandingan
## winner bernilai RigidBody2D pemenang, atau null jika hasilnya draw
signal game_over(winner: RigidBody2D)

## Signal saat pertandingan dimulai dan seluruh fighter telah selesai diinisialisasi
signal match_started(alive_count: int, total_count: int)

## Status akhir pertandingan
var is_game_over: bool = false
var winner: RigidBody2D = null

## Penyimpanan internal untuk seluruh fighter terdaftar dan fighter tereliminasi
var _registered_fighters: Array[RigidBody2D] = []
var _eliminated_fighters: Array[RigidBody2D] = []

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
	
	match_started.emit(get_alive_count(), get_total_count())

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
	print("[%s] Fighter terdaftar: %s (ID: %s)" % [name, fighter_name_str, fid_str])

## Handler saat signal 'eliminated' dipancarkan oleh seorang fighter
func _on_fighter_eliminated(fighter: RigidBody2D) -> void:
	if not is_instance_valid(fighter):
		return
	
	# Proteksi eliminasi ganda: abaikan jika fighter sudah terdaftar tereliminasi
	if _eliminated_fighters.has(fighter):
		var name_str: String = fighter.fighter_name if "fighter_name" in fighter else fighter.name
		print("[%s] Fighter '%s' sudah tereliminasi sebelumnya. Mengabaikan eliminasi ganda." % [name, name_str])
		return
	
	# Simpan ke daftar tereliminasi
	_eliminated_fighters.append(fighter)
	
	var remaining: int = get_alive_count()
	var total: int = get_total_count()
	var fighter_name_str: String = fighter.fighter_name if "fighter_name" in fighter else fighter.name
	var fid_str: String = str(fighter.fighter_id) if "fighter_id" in fighter else "?"
	
	# Cetak output debug status sisa fighter aktif
	print("[%s] Fighter tereliminasi: %s (ID: %s) | Sisa fighter hidup: %d/%d" % [name, fighter_name_str, fid_str, remaining, total])
	
	# Pancarkan signal eliminasi untuk listener lain
	fighter_eliminated.emit(fighter, remaining)
	
	# Evaluasi kondisi akhir pertandingan (diimplementasikan oleh subclass)
	_evaluate_game_over()

## Metode virtual untuk evaluasi kondisi akhir pertandingan
func _evaluate_game_over() -> void:
	pass

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
