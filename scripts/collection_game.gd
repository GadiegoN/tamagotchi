extends Control
signal completed(food: int, water: int)
const Rules = preload("res://scripts/rules.gd")
const View = preload("res://scripts/pet_view.gd")
var active := false
var remaining := 0.0
var player := Vector2.ZERO
var destination := Vector2.ZERO
var items: Array[Dictionary] = []
var food := 0
var water := 0
var heading: Label
var instructions: Label
var exit_button: Button
var random := RandomNumberGenerator.new()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	heading = Label.new()
	heading.position = Vector2(24, 28)
	heading.add_theme_font_size_override("font_size", 26)
	add_child(heading)
	instructions = Label.new()
	instructions.position = Vector2(24, 78)
	instructions.text = "Colete frutas e gotas em 30 segundos.\nSetas / WASD ou clique e segure para andar.\nCada gota vale 150 ml. Cada fruta, 1 comida."
	instructions.add_theme_font_size_override("font_size", 16)
	add_child(instructions)
	exit_button = Button.new()
	exit_button.text = "Voltar com a coleta"
	exit_button.position = Vector2(24, 820)
	exit_button.size = Vector2(472, 48)
	exit_button.pressed.connect(finish)
	add_child(exit_button)
	hide()

func start() -> void:
	random.randomize()
	food = 0
	water = 0
	remaining = Rules.GAME_SECONDS
	items.clear()
	player = Vector2(size.x / 2, size.y / 2)
	destination = player
	for i in range(Rules.GAME_ITEMS):
		items.append({"position": Vector2(random.randf_range(40, size.x - 40), random.randf_range(200, size.y - 140)), "water": i % 2 == 0})
	active = true
	show()
	grab_focus()

func _process(delta: float) -> void:
	if not active:
		return
	remaining = maxf(0, remaining - delta)
	var direction := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	if direction.length() > 0:
		player += direction.normalized() * 230 * delta
		destination = player
	else:
		player = player.move_toward(destination, delta * 230)
	player.x = clampf(player.x, 24, size.x - 24)
	player.y = clampf(player.y, 175, size.y - 110)
	for i in range(items.size() - 1, -1, -1):
		if player.distance_to(items[i].position) < 30:
			if items[i].water:
				water += Rules.WATER_REWARD
			else:
				food += 1
			items.remove_at(i)
	heading.text = "Jardim · %02d s   |   %d frutas · %d ml" % [ceili(remaining), food, water]
	exit_button.position.y = size.y - 72
	exit_button.size.x = size.x - 48
	queue_redraw()
	if remaining <= 0 or items.is_empty():
		finish()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		destination = event.position
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		destination = event.position
	elif event is InputEventScreenTouch and event.pressed:
		destination = event.position
	destination.x = clampf(destination.x, 24, size.x - 24)
	destination.y = clampf(destination.y, 175, size.y - 110)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("142c38"))
	draw_style_box(View.box(Color("315a51"), 24), Rect2(14, 154, size.x - 28, size.y - 245))
	for item in items:
		var p: Vector2 = item.position
		if item.water:
			draw_circle(p, 12, Color("8ed6ea"))
			draw_colored_polygon(PackedVector2Array([p + Vector2(-11, -4), p + Vector2(0, -23), p + Vector2(11, -4)]), Color("8ed6ea"))
		else:
			draw_circle(p, 13, Color("efac79"))
			draw_line(p + Vector2(0, -12), p + Vector2(6, -20), Color("b2d68f"), 4)
	draw_circle(player + Vector2(-11, -14), 8, Color("f5c685"))
	draw_circle(player + Vector2(11, -14), 8, Color("f5c685"))
	draw_circle(player, 21, Color("f5c685"))
	draw_circle(player + Vector2(-7, -3), 3, Color("24394b"))
	draw_circle(player + Vector2(7, -3), 3, Color("24394b"))

func finish() -> void:
	if not active:
		return
	active = false
	hide()
	completed.emit(food, water)
