extends RefCounted
const Rules = preload("res://scripts/rules.gd")
const EPS = 0.001

static func record(s: Dictionary, message: String) -> void:
	var date := Rules.calendar(s.updated_at, int(s.timezone))
	s.events.append("%02d/%02d %02d:%02d · %s" % [date.day, date.month, date.hour, date.minute, message])
	if s.events.size() > 8:
		s.events.pop_front()

## Integrate between meaningful events, never replay frames or seconds.
static func advance(s: Dictionary, now: float) -> Dictionary:
	var elapsed := maxf(0, now - s.updated_at)
	var report := {"elapsed": elapsed, "capped": false, "backwards": now < s.updated_at}
	if elapsed > Rules.MAX_OFFLINE:
		var skipped := elapsed - Rules.MAX_OFFLINE
		for key in ["updated_at", "last_toilet", "sleep_due", "wake_until", "activity_until"]:
			s[key] += skipped
		report.capped = true
		record(s, "Ausência longa: cuidados calculados para os últimos 7 dias.")
	settle(s)
	while s.updated_at < now - EPS:
		var cursor: float = s.updated_at
		var local := cursor + float(s.timezone)
		var next_hour: float = (floor(local / Rules.HOUR) + 1) * Rules.HOUR - float(s.timezone)
		var boundary := minf(now, next_hour)
		var water_rate := Rules.WATER_RATE * (Rules.SLEEP_WATER_FACTOR if s.sleeping else 1.0)
		for threshold in [Rules.MEAL_THRESHOLD, 80.0, 100.0]:
			if s.hunger < threshold - EPS:
				boundary = minf(boundary, cursor + (threshold - s.hunger) / Rules.HUNGER_RATE * Rules.HOUR)
		for threshold in [Rules.DRINK_THRESHOLD, 10.0, 0.0]:
			if s.hydration > threshold + EPS:
				boundary = minf(boundary, cursor + (s.hydration - threshold) / water_rate * Rules.HOUR)
		for hours in [Rules.TOILET_HOURS, Rules.ACCIDENT_HOURS]:
			var due: float = s.last_toilet + hours * Rules.HOUR
			if due > cursor + EPS:
				boundary = minf(boundary, due)
		if s.sleeping:
			boundary = minf(boundary, cursor + maxf(EPS, s.sleep_goal - s.sleep_progress))
		else:
			var sleep_at := maxf(s.sleep_due, s.wake_until)
			if sleep_at > cursor + EPS:
				boundary = minf(boundary, sleep_at)
		integrate(s, boundary - cursor)
		s.updated_at = boundary
		settle(s)
	return report

static func integrate(s: Dictionary, seconds: float) -> void:
	var hours := seconds / Rules.HOUR
	var risk := 0.0
	if s.hunger >= 80.0 - EPS:
		risk += 1.5
	if s.hydration <= 10.0 + EPS:
		risk += 2.0
	if s.dirty:
		risk += 0.7
	if risk > 0:
		s.health = maxf(10, s.health - hours * risk)
	else:
		s.health = minf(100, s.health + hours * 1.5)
	s.hunger = minf(100, s.hunger + hours * Rules.HUNGER_RATE)
	s.hydration = maxf(0, s.hydration - hours * Rules.WATER_RATE * (Rules.SLEEP_WATER_FACTOR if s.sleeping else 1.0))
	if s.sleeping:
		s.sleep_progress = minf(s.sleep_goal, s.sleep_progress + seconds)
		s.sleep_duration = s.sleep_progress
		s.energy = lerpf(s.sleep_base_energy, 100, s.sleep_progress / maxf(1, s.sleep_goal))

static func settle(s: Dictionary) -> void:
	var now: float = s.updated_at
	if now - s.last_toilet >= Rules.ACCIDENT_HOURS * Rules.HOUR - EPS:
		s.last_toilet = now
		s.dirty = true
		s.accidents += 1
		record(s, "Escapou! Preciso de uma limpeza.")
	if s.sleeping and s.sleep_progress >= s.sleep_goal - EPS:
		s.sleeping = false
		s.energy = 100.0
		s.extra_rest = 0.0
		s.sleep_progress = 0.0
		s.sleep_goal = 0.0
		s.sleep_quality = "Sono completo"
		s.sleep_due = Rules.next_bedtime(now, int(s.timezone))
		record(s, "Acordei descansado!")
	if not s.sleeping and now >= maxf(s.sleep_due, s.wake_until) - EPS:
		start_sleep(s)
	if s.sleeping:
		return
	var meal := Rules.meal_key(now, int(s.timezone))
	if Rules.period(now, int(s.timezone)) != "Madrugada" and s.meal_key != meal and s.hunger >= Rules.MEAL_THRESHOLD - EPS and s.food_bowl > 0:
		s.food_bowl -= 1
		apply_meal(s, "Comendo")
		record(s, "Nhac! Comi uma porção do pote.")
	if s.hydration <= Rules.DRINK_THRESHOLD + EPS and s.water_bowl > 0:
		var drink := minf(Rules.DRINK_ML, s.water_bowl)
		s.water_bowl -= drink
		s.hydration = minf(100, s.hydration + drink * 0.75)
		s.last_drink = now
		s.activity = "Bebendo"
		s.activity_until = now + 8
		record(s, "Bebi %d ml de água." % drink)

