extends SceneTree

func _init() -> void:
	call_deferred("_start_tests")

func _start_tests() -> void:
	print("========================================")
	print("STARTING TEST SUITE: Task 06.5 Maze Geometry & Checkpoint Triggers")
	print("========================================")
	
	var passed = true
	passed = await test_checkpoint_detection_and_no_duplicate() and passed
	passed = await test_checkpoint_exit_and_reentry() and passed
	passed = test_checkpoint_target_position_and_fighter_nav() and passed
	passed = await test_maze_arena_structure_and_wall_collision() and passed
	
	if not passed:
		print("FAILED: One or more unit tests failed.")
		quit(1)
		return
	
	print("\n--- Running Battle Royale Full Match Playtest Regression ---")
	_run_br_regression_test()

func test_checkpoint_detection_and_no_duplicate() -> bool:
	print("\n[TEST 1] Checkpoint trigger detection & duplicate prevention...")
	var cp_scene = load("res://scenes/checkpoint.tscn")
	var cp: Checkpoint = cp_scene.instantiate()
	cp.position = Vector2(200, 200)
	root.add_child(cp)
	
	var fighter_scene = load("res://scenes/fighter.tscn")
	var fighter: RigidBody2D = fighter_scene.instantiate()
	fighter.position = Vector2(0, 0)
	fighter.initial_impulse = Vector2.ZERO
	root.add_child(fighter)
	
	var enter_count = [0]
	var reported_fighter: Array[RigidBody2D] = [null]
	var reported_cp: Array[Checkpoint] = [null]
	
	cp.fighter_entered.connect(func(f, c):
		enter_count[0] += 1
		reported_fighter[0] = f
		reported_cp[0] = c
	)
	
	# Move fighter into checkpoint
	fighter.global_position = Vector2(200, 200)
	
	# Wait 2 physics frames for Area2D collision detection
	for i in range(5):
		await physics_frame
	
	assert(enter_count[0] == 1, "fighter_entered should fire exactly once upon entry")
	assert(reported_fighter[0] == fighter, "Reported fighter should match entrant")
	assert(reported_cp[0] == cp, "Reported checkpoint should match entered checkpoint")
	assert(cp.is_fighter_inside(fighter) == true, "is_fighter_inside should be true")
	assert(cp.get_overlapping_fighters().has(fighter) == true, "get_overlapping_fighters should contain entrant")
	
	# Keep fighter inside for several more frames: must NOT report duplicate enter
	for i in range(10):
		await physics_frame
	
	assert(enter_count[0] == 1, "enter_count must remain 1 while fighter stays inside trigger")
	
	fighter.free()
	cp.free()
	await physics_frame
	print("PASS: Checkpoint trigger detection & duplicate prevention.")
	return true

func test_checkpoint_exit_and_reentry() -> bool:
	print("\n[TEST 2] Checkpoint trigger exit and re-entry...")
	var cp_scene = load("res://scenes/checkpoint.tscn")
	var cp: Checkpoint = cp_scene.instantiate()
	cp.position = Vector2(300, 300)
	root.add_child(cp)
	
	var fighter_scene = load("res://scenes/fighter.tscn")
	var fighter: RigidBody2D = fighter_scene.instantiate()
	fighter.position = Vector2(300, 300) # start inside
	fighter.initial_impulse = Vector2.ZERO
	root.add_child(fighter)
	
	var enter_count = [0]
	var exit_count = [0]
	
	cp.fighter_entered.connect(func(f, c):
		enter_count[0] += 1
	)
	cp.fighter_exited.connect(func(f, c):
		exit_count[0] += 1
	)
	
	for i in range(5):
		await physics_frame
	
	assert(enter_count[0] == 1, "Initial entry should register")
	assert(cp.is_fighter_inside(fighter) == true, "Fighter inside")
	
	# Move fighter out
	fighter.global_position = Vector2(800, 800)
	
	for i in range(5):
		await physics_frame
	
	assert(exit_count[0] == 1, "fighter_exited should fire upon exiting")
	assert(cp.is_fighter_inside(fighter) == false, "Fighter no longer inside")
	assert(cp.get_overlapping_fighters().size() == 0, "No overlapping fighters")
	
	# Move fighter back in (re-entry)
	fighter.global_position = Vector2(300, 300)
	for i in range(5):
		await physics_frame
	
	assert(enter_count[0] == 2, "fighter_entered should fire again upon re-entry")
	assert(cp.is_fighter_inside(fighter) == true, "Fighter inside again")
	
	fighter.free()
	cp.free()
	await physics_frame
	print("PASS: Checkpoint trigger exit and re-entry.")
	return true

