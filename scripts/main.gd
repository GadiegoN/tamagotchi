extends Control
const Rules = preload("res://scripts/rules.gd")
const State = preload("res://scripts/pet_state.gd")
const Care = preload("res://scripts/care.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Store = preload("res://scripts/save_store.gd")
const PetView = preload("res://scripts/pet_view.gd")
const Game = preload("res://scripts/collection_game.gd")
var state: Dictionary
var store := Store.new()
var clock_label: Label
var status_label: Label
var routine_label: Label
var resource_label: Label
var feedback: Label
var history: Label
var bars: Dictionary = {}
var pet: Control
var sleep_button: Button
var toilet_button: Button
var game: Control
var debug_panel: PanelContainer
var debug_info: Label
var debug_state: Dictionary = {}
var debug_offset := 0.0
var save_counter := 0
var persistence_enabled := true
var save_path := Store.PATH
var care_panel: VBoxContainer
var details_panel: VBoxContainer
var feed_button: Button

func _ready() -> void:
	get_tree().auto_accept_quit = false
	var now := Time.get_unix_time_from_system()
	state = store.load_state(now, int(Time.get_time_zone_from_system().bias) * 60, save_path) if persistence_enabled else State.fresh(now, int(Time.get_time_zone_from_system().bias) * 60)
	var report := Care.advance(state, now)
	state.timezone = int(Time.get_time_zone_from_system().bias) * 60
	build_ui()
	feedback.text = "Que bom te ver!"
	if report.elapsed > 60:
		feedback.text = "Você voltou! Vamos cuidar do seu bichinho?"
	if report.capped:
		feedback.text = "Ausência longa: calculamos até 7 dias de cuidados. Seu bichinho pode se recuperar."
	if report.backwards:
		feedback.text = "O relógio voltou. Os cuidados aguardam o último horário salvo, sem penalidade."
	if not store.notice.is_empty():
		feedback.text = store.notice
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(tick)
	add_child(timer)
	timer.start()
	refresh()
	persist()

func build_ui() -> void:
	var theme_new := Theme.new()
	theme_new.default_font_size = 16
	theme_new.set_color("font_color", "Label", Color("edf2e7"))
	for button_state in ["normal", "hover", "pressed", "focus"]:
		var style := PetView.box(Color("29454e") if button_state == "normal" else Color("41636a"), 12)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		theme_new.set_stylebox(button_state, "Button", style)
	theme = theme_new
	var background := ColorRect.new()
	background.color = Color("142c38")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	scroll.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := label(header, "Meu bichinho", 29)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clock_label = label(header, "", 17, Color("efc38a"))
	status_label = label(column, "", 17, Color("b8ddbe"))
	pet = PetView.new()
	column.add_child(pet)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 7)
	column.add_child(grid)
	for key in ["hunger", "hydration", "energy"]:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(cell)
		var caption := label(cell, "", 14)
		caption.tooltip_text = "Quanto maior, melhor."
		var bar := ProgressBar.new()
		bar.custom_minimum_size.y = 10
		bar.show_percentage = false
		bar.add_theme_stylebox_override("background", PetView.box(Color("29434c"), 5))
		bar.add_theme_stylebox_override("fill", PetView.box(Color("edbb83") if key == "hunger" else Color("a9d4bd"), 5))
		cell.add_child(bar)
		bars[key] = [caption, bar]
	feedback = label(column, "", 16, Color("f1ce99"))
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.custom_minimum_size.y = 42
	feed_button = button(column, "Dar alimento", func(): action("feed"))
	feed_button.custom_minimum_size.y = 58
	button(column, "Brincar no jardim", start_game)
	button(column, "Potes e cuidados", func(): care_panel.visible = not care_panel.visible)
	care_panel = VBoxContainer.new()
	care_panel.add_theme_constant_override("separation", 8)
	column.add_child(care_panel)
	care_panel.hide()
	var actions := GridContainer.new()
	actions.columns = 2
	actions.add_theme_constant_override("h_separation", 10)
	actions.add_theme_constant_override("v_separation", 8)
	care_panel.add_child(actions)
	button(actions, "Encher o potinho", func(): action("food"))
	button(actions, "Colocar água", func(): action("water"))
	toilet_button = button(actions, "Levar ao banheiro", func(): action("toilet"))
	sleep_button = button(actions, "Dormir", func(): action("sleep"))
	button(column, "Ver detalhes", func(): details_panel.visible = not details_panel.visible)
	details_panel = VBoxContainer.new()
	details_panel.add_theme_constant_override("separation", 10)
	column.add_child(details_panel)
	details_panel.hide()
	resource_label = label(details_panel, "", 15, Color("c7d6d0"))
	routine_label = label(details_panel, "", 14, Color("acc6ba"))
	routine_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label(details_panel, "DIÁRIO DE CUIDADOS", 12, Color("acc6ba"))
	history = label(details_panel, "", 13, Color("c7d6d0"))
	history.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if OS.is_debug_build():
		button(details_panel, "Laboratório de tempo (F3)", toggle_debug)
	game = Game.new()
	game.completed.connect(game_completed)
	add_child(game)
	build_debug()

