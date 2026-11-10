extends Control

# MissionSelection
# Interactive 3D planetary selection allowing players to explore each destination,
# compare constraints, and select their mission.

@onready var btn_earth: Button = $UI/PanelLeft/VBox/BtnEarth
@onready var btn_moon: Button = $UI/PanelLeft/VBox/BtnMoon
@onready var btn_mars: Button = $UI/PanelLeft/VBox/BtnMars
@onready var btn_back: Button = $UI/PanelLeft/VBox/BtnBack
@onready var btn_proceed: Button = $UI/PanelRight/VBox/BtnProceed

@onready var planet_visual: PlanetVisualizer = $ViewportContainer/SubViewport/PlanetNode
@onready var lbl_mission_name: Label = $UI/PanelRight/VBox/LblMissionName
@onready var lbl_destination: Label = $UI/PanelRight/VBox/LblDestination
@onready var lbl_difficulty: Label = $UI/PanelRight/VBox/HBoxDiff/LblDifficulty
@onready var lbl_overview: Label = $UI/PanelRight/VBox/LblOverview
@onready var lbl_budget: Label = $UI/PanelRight/VBox/GridStats/ValBudget
@onready var lbl_mass: Label = $UI/PanelRight/VBox/GridStats/ValMass
@onready var lbl_power: Label = $UI/PanelRight/VBox/GridStats/ValPower
@onready var lbl_duration: Label = $UI/PanelRight/VBox/GridStats/ValDuration
@onready var list_challenges: VBoxContainer = $UI/PanelRight/VBox/ScrollChallenges/ListChallenges

var _selected_id: String = "earth_observation"

func _gm() -> Node:
	return get_node_or_null("/root/GameManager")

func _mm() -> Node:
	return get_node_or_null("/root/MissionManager")

func _sm() -> Node:
	return get_node_or_null("/root/SceneManager")

func _ready() -> void:
	UITheme.style_button(btn_earth, false)
	UITheme.style_button(btn_moon, false)
	UITheme.style_button(btn_mars, false)
	UITheme.style_button(btn_back, false)
	UITheme.style_button(btn_proceed, true)

	btn_earth.pressed.connect(func(): _select_mission_by_id("earth_observation"))
	btn_moon.pressed.connect(func(): _select_mission_by_id("lunar_exploration"))
	btn_mars.pressed.connect(func(): _select_mission_by_id("mars_rover"))
	btn_back.pressed.connect(_on_back_pressed)
	btn_proceed.pressed.connect(_on_proceed_pressed)

	_select_mission_by_id("earth_observation")

func _select_mission_by_id(m_id: String) -> void:
	_selected_id = m_id
	var mm = _mm()
	if mm == null:
		return

	var mission = mm.get_mission(m_id)
	if mission == null:
		return

	# Update 3D Planet
	if planet_visual != null:
		planet_visual.planet_type = mission.destination

	# Highlight active button
	_update_button_highlights()

	# Update Details Panel
	lbl_mission_name.text = mission.mission_name
	lbl_destination.text = "DESTINATION: %s (%s)" % [mission.destination.to_upper(), mission.subtitle]
	lbl_difficulty.text = "DIFFICULTY: %s" % mission.difficulty.to_upper()
	lbl_overview.text = mission.brief_overview

	lbl_budget.text = "$%.0fM" % mission.budget_limit
	lbl_mass.text = "%.0f kg" % mission.mass_limit
	lbl_power.text = "%.0f W" % mission.power_requirement
	lbl_duration.text = "%.0f Days" % mission.duration_days

	# Challenges list
	for child in list_challenges.get_children():
		child.queue_free()

	for constraint in mission.engineering_constraints:
		var c_lbl = Label.new()
		c_lbl.text = "• " + constraint
		c_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)
		c_lbl.add_theme_font_size_override("font_size", 12)
		list_challenges.add_child(c_lbl)

func _update_button_highlights() -> void:
	var buttons = {
		"earth_observation": btn_earth,
		"lunar_exploration": btn_moon,
		"mars_rover": btn_mars
	}
	for id in buttons.keys():
		var btn = buttons[id]
		if id == _selected_id:
			btn.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_CYAN)
		else:
			btn.add_theme_color_override("font_color", UITheme.COLOR_TEXT_WHITE)

func _on_proceed_pressed() -> void:
	var mm = _mm()
	var gm = _gm()
	var sm = _sm()
	if mm != null and gm != null and sm != null:
		var mission = mm.get_mission(_selected_id)
		if mission != null:
			gm.select_mission(mission)
			sm.switch_to_scene("briefing")

func _on_back_pressed() -> void:
	var sm = _sm()
	if sm != null:
		sm.switch_to_scene("main_menu")
