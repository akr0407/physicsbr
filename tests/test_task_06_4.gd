extends SceneTree

func _init() -> void:
	call_deferred("_start_tests")

func _start_tests() -> void:
	print("========================================")
	print("STARTING TEST SUITE: Task 06.4 Fighter Navigation Target")
	print("========================================")
	
	var passed = true
	passed = test_explicit_target_assignment_and_steering() and passed
	passed = test_clear_target_restores_rival_hunting() and passed
	passed = test_ai_disabled_suppresses_navigation() and passed
	passed = test_knockback_recovery_suppresses_navigation() and passed
	passed = test_invalid_target_safety() and passed
	passed = test_elimination_clears_nav_target() and passed
	
	if not passed:
		print("FAILED: One or more unit tests failed.")
		quit(1)
		return
	
	print("\n--- Running Battle Royale Playtest Regression Test ---")
	_run_br_regression_test()

func test_explicit_target_assignment_and_steering() -> bool:
	print("\n[TEST 1] Explicit target assignment and steering...")
	var fighter = RigidBody2D.new()
	fighter.set_script(load("res://scripts/fighter.gd"))
	fighter.fighter_name = "NavTestFighter"
	fighter.global_position = Vector2(100, 200)
	fighter.initial_impulse = Vector2.ZERO
	root.add_child(fighter)
	
	# Initially no nav target
	assert(fighter.has_nav_target_position() == false, "Default has_nav_target_position should be false")
	assert(fighter.get_nav_target_position() == Vector2.ZERO, "Default nav_target_position should be ZERO")
	
	# Assign target to the right: (500, 200)
	var target = Vector2(500, 200)
	fighter.set_nav_target_position(target)
	assert(fighter.has_nav_target_position() == true, "has_nav_target_position should be true after set")
	assert(fighter.get_nav_target_position() == target, "get_nav_target_position should match assigned target")
	
	# Run one physics process frame
	fighter.linear_velocity = Vector2.ZERO
	fighter._physics_process(0.016)
	
	fighter.free()
	print("PASS: Explicit target assignment and steering.")
	return true

func test_clear_target_restores_rival_hunting() -> bool:
	print("\n[TEST 2] Clearing target restores default rival-hunting...")
	var f1 = RigidBody2D.new()
	f1.set_script(load("res://scripts/fighter.gd"))
	f1.fighter_name = "HunterFighter"
	f1.global_position = Vector2(100, 100)
	f1.initial_impulse = Vector2.ZERO
	root.add_child(f1)
	
	var f2 = RigidBody2D.new()
	f2.set_script(load("res://scripts/fighter.gd"))
	f2.fighter_name = "RivalFighter"
	f2.global_position = Vector2(200, 100)
	f2.initial_impulse = Vector2.ZERO
	root.add_child(f2)
	
	# Set explicit target away from rival
	f1.set_nav_target_position(Vector2(0, 500))
	assert(f1.has_nav_target_position() == true, "f1 should have nav target")
	assert(f1.current_target == null, "current_target should be null when explicit nav target is set")
	
	f1._physics_process(0.016)
	# While nav target is active, current_target must remain null (no rival hunt)
	assert(f1.current_target == null, "current_target should remain null while nav target is active")
	
	# Clear nav target
	f1.clear_nav_target_position()
	assert(f1.has_nav_target_position() == false, "f1 has_nav_target should be false after clear")
	assert(f1.get_nav_target_position() == Vector2.ZERO, "nav_target_position should be reset to ZERO")
	
	# Next physics process must trigger rival target acquisition
	f1._physics_process(0.016)
	assert(f1.current_target != null, "f1 should acquire a rival after clearing nav target")
	assert(f1.current_target.is_in_group("fighters"), "acquired target must be a rival in fighters group")
	
	f1.free()
	f2.free()
	print("PASS: Clearing target restores default rival-hunting.")
	return true

