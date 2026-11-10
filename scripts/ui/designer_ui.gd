extends Control

# DesignerUI
# Core interactive engineering assembly studio.
# Connects component selection, 3D modular model preview, real-time resource calculations,
# and aerospace constraint validation.

@onready var preview_3d: SpacecraftPreview = $VBoxMain/HBoxCenter/ViewportContainer/SubViewport/SpacecraftPreview
@onready var edit_craft_name: LineEdit = $VBoxMain/HeaderBar/HBox/EditCraftName
@onready var lbl_mission_name: Label = $VBoxMain/HeaderBar/HBox/LblMissionName

# Category buttons
@onready var btn_cat_all: Button = $VBoxMain/HBoxCenter/PanelLeft/VBox/ScrollCat/HBoxCat/BtnCatAll
@onready var btn_cat_struct: Button = $VBoxMain/HBoxCenter/PanelLeft/VBox/ScrollCat/HBoxCat/BtnCatStruct
@onready var btn_cat_power: Button = $VBoxMain/HBoxCenter/PanelLeft/VBox/ScrollCat/HBoxCat/BtnCatPower
@onready var btn_cat_inst: Button = $VBoxMain/HBoxCenter/PanelLeft/VBox/ScrollCat/HBoxCat/BtnCatInst
@onready var btn_cat_comm: Button = $VBoxMain/HBoxCenter/PanelLeft/VBox/ScrollCat/HBoxCat/BtnCatComm
@onready var btn_cat_prop: Button = $VBoxMain/HBoxCenter/PanelLeft/VBox/ScrollCat/HBoxCat/BtnCatProp
@onready var btn_cat_land: Button = $VBoxMain/HBoxCenter/PanelLeft/VBox/ScrollCat/HBoxCat/BtnCatLand
@onready var btn_cat_data: Button = $VBoxMain/HBoxCenter/PanelLeft/VBox/ScrollCat/HBoxCat/BtnCatData

@onready var list_components: VBoxContainer = $VBoxMain/HBoxCenter/PanelLeft/VBox/ScrollComps/ListComps

# Resource meters
@onready var bar_mass: ProgressBar = $VBoxMain/HBoxCenter/PanelRight/VBox/GridMeters/BarMass
@onready var lbl_mass_val: Label = $VBoxMain/HBoxCenter/PanelRight/VBox/GridMeters/LblMassVal
@onready var bar_cost: ProgressBar = $VBoxMain/HBoxCenter/PanelRight/VBox/GridMeters/BarCost
@onready var lbl_cost_val: Label = $VBoxMain/HBoxCenter/PanelRight/VBox/GridMeters/LblCostVal
@onready var bar_power: ProgressBar = $VBoxMain/HBoxCenter/PanelRight/VBox/GridMeters/BarPower
@onready var lbl_power_val: Label = $VBoxMain/HBoxCenter/PanelRight/VBox/GridMeters/LblPowerVal
@onready var lbl_comms_val: Label = $VBoxMain/HBoxCenter/PanelRight/VBox/GridMeters/LblCommsVal
@onready var lbl_deltav_val: Label = $VBoxMain/HBoxCenter/PanelRight/VBox/GridMeters/LblDeltaVVal
@onready var lbl_rel_val: Label = $VBoxMain/HBoxCenter/PanelRight/VBox/GridMeters/LblRelVal
@onready var lbl_science_val: Label = $VBoxMain/HBoxCenter/PanelRight/VBox/GridMeters/LblScienceVal

# Validation & Selected components list
@onready var list_selected: VBoxContainer = $VBoxMain/HBoxCenter/PanelRight/VBox/ScrollSelected/ListSelected
@onready var list_warnings: VBoxContainer = $VBoxMain/HBoxCenter/PanelRight/VBox/ScrollWarnings/ListWarnings
@onready var lbl_valid_status: Label = $VBoxMain/HBoxCenter/PanelRight/VBox/LblValidStatus

# Footer actions
@onready var btn_briefing: Button = $VBoxMain/FooterBar/HBox/BtnBriefing
@onready var btn_clear: Button = $VBoxMain/FooterBar/HBox/BtnClear
@onready var btn_launch: Button = $VBoxMain/FooterBar/HBox/BtnLaunch