func label(parent: Node, words: String, font_size: int, color: Color = Color("edf2e7")) -> Label:
	var node := Label.new()
	node.text = words
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	parent.add_child(node)
	return node

func button(parent: Node, words: String, callback: Callable) -> Button:
	var node := Button.new()
	node.text = words
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.custom_minimum_size.y = 44
	node.pressed.connect(callback)
	parent.add_child(node)
	return node

func current_time() -> float:
	return Time.get_unix_time_from_system() + debug_offset

func tick() -> void:
	Care.advance(state, current_time())
	if game.active and state.sleeping:
		game.finish()
	refresh()
	save_counter += 1
	if save_counter >= 30:
		save_counter = 0
		persist()

func action(kind: String) -> void:
	Care.advance(state, current_time())
	match kind:
		"feed": feedback.text = Care.feed(state)
		"food": feedback.text = Inventory.fill_food(state)
		"water": feedback.text = Inventory.fill_water(state)
		"toilet": feedback.text = Care.toilet(state)
		"sleep": feedback.text = Care.wake(state) if state.sleeping else Care.start_sleep(state)
	Care.settle(state)
	refresh()
	persist()

func start_game() -> void:
	Care.advance(state, current_time())
	var reason := Care.begin_game(state)
	if not reason.is_empty():
		feedback.text = reason
		refresh()
		return
	persist()
	game.start()
	refresh()

func game_completed(food: int, water: int) -> void:
	feedback.text = Inventory.reward(state, food, water)
	Care.record(state, feedback.text)
	refresh()
	persist()