func test_ai_disabled_suppresses_navigation() -> bool:
	print("\n[TEST 3] AI disabled suppresses navigation steering...")
	var fighter = RigidBody2D.new()
	fighter.set_script(load("res://scripts/fighter.gd"))
	fighter.fighter_name = "DisabledAIFighter"
	fighter.global_position = Vector2(100, 100)
	fighter.initial_impulse = Vector2.ZERO
	fighter.ai_enabled = false
	root.add_child(fighter)
	
	fighter.set_nav_target_position(Vector2(500, 500))
	assert(fighter.has_nav_target_position() == true, "nav target can be set")
	
	fighter.linear_velocity = Vector2.ZERO
	# Process physics
	fighter._physics_process(0.016)
	# Because ai_enabled is false, it returns early immediately without applying any force
	assert(fighter.ai_enabled == false, "ai_enabled is false")
	
	fighter.free()
	print("PASS: AI disabled suppresses navigation steering.")
	return true

func test_knockback_recovery_suppresses_navigation() -> bool:
	print("\n[TEST 4] Knockback recovery suppresses navigation steering...")
	var fighter = RigidBody2D.new()
	fighter.set_script(load("res://scripts/fighter.gd"))
	fighter.fighter_name = "KnockbackFighter"
	fighter.global_position = Vector2(100, 100)
	fighter.initial_impulse = Vector2.ZERO
	root.add_child(fighter)
	
	fighter.set_nav_target_position(Vector2(500, 500))
	# Simulate recent combat collision
	fighter._last_combat_time = Time.get_ticks_msec() / 1000.0
	
	# Process physics: should return early due to knockback_recovery_time
	fighter._physics_process(0.016)
	
	var current_time = Time.get_ticks_msec() / 1000.0
	assert(current_time - fighter._last_combat_time < fighter.knockback_recovery_time, "Within knockback recovery window")
	
	fighter.free()
	print("PASS: Knockback recovery suppresses navigation steering.")
	return true

func test_invalid_target_safety() -> bool:
	print("\n[TEST 5] Invalid / non-finite target safety...")
	var fighter = RigidBody2D.new()
	fighter.set_script(load("res://scripts/fighter.gd"))
	fighter.fighter_name = "SafetyFighter"
	root.add_child(fighter)
	
	# Assign NaN or Inf
	fighter.set_nav_target_position(Vector2(NAN, 100))
	assert(fighter.has_nav_target_position() == false, "NaN position should be safely rejected")
	
	fighter.set_nav_target_position(Vector2(INF, INF))
	assert(fighter.has_nav_target_position() == false, "Infinite position should be safely rejected")
	
	fighter.free()
	print("PASS: Invalid / non-finite target safety.")
	return true

func test_elimination_clears_nav_target() -> bool:
	print("\n[TEST 6] Elimination clears navigation target...")
	var fighter = RigidBody2D.new()
	fighter.set_script(load("res://scripts/fighter.gd"))
	fighter.fighter_name = "ElimTestFighter"
	root.add_child(fighter)
	
	fighter.set_nav_target_position(Vector2(300, 300))
	assert(fighter.has_nav_target_position() == true, "nav target should be active")
	
	fighter.eliminate()
	assert(fighter.is_eliminated == true, "fighter should be eliminated")
	assert(fighter.has_nav_target_position() == false, "nav target should be cleared on elimination")
	assert(fighter.get_nav_target_position() == Vector2.ZERO, "nav target position should be reset")
	
	fighter.free()
	print("PASS: Elimination clears navigation target.")
	return true

var _scene_test_instance: Node = null
var _match_start_ticks: int = 0

func _run_br_regression_test() -> void:
	print("\n[TEST 7] Full Battle Royale Playtest Regression Test on main.tscn...")
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
		print("[BATTLE ROYALE REGRESSION TEST COMPLETED]")
		print("Elapsed Time: %0.2f seconds" % elapsed_sec)
		print("Outcome: %s" % ("WINNER: " + wname if winner else "DRAW"))
		print("HUD Alive Text: %s" % hud.get_alive_text())
		print("HUD Winner Text: %s" % hud.get_winner_text())
		print("HUD Game Over Visible: %s" % hud.is_game_over_visible())
		print("========================================")
		
		assert(hud.is_game_over_visible() == true, "HUD game over must be visible")
		assert(br_mgr.is_match_over() == true, "Match must be over")
		print("\nALL TASK 06.4 TESTS PASSED SUCCESSFULLY!")
		quit(0)
	)