var _current_filter: String = "All"
var _last_validation: ValidationResult

func _gm() -> Node:
	return get_node_or_null("/root/GameManager")

func _mm() -> Node:
	return get_node_or_null("/root/MissionManager")

func _sm() -> Node:
	return get_node_or_null("/root/SceneManager")

func _ready() -> void:
	UITheme.style_button(btn_briefing, false)
	UITheme.style_button(btn_clear, false)
	UITheme.style_button(btn_launch, true)

	var gm = _gm()
	var mm = _mm()

	# Auto-initialize default mission and spacecraft if opened directly
	if gm != null:
		if gm.current_mission == null and mm != null:
			var def_m = mm.get_mission("earth_observation")
			if def_m != null:
				gm.select_mission(def_m)
		if gm.current_spacecraft == null:
			gm.current_spacecraft = SpacecraftConfig.new()

	var cat_buttons = [
		btn_cat_all, btn_cat_struct, btn_cat_power, btn_cat_inst,
		btn_cat_comm, btn_cat_prop, btn_cat_land, btn_cat_data
	]
	for btn in cat_buttons:
		UITheme.style_button(btn, false)

	btn_cat_all.pressed.connect(func(): _set_filter("All"))
	btn_cat_struct.pressed.connect(func(): _set_filter("Structure"))
	btn_cat_power.pressed.connect(func(): _set_filter("Power"))
	btn_cat_inst.pressed.connect(func(): _set_filter("Instruments"))
	btn_cat_comm.pressed.connect(func(): _set_filter("Communications"))
	btn_cat_prop.pressed.connect(func(): _set_filter("Propulsion"))
	btn_cat_land.pressed.connect(func(): _set_filter("Landing"))
	btn_cat_data.pressed.connect(func(): _set_filter("Data"))

	btn_briefing.pressed.connect(_on_briefing_pressed)
	btn_clear.pressed.connect(_on_clear_pressed)
	btn_launch.pressed.connect(_on_launch_pressed)

	if gm != null and gm.current_spacecraft != null and not gm.current_spacecraft.spacecraft_name.is_empty():
		edit_craft_name.text = gm.current_spacecraft.spacecraft_name
	edit_craft_name.text_changed.connect(func(n_name):
		var cur_gm = _gm()
		if cur_gm != null and cur_gm.current_spacecraft != null:
			cur_gm.current_spacecraft.spacecraft_name = n_name
	)

	if gm != null and gm.current_mission != null:
		lbl_mission_name.text = "MISSION: " + gm.current_mission.mission_name.to_upper()
	else:
		lbl_mission_name.text = "MISSION: UNASSIGNED"

	_populate_components_list()
	_update_all()

func _set_filter(filter_name: String) -> void:
	_current_filter = filter_name
	_populate_components_list()

func _populate_components_list() -> void:
	for child in list_components.get_children():
		child.queue_free()

	var mm = _mm()
	if mm == null:
		return

	var all_comps = mm.get_all_components()
	for comp in all_comps:
		if _current_filter != "All" and comp.category != _current_filter:
			continue

		var item_card = _create_component_item_card(comp)
		list_components.add_child(item_card)

