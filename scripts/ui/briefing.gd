extends Control

# MissionBriefing
# Detailed pre-flight mission directive detailing scientific milestones,
# engineering constraints, and authentic NASA program heritage.

@onready var lbl_header: Label = $UI/PanelMain/VBox/Header/VBoxTitles/LblMissionTitle
@onready var lbl_subtitle: Label = $UI/PanelMain/VBox/Header/VBoxTitles/LblSubtitle
@onready var lbl_destination: Label = $UI/PanelMain/VBox/Header/LblDestination

@onready var val_budget: Label = $UI/PanelMain/VBox/HBoxTop/PanelConstraints/VBox/Grid/ValBudget
@onready var val_mass: Label = $UI/PanelMain/VBox/HBoxTop/PanelConstraints/VBox/Grid/ValMass
@onready var val_power: Label = $UI/PanelMain/VBox/HBoxTop/PanelConstraints/VBox/Grid/ValPower
@onready var val_comms: Label = $UI/PanelMain/VBox/HBoxTop/PanelConstraints/VBox/Grid/ValComms
@onready var val_deltav: Label = $UI/PanelMain/VBox/HBoxTop/PanelConstraints/VBox/Grid/ValDeltaV
@onready var val_duration: Label = $UI/PanelMain/VBox/HBoxTop/PanelConstraints/VBox/Grid/ValDuration

@onready var list_objectives: VBoxContainer = $UI/PanelMain/VBox/HBoxTop/PanelObjectives/VBox/Scroll/ListObjectives
@onready var list_required: VBoxContainer = $UI/PanelMain/VBox/HBoxBottom/PanelRequired/VBox/Scroll/ListRequired
@onready var rtxt_nasa: RichTextLabel = $UI/PanelMain/VBox/HBoxBottom/PanelNasa/VBox/RtxtNasa

@onready var btn_back: Button = $UI/PanelMain/VBox/Footer/BtnBack
@onready var btn_design: Button = $UI/PanelMain/VBox/Footer/BtnDesign

func _ready() -> void:
	UITheme.style_button(btn_back, false)
	UITheme.style_button(btn_design, true)

	btn_back.pressed.connect(_on_back_pressed)
	btn_design.pressed.connect(_on_design_pressed)

	_populate_briefing()

func _populate_briefing() -> void:
	var gm = get_node_or_null("/root/GameManager")
	var mm = get_node_or_null("/root/MissionManager")

	var mission: MissionConfig = gm.current_mission if gm != null else null
	if mission == null and mm != null:
		mission = mm.get_mission("earth_observation")
		if mission != null and gm != null:
			gm.select_mission(mission)

	if mission == null:
		return

	lbl_header.text = "MISSION BRIEFING // " + mission.mission_name.to_upper()
	lbl_subtitle.text = mission.subtitle
	lbl_destination.text = "TARGET: %s | DIFFICULTY: %s" % [mission.destination.to_upper(), mission.difficulty.to_upper()]

	val_budget.text = "$%.0f Million" % mission.budget_limit
	val_mass.text = "%.0f kg Max" % mission.mass_limit
	val_power.text = "%.0f Watts" % mission.power_requirement
	val_comms.text = "%.0f Mbps" % mission.communication_requirement
	val_deltav.text = "%.0f m/s" % mission.min_delta_v
	val_duration.text = "%.0f Days" % mission.duration_days

	# Objectives
	for child in list_objectives.get_children():
		child.queue_free()
	for obj in mission.objectives:
		var lbl = Label.new()
		lbl.text = "✓ " + obj
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_WHITE)
		lbl.add_theme_font_size_override("font_size", 13)
		list_objectives.add_child(lbl)

	# Required Components
	for child in list_required.get_children():
		child.queue_free()
	for req_id in mission.required_components:
		var comp = mm.get_component(req_id) if mm != null else null
		var lbl = Label.new()
		lbl.text = "★ " + (comp.display_name if comp != null else req_id)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)
		lbl.add_theme_font_size_override("font_size", 13)
		list_required.add_child(lbl)

	# NASA Educational Context
	rtxt_nasa.bbcode_enabled = true
	rtxt_nasa.text = "[color=#00e5ff][b]NASA HERITAGE & SCIENTIFIC PRINCIPLES:[/b][/color]\n\n"
	rtxt_nasa.text += mission.educational_context + "\n\n"
	rtxt_nasa.text += "[color=#ffb300][b]Official NASA Reference:[/b][/color] " + mission.nasa_reference_title + "\n"
	rtxt_nasa.text += "[color=#80b3ff]" + mission.nasa_reference_url + "[/color]"

func _on_design_pressed() -> void:
	var sm = get_node_or_null("/root/SceneManager")
	if sm != null:
		sm.switch_to_scene("designer")

func _on_back_pressed() -> void:
	var sm = get_node_or_null("/root/SceneManager")
	if sm != null:
		sm.switch_to_scene("mission_selection")