func test_checkpoint_target_position_and_fighter_nav() -> bool:
	print("\n[TEST 3] Checkpoint target position & fighter navigation assignment...")
	var cp_scene = load("res://scenes/checkpoint.tscn")
	var cp: Checkpoint = cp_scene.instantiate()
	cp.position = Vector2(450, 250)
	cp.target_offset = Vector2(15, -10)
	root.add_child(cp)
	
	# Check target position
	var expected_target = Vector2(465, 240)
	assert(cp.get_target_position() == expected_target, "get_target_position should equal position + offset")
	
	# Assign target position to fighter
	var fighter = RigidBody2D.new()
	fighter.set_script(load("res://scripts/fighter.gd"))
	fighter.fighter_name = "NavDemonstrator"
	root.add_child(fighter)
	
	fighter.set_nav_target_position(cp.get_target_position())
	assert(fighter.has_nav_target_position() == true, "Fighter has nav target")
	assert(fighter.get_nav_target_position() == expected_target, "Fighter nav target matches checkpoint")
	
	fighter.free()
	cp.free()
	print("PASS: Checkpoint target position & fighter navigation assignment.")
	return true

func test_maze_arena_structure_and_wall_collision() -> bool:
	print("\n[TEST 4] Maze arena hierarchy & wall collision blocking...")
	var maze_scene = load("res://scenes/maze_arena.tscn")
	var maze: Node2D = maze_scene.instantiate()
	root.add_child(maze)
	
	# Verify structure
	var walls: StaticBody2D = maze.get_node_or_null("MazeWalls") as StaticBody2D
	assert(walls != null, "MazeWalls StaticBody2D must exist")
	
	var cps: Node2D = maze.get_node_or_null("Checkpoints") as Node2D
	assert(cps != null, "Checkpoints container must exist")
	assert(cps.get_child_count() == 6, "Must have 6 checkpoints")
	
	var spawns: Node2D = maze.get_node_or_null("SpawnPoints") as Node2D
	assert(spawns != null, "SpawnPoints container must exist")
	assert(spawns.get_child_count() == 8, "Must have 8 spawn markers")
	
	# Physics Wall Collision Test:
	# Place fighter above DividerWall1 (center at y=220, thickness=30, top edge at y=205)
	# Fighter size is 48x48 (half-height 24).
	# So fighter should NOT be able to fall/move below y = 205 - 24 = 181!
	var fighter_scene = load("res://scenes/fighter.tscn")
	var fighter: RigidBody2D = fighter_scene.instantiate()
	fighter.position = Vector2(470, 150)
	fighter.initial_impulse = Vector2(0, 500) # drive downward into wall
	root.add_child(fighter)
	
	# Let physics simulate for 15 frames
	for i in range(15):
		await physics_frame
	
	# Fighter should collide with DividerWall1 and bounce/stop above y = 205
	assert(fighter.global_position.y < 205.0, "Fighter must be blocked above DividerWall1 top edge")
	
	fighter.free()
	maze.free()
	await physics_frame
	print("PASS: Maze arena hierarchy & wall collision blocking.")
	return true

var _scene_test_instance: Node = null
var _match_start_ticks: int = 0

func _run_br_regression_test() -> void:
	print("\n[TEST 5] Full Battle Royale Playtest Regression Test on main.tscn...")
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
		print("\nALL TASK 06.5 TESTS PASSED SUCCESSFULLY!")
		quit(0)
	)
