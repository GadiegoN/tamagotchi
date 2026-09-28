extends SceneTree
const Main = preload("res://scripts/main.gd")
const State = preload("res://scripts/pet_state.gd")
const Store = preload("res://scripts/save_store.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Care = preload("res://scripts/care.gd")
const Rules = preload("res://scripts/rules.gd")
const PATH = "user://restart_test.json"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if "--write-fixture" in OS.get_cmdline_user_args():
		var now := Time.get_unix_time_from_system()
		var state := State.fresh(now - 6 * Rules.HOUR, 0)
		state.sleep_due = now + Rules.DAY
		Inventory.fill_food(state)
		Inventory.fill_water(state)
		Care.begin_game(state)
		var ok := Store.new().save_state(state, PATH)
		print("RESTART: separate-process fixture saved: ", ok)
		quit(0 if ok else 1)
		return
	var app := Main.new()
	app.save_path = PATH
	root.add_child(app)
	await process_frame
	var ok: bool = app.state.energy == 82 and app.state.inventory.food == 7 and app.state.inventory.water == 1700 and app.state.water_bowl == 200 and app.state.hydration > 60 and app.state.hydration < 63
	print("RESTART: loaded, processed six offline hours, retained inventory: ", ok)
	if not ok:
		quit(1)
		return
	# Exercise the actual close request, including final persistence.
	app._notification(Main.NOTIFICATION_WM_CLOSE_REQUEST)
