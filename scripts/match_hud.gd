class_name MatchHUD
extends CanvasLayer

@export var manager: BaseMatchManager = null

@onready var alive_label: Label = $Root/TopBar/AliveLabel
@onready var game_over_panel: Control = $Root/GameOverPanel
@onready var result_title_label: Label = $Root/GameOverPanel/VBox/ResultTitleLabel
@onready var winner_label: Label = $Root/GameOverPanel/VBox/WinnerLabel

func _ready() -> void:
	# Hubungkan ke BaseMatchManager
	if manager == null:
		manager = get_node_or_null("../BattleRoyaleManager") as BaseMatchManager
		if manager == null:
			manager = get_node_or_null("../MatchManager") as BaseMatchManager
		if manager == null and get_parent() != null:
			for child in get_parent().get_children():
				if child is BaseMatchManager:
					manager = child
					break
	
	if manager:
		if not manager.fighter_eliminated.is_connected(_on_fighter_eliminated):
			manager.fighter_eliminated.connect(_on_fighter_eliminated)
		if not manager.game_over.is_connected(_on_game_over):
			manager.game_over.connect(_on_game_over)
		if manager.has_signal("match_started") and not manager.match_started.is_connected(_on_match_started):
			manager.match_started.connect(_on_match_started)
	
	# Sembunyikan panel hasil pertandingan di awal
	if game_over_panel:
		game_over_panel.visible = false
	
	# Panggil update survivor count
	update_survivor_display()
	call_deferred("update_survivor_display")

func _on_match_started(_alive: int, _total: int) -> void:
	update_survivor_display()

func _on_fighter_eliminated(_fighter: RigidBody2D, _remaining: int) -> void:
	update_survivor_display()

func _on_game_over(winner: RigidBody2D) -> void:
	update_survivor_display()
	show_game_over(winner)

## Memperbarui teks sisa fighter hidup menggunakan getter resmi BaseMatchManager
func update_survivor_display() -> void:
	if not is_instance_valid(alive_label):
		return
	if manager:
		alive_label.text = "ALIVE: %d/%d" % [manager.get_alive_count(), manager.get_total_count()]
	else:
		alive_label.text = "ALIVE: --/--"

## Menampilkan overlay hasil pertandingan
func show_game_over(winner: RigidBody2D) -> void:
	if not is_instance_valid(game_over_panel):
		return
	
	if winner != null:
		var wname: String = winner.fighter_name if "fighter_name" in winner else winner.name
		var wid: String = str(winner.fighter_id) if "fighter_id" in winner else "?"
		result_title_label.text = "PERTANDINGAN SELESAI!"
		winner_label.text = "PEMENANG: %s (ID: %s)" % [wname, wid]
		if "fighter_color" in winner:
			winner_label.add_theme_color_override("font_color", winner.fighter_color)
	else:
		result_title_label.text = "PERTANDINGAN SELESAI!"
		winner_label.text = "HASIL: SERI / DRAW"
		winner_label.add_theme_color_override("font_color", Color(0.95, 0.4, 0.4, 1.0))
	
	game_over_panel.visible = true

## Helper getters untuk automated regression testing
func get_alive_text() -> String:
	return alive_label.text if is_instance_valid(alive_label) else ""

func is_game_over_visible() -> bool:
	return game_over_panel.visible if is_instance_valid(game_over_panel) else false

func get_winner_text() -> String:
	return winner_label.text if is_instance_valid(winner_label) else ""
