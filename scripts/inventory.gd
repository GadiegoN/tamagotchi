extends RefCounted
const Rules = preload("res://scripts/rules.gd")

static func fill_food(s: Dictionary) -> String:
	var amount := mini(Rules.FOOD_BOWL - int(s.food_bowl), int(s.inventory.food))
	if amount <= 0:
		return "Pote de comida cheio." if s.food_bowl == Rules.FOOD_BOWL else "Sem comida. Colete mais no jardim!"
	s.inventory.food -= amount
	s.food_bowl += amount
	return "%d porção(ões) no pote. Ele come sozinho quando precisa." % amount

static func fill_water(s: Dictionary) -> String:
	var amount := minf(Rules.WATER_BOWL - s.water_bowl, s.inventory.water)
	if amount <= 0:
		return "Pote de água cheio." if s.water_bowl >= Rules.WATER_BOWL else "Reservatório vazio. Busque água no jardim!"
	s.inventory.water -= amount
	s.water_bowl += amount
	return "Pote abastecido com %d ml." % amount

static func reward(s: Dictionary, food: int, water: int) -> String:
	var gained_food := mini(maxi(food, 0), Rules.CAPACITY.food - int(s.inventory.food))
	var gained_water := mini(maxi(water, 0), Rules.CAPACITY.water - int(s.inventory.water))
	s.inventory.food += gained_food
	s.inventory.water += gained_water
	var result := "Coleta: +%d comida e +%d ml de água." % [gained_food, gained_water]
	if gained_food < food or gained_water < water:
		result += " Estoque cheio: excedente deixado no jardim."
	return result