func _create_component_item_card(comp: SpaceComponent) -> Control:
	var card = PanelContainer.new()
	var is_installed = false
	var gm = _gm()
	if gm != null and gm.current_spacecraft != null:
		is_installed = gm.current_spacecraft.has_component(comp.id)

	var bg_col = Color(0.10, 0.16, 0.25, 0.95) if is_installed else Color(0.06, 0.09, 0.15, 0.90)
	var border_col = UITheme.COLOR_ACCENT_CYAN if is_installed else UITheme.COLOR_BORDER
	card.add_theme_stylebox_override("panel", UITheme.create_panel_style(bg_col, border_col, 4))

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	# Title + Add/Remove Button
	var hbox_top = HBoxContainer.new()
	var lbl_name = Label.new()
	lbl_name.text = comp.display_name
	lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_name.add_theme_color_override("font_color", UITheme.COLOR_TEXT_WHITE)
	lbl_name.add_theme_font_size_override("font_size", 13)

	var btn_toggle = Button.new()
	btn_toggle.text = "REMOVE" if is_installed else "+ ADD"
	btn_toggle.custom_minimum_size = Vector2(80, 26)
	UITheme.style_button(btn_toggle, is_installed)
	btn_toggle.pressed.connect(func(): _toggle_component(comp))

	hbox_top.add_child(lbl_name)
	hbox_top.add_child(btn_toggle)
	vbox.add_child(hbox_top)

	# Stats bar
	var hbox_stats = HBoxContainer.new()
	hbox_stats.add_theme_constant_override("separation", 10)
	
	var stat_text = "Mass: %.0fkg | Cost: $%.1fM" % [comp.mass, comp.cost]
	if comp.power_generation > 0.0:
		stat_text += " | Power: +%.0fW" % comp.power_generation
	elif comp.power_consumption > 0.0:
		stat_text += " | Power: -%.0fW" % comp.power_consumption

	if comp.science_value > 0.0:
		stat_text += " | Sci: +%.0f" % comp.science_value
	if comp.comms_bandwidth > 0.0:
		stat_text += " | Comms: %.0fM" % comp.comms_bandwidth
	if comp.delta_v_impulse > 0.0:
		stat_text += " | dV: +%.0fm/s" % comp.delta_v_impulse

	var lbl_stats = Label.new()
	lbl_stats.text = stat_text
	lbl_stats.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)
	lbl_stats.add_theme_font_size_override("font_size", 11)
	hbox_stats.add_child(lbl_stats)
	vbox.add_child(hbox_stats)

	# Tech explanation / heritage
	var lbl_desc = Label.new()
	lbl_desc.text = comp.description
	lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_desc.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)
	lbl_desc.add_theme_font_size_override("font_size", 11)
	vbox.add_child(lbl_desc)

	card.add_child(vbox)
	return card

func _toggle_component(comp: SpaceComponent) -> void:
	var gm = _gm()
	if gm == null or gm.current_spacecraft == null:
		return
	if gm.current_spacecraft.has_component(comp.id):
		gm.current_spacecraft.remove_component_by_id(comp.id)
	else:
		gm.current_spacecraft.add_component(comp)

	_populate_components_list()
	_update_all()

