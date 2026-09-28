extends SceneTree
const Rules = preload("res://scripts/rules.gd")
const State = preload("res://scripts/pet_state.gd")
const Care = preload("res://scripts/care.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Store = preload("res://scripts/save_store.gd")
var checks := 0
var failed := 0
var base := float(Time.get_unix_time_from_datetime_string("2026-09-27T06:00:00"))

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failed += 1
		push_error("FAIL: " + description)

func close_to(a: float, b: float) -> bool:
	return absf(a - b) < 0.01

func _initialize() -> void:
	food_tests()
	water_tests()
	sleep_tests()
	toilet_tests()
	time_tests()
	save_tests()
	print("CARE TESTS: %d checks, %d failures" % [checks, failed])
	quit(1 if failed else 0)

func food_tests() -> void:
	var direct := State.fresh(base, 0)
	direct.food_bowl = 2
	Care.feed(direct)
	check(direct.hunger == 0 and direct.inventory.food == 9 and direct.food_bowl == 2, "hand feeding uses pantry and leaves bowl untouched")
	check(Care.status(direct) == "Comendo na mão" and direct.last_meal == base, "hand feeding visible reaction and meal record")
	Care.feed(direct)
	check(direct.inventory.food == 9, "full pet does not waste food")
	direct.hunger = 60
	direct.inventory.food = 0
	Care.feed(direct)
	check(direct.hunger == 60 and direct.food_bowl == 2, "hand feeding with empty pantry is rejected")
	direct.inventory.food = 3
	direct.sleeping = true
	Care.feed(direct)
	check(direct.inventory.food == 3 and direct.hunger == 60, "no hand feeding while asleep")
	var s := State.fresh(base, 0)
	check(s.inventory.food == 10 and s.food_bowl == 0, "initial food")
	Inventory.fill_food(s)
	check(s.inventory.food == 7 and s.food_bowl == 3, "food transfer")
	Inventory.fill_food(s)
	check(s.inventory.food == 7 and s.food_bowl == 3, "full bowl no transfer")
	s.hunger = 60.0
	Care.settle(s)
	check(s.food_bowl == 2 and s.inventory.food == 7 and s.hunger == 24, "only bowl consumed")
	s.hunger = 60.0
	Care.settle(s)
	check(s.food_bowl == 2, "only one meal per period")
	Care.advance(s, base + 6 * Rules.HOUR)
	check(s.food_bowl == 1, "afternoon meal")
	Care.advance(s, base + 12 * Rules.HOUR)
	check(s.food_bowl == 0, "evening meal")
	s.hunger = 90
	Care.advance(s, base + Rules.DAY)
	check(s.food_bowl == 0 and s.inventory.food == 7, "no direct pantry consumption")
	s.inventory.food = 0
	Inventory.fill_food(s)
	check(s.food_bowl == 0, "empty pantry")
	var message := Inventory.reward(s, 99, 9000)
	check(s.inventory.food == 10 and s.inventory.water == 2000 and "cheio" in message, "reward capacity and feedback")
	Inventory.reward(s, -10, -100)
	check(s.inventory.food == 10, "negative rewards rejected")

func water_tests() -> void:
	var s := State.fresh(base, 0)
	Inventory.fill_water(s)
	check(s.inventory.water == 1700 and s.water_bowl == 300, "water transfer")
	Inventory.fill_water(s)
	check(s.inventory.water == 1700, "full water bowl")
	Care.advance(s, base + 2 * Rules.HOUR)
	check(close_to(s.hydration, 62.5) and s.water_bowl == 300, "progressive thirst")
	Care.advance(s, base + 4 * Rules.HOUR)
	check(close_to(s.hydration, 100) and s.water_bowl == 200 and s.last_drink == base + 4 * Rules.HOUR, "drink at four hours")
	Care.advance(s, base + 12 * Rules.HOUR)
	check(s.water_bowl == 0 and s.inventory.water == 1700, "finite autonomous water")
	s.inventory.water = 0
	Inventory.fill_water(s)
	check(s.water_bowl == 0, "empty reservoir")
	s.water_bowl = 25.0
	s.hydration = 0.0
	Care.settle(s)
	check(s.water_bowl == 0 and close_to(s.hydration, 18.75), "partial drink")
	s.inventory.water = 40
	Inventory.fill_water(s)
	check(s.water_bowl == 40 and s.inventory.water == 0, "partial refill")

func sleep_tests() -> void:
	var s := State.fresh(base, 0)
	s.energy = 20.0
	Care.start_sleep(s)
	Care.advance(s, base + 4 * Rules.HOUR)
	check(s.sleeping and close_to(s.energy, 60), "four hours partial rest")
	Care.wake(s)
	check(not s.sleeping and s.sleep_quality == "Sono insuficiente", "interrupted rest")
	Care.start_sleep(s)
	Care.advance(s, base + 8 * Rules.HOUR)
	check(not s.sleeping and s.energy == 100, "eight hours complete")
	s = State.fresh(base, 0)
	check(Care.begin_game(s) == "" and s.energy == 82, "game cost")
	Care.start_sleep(s)
	check(Care.begin_game(s) != "" and s.energy == 82, "no game during sleep")
	Care.advance(s, base + 8 * Rules.HOUR)
	check(s.sleeping and s.energy < 100 and s.sleep_quality == "Sono prolongado", "extra activities require extra sleep")
	Care.advance(s, base + 8.75 * Rules.HOUR)
	check(not s.sleeping and s.energy == 100 and s.extra_rest == 0, "extra recovery complete")
	s = State.fresh(base, 0)
	s.energy = 10
	check(Care.begin_game(s) != "" and s.energy == 10, "low energy game blocked")
	s.energy = 100
	Care.advance(s, base + 10 * Rules.HOUR)
	check(s.energy == 100, "no passive energy drain")
	Care.advance(s, base + 16 * Rules.HOUR)
	check(s.sleeping, "automatic bedtime at 22")
	Care.advance(s, base + 24 * Rules.HOUR)
	check(not s.sleeping and s.sleep_duration == 8 * Rules.HOUR, "automatic morning wake")

func toilet_tests() -> void:
	var s := State.fresh(base, 0)
	Care.toilet(s)
	check(s.last_toilet == base, "early toilet no effect")
	Care.advance(s, base + 12 * Rules.HOUR)
	check(Care.status(s) == "Precisa de banheiro", "bathroom pending at twelve hours")
	Care.toilet(s)
	check(s.last_toilet == base + 12 * Rules.HOUR, "bathroom action")
	Care.advance(s, base + 26 * Rules.HOUR)
	check(Care.status(s) == "Banheiro urgente", "urgency after fourteen hours")
	Care.advance(s, base + 28 * Rules.HOUR)
	check(s.dirty and s.accidents == 1, "ignored urgency causes accident")
	var old_health: float = s.health
	Care.advance(s, base + 29 * Rules.HOUR)
	check(s.health < old_health, "neglect consequences")
	Care.toilet(s)
	check(not s.dirty, "cleaning")
	s.hunger = 0
	s.hydration = 100
	old_health = s.health
	Care.advance(s, base + 30 * Rules.HOUR)
	check(s.health > old_health, "health recovers with care")

func time_tests() -> void:
	check(Rules.period(base, 0) == "Manhã", "morning")
	check(Rules.period(base + 6 * Rules.HOUR, 0) == "Tarde", "afternoon")
	check(Rules.period(base + 12 * Rules.HOUR, 0) == "Noite", "evening")
	check(Rules.period(base + 18 * Rules.HOUR, 0) == "Madrugada", "midnight")
	check(Rules.calendar(base + 18 * Rules.HOUR, 0).day == 28, "date rollover")
	check(Rules.period(base, -10800) == "Madrugada", "local timezone")
	for duration in [300.0, 2 * Rules.HOUR, 6 * Rules.HOUR, 8 * Rules.HOUR, Rules.DAY, 3 * Rules.DAY]:
		var offline := State.fresh(base, 0)
		Inventory.fill_food(offline)
		Inventory.fill_water(offline)
		Care.begin_game(offline)
		var online := offline.duplicate(true)
		Care.advance(offline, base + duration)
		var cursor := base
		while cursor < base + duration:
			cursor = minf(cursor + 137, base + duration)
			Care.advance(online, cursor)
		for key in ["hunger", "hydration", "energy", "health", "food_bowl", "water_bowl", "last_meal", "last_drink", "last_toilet", "sleep_progress", "sleep_due"]:
			check(close_to(offline[key], online[key]), "offline equivalence %s / %.0f h" % [key, duration / Rules.HOUR])
	var s := State.fresh(base, 0)
	var report := Care.advance(s, base - Rules.HOUR)
	check(report.backwards and s.updated_at == base and s.hunger == 12, "backwards clock freeze")
	report = Care.advance(s, base + 365 * Rules.DAY)
	check(report.capped and s.updated_at == base + 365 * Rules.DAY and s.health >= 10, "long absence bounded, recoverable")

func save_tests() -> void:
	var path := "user://care_test.json"
	var store := Store.new()
	var s := State.fresh(base, 0)
	Inventory.fill_food(s)
	Inventory.fill_water(s)
	Care.begin_game(s)
	check(store.save_state(s, path), "first save")
	var loaded := store.load_state(base + 6 * Rules.HOUR, 0, path)
	check(loaded.inventory.food == s.inventory.food and loaded.inventory.water == s.inventory.water and loaded.energy == s.energy, "save roundtrip")
	Care.advance(loaded, base + 6 * Rules.HOUR)
	Care.advance(s, base + 6 * Rules.HOUR)
	check(close_to(loaded.hunger, s.hunger) and loaded.food_bowl == s.food_bowl, "reopen elapsed time")
	check(store.save_state(s, path), "replace save")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("broken save")
	file.close()
	loaded = store.load_state(base, 0, path)
	check(loaded.inventory.food == 7 and not store.notice.is_empty(), "backup recovery")
	check(store.save_state(loaded, path), "saving after backup recovery")
	var backup := store.load_state(base, 0, path + ".bak")
	check(backup.inventory.food == 7, "valid backup survives corrupt primary replacement")
	check(State.validate({"version": 1}, base, 0).is_empty(), "invalid schema")
	var invalid := State.fresh(base, 0)
	invalid.inventory.food = "invalid"
	check(State.validate(invalid, base, 0).is_empty(), "invalid inventory")
	for suffix in ["", ".bak", ".tmp", ".invalid"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
