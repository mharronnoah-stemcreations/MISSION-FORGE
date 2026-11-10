extends Control

# MainMenu
# Main entry screen featuring 3D animated space vista, game mode navigation,
# persistent records inspection, and educational briefing.

@onready var btn_start: Button = $UI/VBoxButtons/BtnStart
@onready var btn_records: Button = $UI/VBoxButtons/BtnRecords
@onready var btn_guide: Button = $UI/VBoxButtons/BtnGuide
@onready var btn_quit: Button = $UI/VBoxButtons/BtnQuit

@onready var modal_records: PanelContainer = $Modals/ModalRecords
@onready var modal_guide: PanelContainer = $Modals/ModalGuide
@onready var records_container: VBoxContainer = $Modals/ModalRecords/VBox/Scroll/RecordsList
@onready var btn_close_records: Button = $Modals/ModalRecords/VBox/BtnCloseRecords
@onready var btn_close_guide: Button = $Modals/ModalGuide/VBox/BtnCloseGuide

func _gm() -> Node:
	return get_node_or_null("/root/GameManager")

func _mm() -> Node:
	return get_node_or_null("/root/MissionManager")

func _sm() -> Node:
	return get_node_or_null("/root/SceneManager")

func _ready() -> void:
	UITheme.style_button(btn_start, true)
	UITheme.style_button(btn_records, false)
	UITheme.style_button(btn_guide, false)
	UITheme.style_button(btn_quit, false)
	UITheme.style_button(btn_close_records, false)
	UITheme.style_button(btn_close_guide, false)

	btn_start.pressed.connect(_on_start_pressed)
	btn_records.pressed.connect(_on_records_pressed)
	btn_guide.pressed.connect(_on_guide_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)
	
	btn_close_records.pressed.connect(func(): modal_records.visible = false)
	btn_close_guide.pressed.connect(func(): modal_guide.visible = false)

	modal_records.visible = false
	modal_guide.visible = false

func _on_start_pressed() -> void:
	var sm = _sm()
	if sm != null:
		sm.switch_to_scene("mission_selection")

func _on_records_pressed() -> void:
	_populate_records()
	modal_records.visible = true

func _on_guide_pressed() -> void:
	modal_guide.visible = true

func _on_quit_pressed() -> void:
	get_tree().quit()

func _populate_records() -> void:
	for child in records_container.get_children():
		child.queue_free()

	var gm = _gm()
	var mm = _mm()

	if gm == null or gm.mission_records.is_empty():
		var lbl = Label.new()
		lbl.text = "No mission records recorded yet. Complete your first mission simulation!"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)
		records_container.add_child(lbl)
		return

	for m_id in gm.mission_records.keys():
		var rec = gm.mission_records[m_id]
		var mission = mm.get_mission(m_id) if mm != null else null
		var m_title = mission.mission_name if mission != null else m_id

		var card = PanelContainer.new()
		card.add_theme_stylebox_override("panel", UITheme.create_panel_style(Color(0.1, 0.15, 0.24, 0.9)))
		
		var vbox = VBoxContainer.new()
		var h_title = Label.new()
		h_title.text = "%s (%s)" % [m_title, rec.get("best_rating", "Nominal")]
		h_title.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_CYAN)
		
		var stats_lbl = Label.new()
		stats_lbl.text = "High Score: %.1f / 100  |  Completed Flights: %d" % [
			rec.get("high_score", 0.0), rec.get("runs_completed", 0)
		]
		stats_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_WHITE)

		vbox.add_child(h_title)
		vbox.add_child(stats_lbl)
		card.add_child(vbox)
		records_container.add_child(card)
