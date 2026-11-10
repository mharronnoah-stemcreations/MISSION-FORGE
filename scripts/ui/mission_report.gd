extends Control

# MissionReport
# Post-flight debriefing presenting normalized multi-criteria scoring,
# root-cause engineering analysis, and educational NASA science takeaways.

@onready var lbl_title: Label = $UI/PanelMain/VBox/Header/VBox/LblTitle
@onready var lbl_rating: Label = $UI/PanelMain/VBox/Header/VBox/LblRating
@onready var lbl_final_score: Label = $UI/PanelMain/VBox/Header/LblFinalScore

# Category scores
@onready var val_sci: Label = $UI/PanelMain/VBox/HBoxTop/PanelScores/VBox/Grid/ValSci
@onready var val_rel: Label = $UI/PanelMain/VBox/HBoxTop/PanelScores/VBox/Grid/ValRel
@onready var val_eff: Label = $UI/PanelMain/VBox/HBoxTop/PanelScores/VBox/Grid/ValEff
@onready var val_bud: Label = $UI/PanelMain/VBox/HBoxTop/PanelScores/VBox/Grid/ValBud
@onready var val_com: Label = $UI/PanelMain/VBox/HBoxTop/PanelScores/VBox/Grid/ValCom

# Analysis lists
@onready var list_strengths: VBoxContainer = $UI/PanelMain/VBox/HBoxBottom/PanelFeedback/VBox/Scroll/VBoxFeedback/ListStrengths
@onready var list_weaknesses: VBoxContainer = $UI/PanelMain/VBox/HBoxBottom/PanelFeedback/VBox/Scroll/VBoxFeedback/ListWeaknesses
@onready var list_recs: VBoxContainer = $UI/PanelMain/VBox/HBoxBottom/PanelFeedback/VBox/Scroll/VBoxFeedback/ListRecs
@onready var list_takeaways: VBoxContainer = $UI/PanelMain/VBox/HBoxTop/PanelTakeaways/VBox/Scroll/ListTakeaways

# Actions
@onready var btn_redesign: Button = $UI/PanelMain/VBox/Footer/BtnRedesign
@onready var btn_new_mission: Button = $UI/PanelMain/VBox/Footer/BtnNewMission
@onready var btn_menu: Button = $UI/PanelMain/VBox/Footer/BtnMenu

func _gm() -> Node:
	return get_node_or_null("/root/GameManager")

func _sm() -> Node:
	return get_node_or_null("/root/SceneManager")

func _ready() -> void:
	UITheme.style_button(btn_redesign, true)
	UITheme.style_button(btn_new_mission, false)
	UITheme.style_button(btn_menu, false)

	btn_redesign.pressed.connect(_on_redesign_pressed)
	btn_new_mission.pressed.connect(_on_new_mission_pressed)
	btn_menu.pressed.connect(_on_menu_pressed)

	_populate_report()

func _populate_report() -> void:
	var gm = _gm()
	var result = gm.current_result if gm != null else null
	if result == null:
		# Fallback preview demo result
		result = MissionResult.new()
		result.mission_name = "TerraPulse-1"
		result.final_score = 88.5
		result.scientific_score = 92.0
		result.reliability_score = 86.0
		result.efficiency_score = 85.0
		result.budget_score = 90.0
		result.completion_score = 100.0
		result.strengths.append("High Scientific Output: Multispectral imager collected 100% target Earth datasets.")
		result.recommendations.append("Equip Li-Ion battery pack to maintain instrument heaters during orbital eclipse.")

	lbl_title.text = "MISSION EVALUATION REPORT // " + result.mission_name.to_upper()
	lbl_final_score.text = "%.1f" % result.final_score

	# Grade / Rating
	if result.final_score >= 90.0:
		lbl_rating.text = "RATING: OUTSTANDING (PRIME MISSION SUCCESS)"
		lbl_rating.add_theme_color_override("font_color", UITheme.COLOR_SUCCESS)
	elif result.final_score >= 75.0:
		lbl_rating.text = "RATING: NOMINAL (ALL PRIMARY OBJECTIVES ACHIEVED)"
		lbl_rating.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_CYAN)
	elif result.final_score >= 55.0:
		lbl_rating.text = "RATING: SATISFACTORY (PARTIAL MISSION SUCCESS)"
		lbl_rating.add_theme_color_override("font_color", UITheme.COLOR_WARNING)
	else:
		lbl_rating.text = "RATING: CRITICAL MISSION FAILURE / DATA LOSS"
		lbl_rating.add_theme_color_override("font_color", UITheme.COLOR_DANGER)

	val_sci.text = "%.1f / 100" % result.scientific_score
	val_rel.text = "%.1f / 100" % result.reliability_score
	val_eff.text = "%.1f / 100" % result.efficiency_score
	val_bud.text = "%.1f / 100" % result.budget_score
	val_com.text = "%.1f / 100" % result.completion_score

	# Strengths
	for child in list_strengths.get_children(): child.queue_free()
	for s in result.strengths:
		var l = Label.new()
		l.text = "✓ " + s
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_color_override("font_color", UITheme.COLOR_SUCCESS)
		l.add_theme_font_size_override("font_size", 12)
		list_strengths.add_child(l)
	if result.strengths.is_empty():
		var l = Label.new()
		l.text = "• No significant engineering margins identified."
		l.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)
		l.add_theme_font_size_override("font_size", 12)
		list_strengths.add_child(l)

	# Weaknesses
	for child in list_weaknesses.get_children(): child.queue_free()
	for w in result.weaknesses:
		var l = Label.new()
		l.text = "✗ " + w
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_color_override("font_color", UITheme.COLOR_DANGER)
		l.add_theme_font_size_override("font_size", 12)
		list_weaknesses.add_child(l)
	if result.weaknesses.is_empty():
		var l = Label.new()
		l.text = "• Flight executed within nominal constraints with zero anomalies."
		l.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)
		l.add_theme_font_size_override("font_size", 12)
		list_weaknesses.add_child(l)

	# Recommendations
	for child in list_recs.get_children(): child.queue_free()
	for r in result.recommendations:
		var l = Label.new()
		l.text = "➜ " + r
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)
		l.add_theme_font_size_override("font_size", 12)
		list_recs.add_child(l)
	if result.recommendations.is_empty():
		var l = Label.new()
		l.text = "• Vehicle design represents optimal systems trade-off for this flight profile."
		l.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)
		l.add_theme_font_size_override("font_size", 12)
		list_recs.add_child(l)

	# NASA Educational Takeaways
	for child in list_takeaways.get_children(): child.queue_free()
	for t in result.educational_takeaways:
		var l = Label.new()
		l.text = "★ " + t
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_color_override("font_color", UITheme.COLOR_TEXT_WHITE)
		l.add_theme_font_size_override("font_size", 12)
		list_takeaways.add_child(l)

func _on_redesign_pressed() -> void:
	var sm = _sm()
	if sm != null:
		sm.switch_to_scene("designer")

func _on_new_mission_pressed() -> void:
	var sm = _sm()
	if sm != null:
		sm.switch_to_scene("mission_selection")

func _on_menu_pressed() -> void:
	var sm = _sm()
	if sm != null:
		sm.switch_to_scene("main_menu")
