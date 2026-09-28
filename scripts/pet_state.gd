extends RefCounted
const Rules = preload("res://scripts/rules.gd")

static func fresh(now: float, offset: int) -> Dictionary:
	var hour: int = Rules.calendar(now, offset).hour
	var sleep_due := now if hour >= Rules.BEDTIME or hour < 6 else Rules.next_bedtime(now, offset)
	return {
		"version": 1, "updated_at": now, "timezone": offset,
		"hunger": 12.0, "hydration": 100.0, "energy": 100.0, "health": 100.0,
		"inventory": {"food": 10, "water": 2000}, "food_bowl": 0, "water_bowl": 0.0,
		"last_meal": 0.0, "meal_key": "", "last_drink": now,
		"last_toilet": now, "dirty": false, "accidents": 0,
		"sleeping": false, "sleep_started": 0.0, "last_sleep": 0.0,
		"sleep_duration": 0.0, "sleep_progress": 0.0, "sleep_goal": 0.0,
		"sleep_base_energy": 100.0, "extra_rest": 0.0,
		"sleep_due": sleep_due, "wake_until": 0.0,
		"sleep_quality": "Ainda não dormiu", "last_activity": now,
		"activity_until": 0.0, "activity": "Acordado", "events": []
	}

static func validate(raw: Variant, now: float, offset: int) -> Dictionary:
	if not raw is Dictionary or raw.get("version") != 1:
		return {}
	var result := fresh(now, offset)
	for key in result:
		if not raw.has(key):
			return {}
		var expected: Variant = result[key]
		var value: Variant = raw[key]
		if expected is float or expected is int:
			if not (value is float or value is int) or not is_finite(float(value)):
				return {}
		elif typeof(value) != typeof(expected):
			return {}
		result[key] = value
	for key in ["hunger", "hydration", "energy", "health", "sleep_base_energy"]:
		result[key] = clampf(result[key], 0.0, 100.0)
	for key in Rules.CAPACITY:
		var amount: Variant = result.inventory.get(key)
		if not (amount is float or amount is int) or not is_finite(float(amount)):
			return {}
		result.inventory[key] = clampi(int(amount), 0, Rules.CAPACITY[key])
	result.food_bowl = clampi(int(result.food_bowl), 0, Rules.FOOD_BOWL)
	result.water_bowl = clampf(result.water_bowl, 0, Rules.WATER_BOWL)
	for key in ["sleep_progress", "sleep_goal", "extra_rest", "sleep_duration"]:
		result[key] = clampf(result[key], 0, Rules.MAX_OFFLINE)
	result.events = result.events.filter(func(item): return item is String).slice(-8)
	return result
