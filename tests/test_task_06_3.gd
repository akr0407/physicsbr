extends SceneTree

func _init() -> void:
	print("========================================")
	print("STARTING TEST SUITE: Task 06.3 Regression & Architecture Test")
	print("========================================")
	
	var passed = true
	passed = test_base_match_manager_unit() and passed
	passed = test_battle_royale_manager_inheritance() and passed
	passed = test_match_hud_compatibility() and passed
	
	if not passed:
		print("FAILED: One or more unit tests failed.")
		quit(1)
		return
	
	print("\n--- Running Scene Integration Test on main.tscn ---")
	call_deferred("_run_scene_test")

func test_base_match_manager_unit() -> bool:
	print("\n[TEST 1] BaseMatchManager unit test...")
	var base_mgr = BaseMatchManager.new()
	base_mgr.name = "TestBaseManager"
	
	# Verify signals exist
	if not base_mgr.has_signal("match_started"):
		push_error("FAIL: missing signal match_started")
		return false
	if not base_mgr.has_signal("fighter_eliminated"):
		push_error("FAIL: missing signal fighter_eliminated")
		return false
	if not base_mgr.has_signal("game_over"):
		push_error("FAIL: missing signal game_over")
		return false
	
	# Initial state
	assert(base_mgr.get_alive_count() == 0, "Initial alive count should be 0")
	assert(base_mgr.get_total_count() == 0, "Initial total count should be 0")
	assert(base_mgr.is_match_over() == false, "Initial is_match_over should be false")
	assert(base_mgr.get_winner() == null, "Initial winner should be null")
	
	# Create mock fighters
	var f1 = RigidBody2D.new()
	f1.set_script(load("res://scripts/fighter.gd"))
	f1.fighter_name = "Mock Fighter 1"
	f1.fighter_id = 1
	
	var f2 = RigidBody2D.new()
	f2.set_script(load("res://scripts/fighter.gd"))
	f2.fighter_name = "Mock Fighter 2"
	f2.fighter_id = 2
	
	base_mgr.register_fighter(f1)
	base_mgr.register_fighter(f2)
	
	assert(base_mgr.get_total_count() == 2, "Total count should be 2")
	assert(base_mgr.get_alive_count() == 2, "Alive count should be 2")
	assert(base_mgr.is_fighter_alive(f1) == true, "f1 should be alive")
	assert(base_mgr.is_fighter_alive(f2) == true, "f2 should be alive")
	
	# Elimination test
	var signal_eliminated_called = [false]
	var reported_remaining = [-1]
	base_mgr.fighter_eliminated.connect(func(f, rem):
		signal_eliminated_called[0] = true
		reported_remaining[0] = rem
	)
	
	f1._eliminate()
	assert(signal_eliminated_called[0] == true, "fighter_eliminated signal should fire")
	assert(reported_remaining[0] == 1, "remaining should be 1")
	assert(base_mgr.get_alive_count() == 1, "Alive count should be 1")
	assert(base_mgr.is_fighter_alive(f1) == false, "f1 should not be alive")
	assert(base_mgr.is_fighter_alive(f2) == true, "f2 should be alive")
	
	# Duplicate elimination test (protection)
	signal_eliminated_called[0] = false
	base_mgr._on_fighter_eliminated(f1)
	assert(signal_eliminated_called[0] == false, "Duplicate elimination should be ignored")
	
	f1.free()
	f2.free()
	base_mgr.free()
	print("PASS: BaseMatchManager unit test.")
	return true