static func apply_meal(s: Dictionary, activity: String) -> void:
	s.hunger = maxf(0, s.hunger - Rules.MEAL_RELIEF)
	s.last_meal = s.updated_at
	s.meal_key = Rules.meal_key(s.updated_at, int(s.timezone))
	s.activity = activity
	s.activity_until = s.updated_at + 8

static func feed(s: Dictionary) -> String:
	if s.sleeping:
		return "Estou dormindo. Me acorde para comer."
	if s.hunger < 1.0:
		return "Estou de barriguinha cheia!"
	if s.inventory.food <= 0:
		return "A comida acabou. Vamos buscar mais no jardim?"
	s.inventory.food -= 1
	apply_meal(s, "Comendo na mão")
	record(s, "Você me deu uma comidinha. Obrigado!")
	return "Nhac! Obrigado pela comidinha."

static func start_sleep(s: Dictionary) -> String:
	if s.sleeping:
		return "Já estou dormindo."
	if s.sleep_goal <= 0:
		s.sleep_goal = Rules.SLEEP_HOURS * Rules.HOUR + s.extra_rest
		s.sleep_base_energy = s.energy
		s.sleep_progress = 0.0
		s.sleep_started = s.updated_at
	s.last_sleep = s.updated_at
	s.sleeping = true
	s.sleep_quality = "Sono prolongado" if s.extra_rest > 0 else "Sono normal"
	record(s, "Hora de dormir. Meta: %.1f horas." % (s.sleep_goal / Rules.HOUR))
	return "Boa noite! A recuperação continua com o jogo fechado."

static func wake(s: Dictionary) -> String:
	if not s.sleeping:
		return "Já estou acordado."
	s.sleeping = false
	s.sleep_quality = "Sono insuficiente"
	s.sleep_due = s.updated_at + Rules.HOUR
	s.wake_until = s.sleep_due
	record(s, "Sono interrompido. Retomo o descanso em 1 hora.")
	return "Ainda faltam %.1f h de descanso. Volto a dormir em 1 h." % ((s.sleep_goal - s.sleep_progress) / Rules.HOUR)

static func toilet(s: Dictionary) -> String:
	if s.sleeping:
		return "Acorde o bichinho para levá-lo ao banheiro."
	if s.dirty:
		s.dirty = false
		record(s, "Tudo limpo. Obrigado pelo cuidado!")
		return "Ambiente limpo!"
	if s.updated_at - s.last_toilet < Rules.TOILET_HOURS * Rules.HOUR - EPS:
		return "Ainda não preciso. Minha rotina é de aproximadamente 12 horas."
	s.last_toilet = s.updated_at
	record(s, "Ufa! Fui ao banheiro.")
	return "Ufa! Necessidade atendida."

static func begin_game(s: Dictionary) -> String:
	if s.sleeping:
		return "Estou dormindo. Volte depois do descanso."
	if s.energy < Rules.GAME_COST:
		return "Energia insuficiente. Preciso dormir antes de brincar."
	s.energy -= Rules.GAME_COST
	s.extra_rest += Rules.GAME_RECOVERY
	if s.sleep_goal > 0:
		s.sleep_goal = maxf(0, s.sleep_goal - s.sleep_progress) + Rules.GAME_RECOVERY
		s.sleep_progress = 0.0
		s.sleep_base_energy = s.energy
	s.last_activity = s.updated_at
	record(s, "Brincadeira: -18 de energia e +45 min de descanso.")
	return ""

static func status(s: Dictionary) -> String:
	if s.sleeping:
		return "Dormindo"
	if s.activity_until > s.updated_at:
		return s.activity
	if s.dirty:
		return "Precisa de limpeza"
	if s.updated_at - s.last_toilet >= Rules.URGENT_HOURS * Rules.HOUR - EPS:
		return "Banheiro urgente"
	if s.updated_at - s.last_toilet >= Rules.TOILET_HOURS * Rules.HOUR - EPS:
		return "Precisa de banheiro"
	if s.hydration <= Rules.DRINK_THRESHOLD:
		return "Com sede"
	if s.hunger >= Rules.MEAL_THRESHOLD:
		return "Com fome"
	if s.energy < 35 or s.sleep_quality == "Sono insuficiente":
		return "Cansado"
	return "Explorando" if posmod(int(s.updated_at), 24) < 16 else "Acordado"