func _update_all() -> void:
	var gm = _gm()
	if gm == null or gm.current_spacecraft == null:
		return

	var sc = gm.current_spacecraft
	var mission = gm.current_mission
	sc.recalculate()

	# 1. Update 3D Preview
	if preview_3d != null:
		preview_3d.rebuild_spacecraft(sc)

	# 2. Resource Meters
	var summary = ResourceCalculator.calculate_summary(sc, mission)
	
	# Mass
	var mass_max = mission.mass_limit if mission != null else 1500.0
	bar_mass.max_value = mass_max
	bar_mass.value = sc.total_mass
	lbl_mass_val.text = "%.1f / %.0f kg (%.0f%%)" % [sc.total_mass, mass_max, (sc.total_mass / max(1.0, mass_max)) * 100.0]
	if sc.total_mass > mass_max:
		lbl_mass_val.add_theme_color_override("font_color", UITheme.COLOR_DANGER)
	else:
		lbl_mass_val.add_theme_color_override("font_color", UITheme.COLOR_SUCCESS)

	# Cost / Budget
	var cost_max = mission.budget_limit if mission != null else 500.0
	bar_cost.max_value = cost_max
	bar_cost.value = sc.total_cost
	lbl_cost_val.text = "$%.1fM / $%.0fM" % [sc.total_cost, cost_max]
	if sc.total_cost > cost_max:
		lbl_cost_val.add_theme_color_override("font_color", UITheme.COLOR_DANGER)
	else:
		lbl_cost_val.add_theme_color_override("font_color", UITheme.COLOR_SUCCESS)

	# Power
	var req_p = mission.power_requirement if mission != null else 250.0
	bar_power.max_value = max(req_p * 1.5, sc.total_power_generation)
	bar_power.value = max(0.0, sc.net_power)
	lbl_power_val.text = "Net: %+.0f W (Gen: %.0fW | Con: %.0fW | Req: %.0fW)" % [
		sc.net_power, sc.total_power_generation, sc.total_power_consumption, req_p
	]
	if sc.net_power < req_p:
		lbl_power_val.add_theme_color_override("font_color", UITheme.COLOR_WARNING if sc.net_power >= 0 else UITheme.COLOR_DANGER)
	else:
		lbl_power_val.add_theme_color_override("font_color", UITheme.COLOR_SUCCESS)

	# Telemetry & Delta-V
	lbl_comms_val.text = "Comms Bandwidth: %.1f Mbps (Target: %.1f Mbps)" % [
		sc.comms_capacity, (mission.communication_requirement if mission != null else 10.0)
	]
	lbl_deltav_val.text = "Impulse Delta-V: %.0f m/s (Target: %.0f m/s)" % [
		sc.total_delta_v, (mission.min_delta_v if mission != null else 500.0)
	]
	lbl_rel_val.text = "Calculated Reliability: %.1f%%" % [sc.average_reliability * 100.0]
	lbl_science_val.text = "Installed Science: %.0f Pts (Target: %.0f Pts)" % [
		sc.total_science_value, (mission.scientific_target if mission != null else 100.0)
	]

	# 3. Selected Components List
	for child in list_selected.get_children():
		child.queue_free()

	for comp in sc.selected_components:
		var h = HBoxContainer.new()
		var l = Label.new()
		l.text = "• " + comp.display_name
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_font_size_override("font_size", 11)
		l.add_theme_color_override("font_color", UITheme.COLOR_TEXT_WHITE)

		var b = Button.new()
		b.text = "✕"
		b.custom_minimum_size = Vector2(24, 20)
		UITheme.style_button(b, false)
		b.pressed.connect(func():
			sc.remove_component_by_id(comp.id)
			_populate_components_list()
			_update_all()
		)

		h.add_child(l)
		h.add_child(b)
		list_selected.add_child(h)

	# 4. Validation Engine
	_last_validation = MissionValidator.validate(sc, mission)
	for child in list_warnings.get_children():
		child.queue_free()

	if _last_validation.is_valid and _last_validation.warnings.is_empty():
		lbl_valid_status.text = "STATUS: NOMINAL (READY TO LAUNCH)"
		lbl_valid_status.add_theme_color_override("font_color", UITheme.COLOR_SUCCESS)
	elif _last_validation.is_valid:
		lbl_valid_status.text = "STATUS: LAUNCHABLE WITH %d WARNING(S)" % _last_validation.warnings.size()
		lbl_valid_status.add_theme_color_override("font_color", UITheme.COLOR_WARNING)
	else:
		lbl_valid_status.text = "STATUS: LAUNCH BLOCKED (%d CRITICAL ISSUES)" % _last_validation.errors.size()
		lbl_valid_status.add_theme_color_override("font_color", UITheme.COLOR_DANGER)

	for err in _last_validation.errors:
		var lbl = Label.new()
		lbl.text = "❌ " + err
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_color_override("font_color", UITheme.COLOR_DANGER)
		lbl.add_theme_font_size_override("font_size", 11)
		list_warnings.add_child(lbl)

	for warn in _last_validation.warnings:
		var lbl = Label.new()
		lbl.text = "⚠️ " + warn
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_color_override("font_color", UITheme.COLOR_WARNING)
		lbl.add_theme_font_size_override("font_size", 11)
		list_warnings.add_child(lbl)

	for tip in _last_validation.tips:
		var lbl = Label.new()
		lbl.text = "💡 " + tip
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_CYAN)
		lbl.add_theme_font_size_override("font_size", 11)
		list_warnings.add_child(lbl)

	btn_launch.disabled = not _last_validation.is_valid

func _on_launch_pressed() -> void:
	if _last_validation != null and _last_validation.is_valid:
		var sm = _sm()
		if sm != null:
			sm.switch_to_scene("simulation")

func _on_clear_pressed() -> void:
	var gm = _gm()
	if gm != null and gm.current_spacecraft != null:
		gm.current_spacecraft.clear()
	_populate_components_list()
	_update_all()

func _on_briefing_pressed() -> void:
	var sm = _sm()
	if sm != null:
		sm.switch_to_scene("briefing")
