extends Control
## Procedural temporary art. Replace this view without changing care rules.
var state: Dictionary = {}
var status := "Acordado"
var phase := 0.0
var pet_x := 230.0
const INK = Color("24394b")

func _ready() -> void:
	custom_minimum_size = Vector2(0, 240)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	phase += delta
	var target := size.x * 0.5
	if status in ["Comendo", "Com fome"]:
		target = size.x * 0.23
	elif status in ["Bebendo", "Com sede"]:
		target = size.x * 0.77
	elif status == "Explorando":
		target += sin(phase * 0.45) * 90
	pet_x = move_toward(pet_x, target, delta * 55)
	queue_redraw()

func _draw() -> void:
	if state.is_empty():
		return
	var night: bool = state.sleeping
	draw_style_box(box(Color("243e58") if night else Color("cce5d8"), 22), Rect2(Vector2.ZERO, size))
	draw_circle(Vector2(size.x - 45, 40), 20, Color("f7e4ab"))
	if night:
		draw_circle(Vector2(size.x - 36, 33), 18, Color("243e58"))
	for i in range(8):
		var x := 25.0 + i * size.x / 8
		draw_line(Vector2(x, 167), Vector2(x + 4, 158), Color("88bda4"), 2)
	draw_style_box(box(Color("aacdb7") if not night else Color("354d62"), 20), Rect2(0, 170, size.x, 70))
	draw_circle(Vector2(48, 68), 22, Color("b6d9c5") if not night else Color("304b65"))
	draw_circle(Vector2(73, 66), 30, Color("b6d9c5") if not night else Color("304b65"))
	var bob := sin(phase * 4) * 3 if not night else sin(phase * 1.5)
	var center := Vector2(pet_x, 128 + bob)
	draw_set_transform(Vector2(pet_x, 168), 0, Vector2(1, 0.25))
	draw_circle(Vector2.ZERO, 43, Color(0.12, 0.24, 0.25, 0.15))
	draw_set_transform(Vector2.ZERO)
	var body := Color("f5c685") if state.health > 40 else Color("c2b4a2")
	draw_circle(center + Vector2(-27, -31), 17, body)
	draw_circle(center + Vector2(27, -31), 17, body)
	draw_circle(center + Vector2(-27, -31), 9, Color("e5a58b"))
	draw_circle(center + Vector2(27, -31), 9, Color("e5a58b"))
	draw_set_transform(center, 0, Vector2(1.15, 0.73 if night else 1.0))
	draw_circle(Vector2.ZERO, 39, body)
	draw_circle(Vector2(-23, 31), 12, body)
	draw_circle(Vector2(23, 31), 12, body)
	for eye_x in [-14, 14]:
		if night or status == "Cansado":
			draw_line(Vector2(eye_x - 5, -4), Vector2(eye_x + 5, -4), INK, 3, true)
		else:
			draw_circle(Vector2(eye_x, -6), 4.5, INK)
		draw_circle(Vector2(eye_x * 1.4, 7), 6, Color("ebad90"))
	if status in ["Comendo", "Comendo na mão", "Bebendo"]:
		draw_circle(Vector2(0, 10), 3 + absf(sin(phase * 8)) * 4, INK)
	else:
		draw_arc(Vector2(0, 5), 7, 0.15, PI - 0.15, 12, INK, 2, true)
	draw_set_transform(Vector2.ZERO)
	if night:
		caption(Vector2(pet_x + 45, 88), "z Z", Color("f7e4ab"), 25)
	elif status in ["Precisa de banheiro", "Banheiro urgente", "Precisa de limpeza", "Com fome", "Com sede", "Cansado"]:
		caption(Vector2(pet_x - 8, 67), "!", Color("b35c47"), 25)
	elif status in ["Comendo", "Comendo na mão", "Bebendo"]:
		caption(Vector2(pet_x + 43, 100), "♥", Color("c16c58"), 21)
	if status == "Comendo na mão":
		var food_at := center + Vector2(30 + sin(phase * 6) * 5, 16)
		draw_line(food_at + Vector2(8, 7), food_at + Vector2(32, 16), Color("e6c8ad"), 9, true)
		draw_circle(food_at, 9, Color("ac7652"))
	var food_x := size.x * 0.23
	var water_x := size.x * 0.77
	draw_style_box(box(Color("ae775b"), 9), Rect2(food_x - 37, 186, 74, 24))
	draw_style_box(box(Color("628da3"), 9), Rect2(water_x - 37, 186, 74, 24))
	for i in range(int(state.food_bowl)):
		draw_circle(Vector2(food_x - 20 + 20 * i, 189), 8, Color("f1d19a"))
	if state.water_bowl > 0:
		draw_style_box(box(Color("a4e0ec"), 5), Rect2(water_x - 31, 191, 62 * state.water_bowl / 300, 8))
	var bowl_ink := Color("e0e9de") if night else INK
	caption(Vector2(food_x - 37, 229), "%d / 3" % state.food_bowl, bowl_ink, 14)
	caption(Vector2(water_x - 42, 229), "%d ml" % state.water_bowl, bowl_ink, 14)
	if state.dirty:
		draw_circle(Vector2(size.x / 2, 204), 10, Color("8c6856"))
		draw_circle(Vector2(size.x / 2, 195), 7, Color("8c6856"))

func caption(at: Vector2, words: String, color: Color, font_size: int) -> void:
	draw_string(ThemeDB.fallback_font, at, words, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

static func box(color: Color, radius: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	return style