func test_battle_royale_manager_inheritance() -> bool:
	print("\n[TEST 2] BattleRoyaleManager inheritance & rule test...")
	var br_mgr = BattleRoyaleManager.new()
	br_mgr.name = "TestBRManager"
	
	# Check inheritance
	assert(br_mgr is BaseMatchManager, "BattleRoyaleManager must be BaseMatchManager")
	assert(br_mgr is Node, "BattleRoyaleManager must be Node")
	
	# Check BR-specific properties
	assert("spawn_radius" in br_mgr, "br_mgr should have spawn_radius")
	assert("arena_rect" in br_mgr, "br_mgr should have arena_rect")
	assert("physical_walls_enabled" in br_mgr, "br_mgr should have physical_walls_enabled")
	
	# Create mock fighters for win condition test
	var f1 = RigidBody2D.new()
	f1.set_script(load("res://scripts/fighter.gd"))
	f1.fighter_name = "BR Fighter 1"
	f1.fighter_id = 1
	
	var f2 = RigidBody2D.new()
	f2.set_script(load("res://scripts/fighter.gd"))
	f2.fighter_name = "BR Fighter 2"
	f2.fighter_id = 2
	
	br_mgr.register_fighter(f1)
	br_mgr.register_fighter(f2)
	
	var game_over_called = [false]
	var game_over_winner: Array[RigidBody2D] = [null]
	br_mgr.game_over.connect(func(w):
		game_over_called[0] = true
		game_over_winner[0] = w
	)
	
	# Eliminate f2, f1 should be winner
	f2._eliminate()
	assert(game_over_called[0] == true, "game_over signal should fire when 1 alive")
	assert(game_over_winner[0] == f1, "f1 should be declared winner")
	assert(br_mgr.is_match_over() == true, "is_match_over should be true")
	assert(br_mgr.get_winner() == f1, "get_winner should be f1")
	assert(br_mgr.is_draw() == false, "is_draw should be false")
	
	f1.free()
	f2.free()
	br_mgr.free()
	print("PASS: BattleRoyaleManager inheritance & rule test.")
	return true

func test_match_hud_compatibility() -> bool:
	print("\n[TEST 3] MatchHUD polymorphic binding test...")
	var hud_scene = load("res://scenes/main.tscn")
	var instance = hud_scene.instantiate()
	
	var hud: MatchHUD = instance.get_node_or_null("HUD") as MatchHUD
	var br_mgr: BattleRoyaleManager = instance.get_node_or_null("BattleRoyaleManager") as BattleRoyaleManager
	
	assert(hud != null, "HUD node must exist")
	assert(br_mgr != null, "BattleRoyaleManager node must exist")
	assert(br_mgr is BaseMatchManager, "BattleRoyaleManager must be BaseMatchManager")
	
	# Add to tree temporarily to test _ready binding
	root.add_child(instance)
	if not hud.is_node_ready():
		hud._ready()
	assert(hud.manager == br_mgr, "hud.manager must link to BattleRoyaleManager via BaseMatchManager")
	assert(hud.get_alive_text().begins_with("ALIVE:"), "alive_text should show ALIVE format")
	assert(hud.is_game_over_visible() == false, "game over panel should initially be hidden")
	
	instance.queue_free()
	print("PASS: MatchHUD polymorphic binding test.")
	return true

var _scene_test_instance: Node = null
var _match_start_ticks: int = 0

func _run_scene_test() -> void:
	print("\n[TEST 4] Full Main Scene Playtest Execution...")
	var scene = load("res://scenes/main.tscn")
	_scene_test_instance = scene.instantiate()
	root.add_child(_scene_test_instance)
	
	var br_mgr: BattleRoyaleManager = _scene_test_instance.get_node_or_null("BattleRoyaleManager") as BattleRoyaleManager
	var hud: MatchHUD = _scene_test_instance.get_node_or_null("HUD") as MatchHUD
	
	_match_start_ticks = Time.get_ticks_msec()
	
	br_mgr.game_over.connect(func(winner):
		var elapsed_sec = (Time.get_ticks_msec() - _match_start_ticks) / 1000.0
		var wname = winner.fighter_name if winner and "fighter_name" in winner else (winner.name if winner else "DRAW")
		print("\n========================================")
		print("[SCENE PLAYTEST COMPLETED NATURALLY]")
		print("Elapsed Time: %0.2f seconds" % elapsed_sec)
		print("Outcome: %s" % ("WINNER: " + wname if winner else "DRAW"))
		print("HUD Alive Text: %s" % hud.get_alive_text())
		print("HUD Winner Text: %s" % hud.get_winner_text())
		print("HUD Game Over Visible: %s" % hud.is_game_over_visible())
		print("========================================")
		
		assert(hud.is_game_over_visible() == true, "HUD game over must be visible")
		assert(br_mgr.is_match_over() == true, "Match must be over")
		print("\nALL TESTS PASSED SUCCESSFULLY!")
		quit(0)
	)
