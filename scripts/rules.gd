extends RefCounted
## Rates per real hour. Only this file defines balancing and capacities.
const HOUR = 3600.0
const DAY = 86400.0
const MAX_OFFLINE = 7.0 * DAY
const CAPACITY = {"food": 10, "water": 2000}
const FOOD_BOWL = 3
const WATER_BOWL = 300
const HUNGER_RATE = 4.5
const MEAL_THRESHOLD = 25.0
const MEAL_RELIEF = 36.0
const WATER_RATE = 18.75
const SLEEP_WATER_FACTOR = 0.5
const DRINK_THRESHOLD = 25.0
const DRINK_ML = 100.0
const SLEEP_HOURS = 8.0
const BEDTIME = 22
const TOILET_HOURS = 12.0
const URGENT_HOURS = 14.0
const ACCIDENT_HOURS = 16.0
const GAME_COST = 18.0
const GAME_RECOVERY = 0.75 * HOUR
const GAME_SECONDS = 30.0
const GAME_ITEMS = 10
const WATER_REWARD = 150
const PERIODS = [[0, "Madrugada"], [6, "Manhã"], [12, "Tarde"], [18, "Noite"]]

static func calendar(stamp: float, offset: int) -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(int(stamp) + offset)

static func period(stamp: float, offset: int) -> String:
	var hour: int = calendar(stamp, offset).hour
	var result := "Madrugada"
	for entry in PERIODS:
		if hour >= entry[0]:
			result = entry[1]
	return result

static func meal_key(stamp: float, offset: int) -> String:
	var date := calendar(stamp, offset)
	return "%04d-%02d-%02d/%s" % [date.year, date.month, date.day, period(stamp, offset)]

static func next_bedtime(stamp: float, offset: int) -> float:
	var local := int(stamp) + offset
	var midnight := local - posmod(local, int(DAY))
	var bedtime := float(midnight + BEDTIME * 3600 - offset)
	return bedtime if bedtime > stamp else bedtime + DAY