func refresh() -> void:
	var date := Rules.calendar(current_time(), int(state.timezone))
	clock_label.text = "%02d:%02d" % [date.hour, date.minute]
	clock_label.tooltip_text = "%02d/%02d/%04d" % [date.day, date.month, date.year]
	var status := Care.status(state)
	status_label.text = "%s  ·  %s%s" % [Rules.period(current_time(), int(state.timezone)), status, "  · TESTE" if not debug_state.is_empty() else ""]
	pet.state = state
	pet.status = status
	var names := {"hunger": "Saciedade", "hydration": "Água", "energy": "Energia"}
	for key in bars:
		var value: float = 100.0 - state.hunger if key == "hunger" else state[key]
		bars[key][0].text = "%s  %d%%" % [names[key], roundi(value)]
		bars[key][1].value = value
	feed_button.text = "Dar alimento  ·  %d disponíveis" % state.inventory.food
	resource_label.text = "Despensa  %d/10%s   ·   Pote  %d/3\nReservatório  %d/2000 ml%s   ·   Pote  %d/300 ml" % [state.inventory.food, " CHEIA" if state.inventory.food == 10 else "", state.food_bowl, state.inventory.water, " CHEIO" if state.inventory.water == 2000 else "", state.water_bowl]
	resource_label.text += "\nSaúde: %d%%" % roundi(state.health)
	sleep_button.text = "Acordar" if state.sleeping else "Dormir"
	toilet_button.text = "Limpar ambiente" if state.dirty else "Levar ao banheiro"
	var toilet_hours := maxf(0, Rules.TOILET_HOURS - (state.updated_at - state.last_toilet) / Rules.HOUR)
	var sleep_text := "%s · %.1f/%.1f h" % [state.sleep_quality, state.sleep_progress / Rules.HOUR, state.sleep_goal / Rules.HOUR] if state.sleep_goal > 0 else "Sono às 22h · 8h + %.0f min de recuperação" % (state.extra_rest / 60)
	routine_label.text = "Refeições: manhã, tarde e noite · Água: ~4h\nBanheiro: %s · %s" % ["pendente!" if toilet_hours <= 0 else "em %.1f h" % toilet_hours, sleep_text]
	history.text = "Abasteça os potes. Eu cuido de comer e beber!" if state.events.is_empty() else "\n".join(state.events.slice(-3))
	if debug_panel.visible:
		debug_info.text = "CÓPIA TEMPORÁRIA · não altera o save\nReal: %s\nSimulado: %s\nÚltima atualização: %.0f\nFome %.1f | Água %.1f | Energia %.1f | Saúde %.1f\nEstoques: %s\nPotes: %d comida / %.0f ml\nRefeição: %.0f | Bebeu: %.0f\nSono: %.2f / %.2f h · %s\nBanheiro: %.0f | Acidentes: %d\nEstado: %s" % [Time.get_datetime_string_from_system(), Time.get_datetime_string_from_unix_time(int(current_time()) + int(state.timezone)), state.updated_at, state.hunger, state.hydration, state.energy, state.health, str(state.inventory), state.food_bowl, state.water_bowl, state.last_meal, state.last_drink, state.sleep_progress / Rules.HOUR, state.sleep_goal / Rules.HOUR, state.sleep_quality, state.last_toilet, state.accidents, status]

func persist() -> void:
	if not persistence_enabled or not debug_state.is_empty():
		return
	if not store.save_state(state, save_path):
		feedback.text = "Não foi possível salvar. Verifique o espaço e as permissões da pasta de dados."

func build_debug() -> void:
	debug_panel = PanelContainer.new()
	debug_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	debug_panel.add_theme_stylebox_override("panel", PetView.box(Color("142c38"), 0))
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	debug_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	margin.add_child(column)
	label(column, "Laboratório de tempo", 26)
	debug_info = label(column, "", 15)
	debug_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for hours in [4, 8, 12, 24]:
		button(column, "Avançar %d horas" % hours, func(): debug_offset += hours * Rules.HOUR; tick())
	button(column, "Ver bichinho e testar cuidados", func(): debug_panel.hide())
	button(column, "Encerrar teste e restaurar partida", end_debug)
	add_child(debug_panel)
	debug_panel.hide()

func toggle_debug() -> void:
	if not OS.is_debug_build() or game.active:
		return
	if debug_state.is_empty():
		persist()
		debug_state = state.duplicate(true)
		state = state.duplicate(true)
	debug_panel.visible = not debug_panel.visible
	refresh()

func end_debug() -> void:
	if debug_state.is_empty():
		return
	state = debug_state
	debug_state = {}
	debug_offset = 0
	debug_panel.hide()
	feedback.text = "Teste encerrado. Sua partida original foi restaurada."
	tick()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		toggle_debug()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if game != null and game.active:
			game.finish()
		end_debug()
		Care.advance(state, Time.get_unix_time_from_system())
		persist()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		persist()
