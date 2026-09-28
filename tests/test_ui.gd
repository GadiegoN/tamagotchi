extends SceneTree
const Main = preload("res://scripts/main.gd")
const Rules = preload("res://scripts/rules.gd")
var app: Control
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func capture(filename: String) -> void:
	if "--capture-test" not in OS.get_cmdline_user_args():
		return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://tests/artifacts")
	root.get_texture().get_image().save_png("res://tests/artifacts/" + filename + ".png")

func run() -> void:
	root.size = Vector2i(520, 900)
	app = Main.new()
	app.persistence_enabled = false
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	# UI scenarios always start awake, independent of the developer's local hour.
	app.state.sleeping = false
	app.state.sleep_due = Time.get_unix_time_from_system() + Rules.DAY
	check(app.state.inventory.food == 10, "fresh UI")
	app.action("food")
	app.action("water")
	check(app.state.food_bowl == 3 and app.state.water_bowl == 300, "UI refill actions")
	await capture("01-home")
	check(not app.care_panel.visible and not app.details_panel.visible, "home hides secondary information")
	check(roundi(app.bars.hunger[1].value) == 88, "satiety displays the inverse of hunger")
	app.feed_button.pressed.emit()
	check(app.state.inventory.food == 6 and app.state.food_bowl == 3 and app.state.hunger < 1, "direct feed button keeps bowl food")
	await capture("05-hand-feeding")
	app.start_game()
	check(app.game.active and app.state.energy == 82, "minigame begins and charges once")
	check(app.game.items.size() == Rules.GAME_ITEMS, "collectibles spawn")
	await capture("02-garden")
	# Route the same mouse event used by the playable view through its input handler.
	var item: Dictionary = app.game.items[0]
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = item.position
	app.game._gui_input(click)
	check(app.game.destination == item.position, "click movement target")
	for step in range(200):
		if not app.game.items.has(item):
			break
		app.game._process(0.02)
	check(not app.game.items.has(item), "player moves and collects")
	check(app.game.water > 0, "water reward collected")
	var earned_water: int = app.game.water
	app.game.finish()
	check(not app.game.visible and app.state.inventory.water == mini(2000, 1700 + earned_water), "returns and credits reward")
	var after: int = app.state.inventory.water
	app.game.finish()
	check(app.state.inventory.water == after, "finish cannot duplicate rewards")
	app.start_game()
	app.game._process(Rules.GAME_SECONDS + 1)
	check(not app.game.active, "timer ends game")
	app.start_game()
	app.game.items.clear()
	app.game._process(0.02)
	check(not app.game.active, "collecting everything ends game")
	app.action("sleep")
	check(app.state.sleeping, "sleep UI")
	await capture("03-sleep")
	app.start_game()
	check(not app.game.active, "UI blocks playing asleep")
	app.action("sleep")
	check(not app.state.sleeping, "wake UI")
	var real_state: Dictionary = app.state.duplicate(true)
	app.toggle_debug()
	app.debug_offset += 12 * Rules.HOUR
	app.tick()
	check(app.state.updated_at > real_state.updated_at + 11 * Rules.HOUR, "debug advances hours")
	await capture("04-debug")
	app.end_debug()
	check(app.debug_offset == 0 and absf(app.state.updated_at - real_state.updated_at) < 30, "debug restores real clock")
	check(app.state.inventory.food == real_state.inventory.food, "debug restores inventory")
	print("UI TESTS: %d checks, %d failures" % [checks, failures])
	app.queue_free()
	await process_frame
	quit(1 if failures else 0)
