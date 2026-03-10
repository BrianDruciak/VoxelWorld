extends CanvasLayer

const ZONE_COLORS: Dictionary = {
	"SAFE HAVEN": Color(0.3, 0.85, 0.3),
	"THE WILDS": Color(0.8, 0.75, 0.2),
	"FROZEN WASTES": Color(0.4, 0.7, 0.95),
	"SCORCHED LANDS": Color(0.95, 0.35, 0.15),
	"THE VOID": Color(0.5, 0.1, 0.5),
}

@onready var crosshair: Label = $Crosshair
@onready var debug_label: Label = $DebugLabel
@onready var hotbar_container: HBoxContainer = $HotbarContainer
@onready var hotbar_label: Label = $HotbarLabel

# Health
var _health_bar: ProgressBar
var _health_label: Label

# Zone
var _zone_label: Label

# Run timer
var _timer_label: Label

# Extraction
var _extract_panel: PanelContainer
var _extract_label: Label
var _extract_bar: ProgressBar

# Mining progress
var _mine_bar: ProgressBar

# Death overlay
var _death_overlay: ColorRect
var _death_label: Label
var _death_details: Label

# Success overlay
var _success_overlay: ColorRect
var _success_label: Label
var _success_details: Label

# Shop/Upgrade menu (between-runs)
var _shop_overlay: ColorRect
var _shop_container: VBoxContainer
var _shop_title: Label
var _stash_label: Label
var _tab_container: HBoxContainer
var _tab_buttons: Array[Button] = []
var _tab_panels: Array[Control] = []
var _active_tab: int = 0
var _upgrade_grid: GridContainer
var _tool_grid: GridContainer
var _supply_grid: GridContainer
var _shop_close_btn: Button
var _shop_visible := false

# Full inventory UI
var _inv_overlay: ColorRect
var _inv_grid_panels: Array[Panel] = []
var _inv_hotbar_panels: Array[Panel] = []
var _inv_visible := false
var _held_item: Dictionary = {}
var _held_panel: Panel

# Minimap
var _minimap: Control

# VFX overlay
var _vfx_overlay: ColorRect

var _debug_visible := false
var _inventory_ref: Inventory


func _ready() -> void:
	_build_health_bar()
	_build_zone_label()
	_build_timer_label()
	_build_extraction_ui()
	_build_mine_bar()
	_build_death_overlay()
	_build_success_overlay()
	_build_vfx_overlay()
	_build_shop_menu()
	_build_inventory_grid()
	_build_minimap()
	_build_hotbar()


func set_inventory(inv: Inventory) -> void:
	_inventory_ref = inv
	inv.inventory_changed.connect(_on_inventory_changed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		_debug_visible = not _debug_visible
		debug_label.visible = _debug_visible


# ===== HOTBAR (9 inventory slots) =====

func _build_hotbar() -> void:
	for child in hotbar_container.get_children():
		child.queue_free()
	for i in 9:
		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(48, 48)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.15, 0.15, 0.15, 0.7)
		sb.corner_radius_top_left = 4
		sb.corner_radius_top_right = 4
		sb.corner_radius_bottom_left = 4
		sb.corner_radius_bottom_right = 4
		sb.border_color = Color(0.4, 0.4, 0.4, 0.6)
		sb.border_width_top = 1
		sb.border_width_bottom = 1
		sb.border_width_left = 1
		sb.border_width_right = 1
		panel.add_theme_stylebox_override("panel", sb)
		hotbar_container.add_child(panel)


func update_hotbar_from_inventory() -> void:
	if _inventory_ref == null:
		return
	var children: Array[Node] = hotbar_container.get_children()
	for i in mini(children.size(), 9):
		var panel: Panel = children[i]
		# Clear previous children
		for c in panel.get_children():
			c.queue_free()
		var slot: Dictionary = _inventory_ref.get_slot(i)
		var is_selected: bool = (i == _inventory_ref.selected_hotbar)
		_render_hotbar_panel(panel, slot, i, is_selected)

	# Update label
	var held_slot: Dictionary = _inventory_ref.get_hotbar_slot()
	if held_slot.is_empty():
		hotbar_label.text = ""
	else:
		hotbar_label.text = ItemDB.get_item_name(held_slot.get("id", 0))


func _render_hotbar_panel(panel: Panel, slot: Dictionary, index: int, selected: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4

	if slot.is_empty():
		sb.bg_color = Color(0.15, 0.15, 0.15, 0.7)
	else:
		sb.bg_color = ItemDB.get_item_color(slot.get("id", 0)).darkened(0.3)

	if selected:
		sb.border_color = Color.WHITE
		sb.border_width_top = 2
		sb.border_width_bottom = 2
		sb.border_width_left = 2
		sb.border_width_right = 2
	else:
		sb.border_color = Color(0.4, 0.4, 0.4, 0.6)
		sb.border_width_top = 1
		sb.border_width_bottom = 1
		sb.border_width_left = 1
		sb.border_width_right = 1

	panel.add_theme_stylebox_override("panel", sb)

	# Key number label
	var key_lbl := Label.new()
	key_lbl.text = str(index + 1)
	key_lbl.add_theme_font_size_override("font_size", 10)
	key_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.5))
	key_lbl.position = Vector2(2, 0)
	panel.add_child(key_lbl)

	if slot.is_empty():
		return

	var item_id: int = slot.get("id", 0)

	# Tool icon letter
	if ItemDB.is_tool_item(item_id):
		var icon_lbl := Label.new()
		icon_lbl.text = ItemDB.get_tool_icon(item_id)
		icon_lbl.add_theme_font_size_override("font_size", 22)
		icon_lbl.add_theme_color_override("font_color", ItemDB.get_item_color(item_id))
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		panel.add_child(icon_lbl)

		# Durability bar
		var dur: int = slot.get("durability", -1)
		var max_dur: int = ItemDB.get_tool_durability(item_id)
		if dur >= 0 and max_dur > 0:
			var ratio: float = float(dur) / float(max_dur)
			var dur_bar := ColorRect.new()
			dur_bar.size = Vector2(44.0 * ratio, 3)
			dur_bar.position = Vector2(2, 43)
			if ratio > 0.5:
				dur_bar.color = Color(0.2, 0.8, 0.2)
			elif ratio > 0.25:
				dur_bar.color = Color(0.9, 0.8, 0.1)
			else:
				dur_bar.color = Color(0.9, 0.2, 0.1)
			panel.add_child(dur_bar)
	else:
		# Block color swatch
		var swatch := ColorRect.new()
		swatch.color = ItemDB.get_item_color(item_id)
		swatch.set_anchors_preset(Control.PRESET_FULL_RECT)
		swatch.offset_left = 6
		swatch.offset_top = 6
		swatch.offset_right = -6
		swatch.offset_bottom = -6
		panel.add_child(swatch)

	# Stack count
	var count: int = slot.get("count", 0)
	if count > 1:
		var count_lbl := Label.new()
		count_lbl.text = str(count)
		count_lbl.add_theme_font_size_override("font_size", 12)
		count_lbl.add_theme_color_override("font_color", Color.WHITE)
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		count_lbl.offset_right = -3
		count_lbl.offset_bottom = -1
		panel.add_child(count_lbl)


func _on_inventory_changed() -> void:
	update_hotbar_from_inventory()
	if _inv_visible:
		_refresh_inventory_grid()


# ===== HEALTH BAR =====

func _build_health_bar() -> void:
	var container := VBoxContainer.new()
	container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	container.offset_top = 10.0
	container.offset_left = -120.0
	container.offset_right = 120.0
	container.offset_bottom = 50.0

	_health_bar = ProgressBar.new()
	_health_bar.custom_minimum_size = Vector2(240, 20)
	_health_bar.max_value = 100.0
	_health_bar.value = 100.0
	_health_bar.show_percentage = false
	var bar_sb := StyleBoxFlat.new()
	bar_sb.bg_color = Color(0.15, 0.15, 0.15, 0.8)
	bar_sb.corner_radius_top_left = 4
	bar_sb.corner_radius_top_right = 4
	bar_sb.corner_radius_bottom_left = 4
	bar_sb.corner_radius_bottom_right = 4
	_health_bar.add_theme_stylebox_override("background", bar_sb)
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = Color(0.8, 0.15, 0.15)
	fill_sb.corner_radius_top_left = 4
	fill_sb.corner_radius_top_right = 4
	fill_sb.corner_radius_bottom_left = 4
	fill_sb.corner_radius_bottom_right = 4
	_health_bar.add_theme_stylebox_override("fill", fill_sb)
	container.add_child(_health_bar)

	_health_label = Label.new()
	_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_health_label.add_theme_font_size_override("font_size", 12)
	_health_label.text = "100 / 100"
	container.add_child(_health_label)

	add_child(container)


func update_health(current: float, maximum: float) -> void:
	if _health_bar == null:
		return
	_health_bar.max_value = maximum
	_health_bar.value = current
	_health_label.text = "%d / %d" % [ceili(current), ceili(maximum)]

	var ratio := current / maximum if maximum > 0 else 0.0
	var fill_sb: StyleBoxFlat = _health_bar.get_theme_stylebox("fill")
	if ratio < 0.25:
		fill_sb.bg_color = Color(0.9, 0.1, 0.1)
	elif ratio < 0.5:
		fill_sb.bg_color = Color(0.9, 0.5, 0.1)
	else:
		fill_sb.bg_color = Color(0.8, 0.15, 0.15)


# ===== ZONE LABEL =====

func _build_zone_label() -> void:
	_zone_label = Label.new()
	_zone_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_zone_label.offset_top = 56.0
	_zone_label.offset_left = -150.0
	_zone_label.offset_right = 150.0
	_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zone_label.add_theme_font_size_override("font_size", 14)
	_zone_label.text = ""
	add_child(_zone_label)


func update_zone(zone_name: String) -> void:
	if _zone_label == null:
		return
	_zone_label.text = zone_name
	var c: Color = ZONE_COLORS.get(zone_name, Color.WHITE)
	_zone_label.add_theme_color_override("font_color", c)


# ===== RUN TIMER =====

func _build_timer_label() -> void:
	_timer_label = Label.new()
	_timer_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_timer_label.offset_top = 10.0
	_timer_label.offset_left = -120.0
	_timer_label.offset_right = -10.0
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_timer_label.add_theme_font_size_override("font_size", 18)
	_timer_label.text = "00:00"
	add_child(_timer_label)


func update_timer(run_time: float) -> void:
	if _timer_label == null:
		return
	var total_secs: int = int(run_time)
	@warning_ignore("integer_division")
	var mins: int = total_secs / 60
	var secs: int = total_secs % 60
	_timer_label.text = "%02d:%02d" % [mins, secs]


# ===== EXTRACTION UI =====

func _build_extraction_ui() -> void:
	_extract_panel = PanelContainer.new()
	_extract_panel.set_anchors_preset(Control.PRESET_CENTER)
	_extract_panel.offset_top = 60.0
	_extract_panel.offset_bottom = 130.0
	_extract_panel.offset_left = -120.0
	_extract_panel.offset_right = 120.0
	_extract_panel.visible = false

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	_extract_panel.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	_extract_label = Label.new()
	_extract_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_extract_label.add_theme_font_size_override("font_size", 16)
	_extract_label.text = "Hold E to Extract"
	vbox.add_child(_extract_label)

	_extract_bar = ProgressBar.new()
	_extract_bar.custom_minimum_size = Vector2(200, 12)
	_extract_bar.max_value = 1.0
	_extract_bar.value = 0.0
	_extract_bar.show_percentage = false
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	bar_bg.corner_radius_top_left = 3
	bar_bg.corner_radius_top_right = 3
	bar_bg.corner_radius_bottom_left = 3
	bar_bg.corner_radius_bottom_right = 3
	_extract_bar.add_theme_stylebox_override("background", bar_bg)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.2, 0.8, 0.3)
	bar_fill.corner_radius_top_left = 3
	bar_fill.corner_radius_top_right = 3
	bar_fill.corner_radius_bottom_left = 3
	bar_fill.corner_radius_bottom_right = 3
	_extract_bar.add_theme_stylebox_override("fill", bar_fill)
	vbox.add_child(_extract_bar)

	_extract_panel.add_child(vbox)
	add_child(_extract_panel)


func show_extraction_prompt(visible_: bool) -> void:
	if _extract_panel:
		_extract_panel.visible = visible_


func update_extraction_progress(progress: float) -> void:
	if _extract_bar:
		_extract_bar.value = progress


# ===== MINING PROGRESS BAR =====

func _build_mine_bar() -> void:
	_mine_bar = ProgressBar.new()
	_mine_bar.set_anchors_preset(Control.PRESET_CENTER)
	_mine_bar.offset_top = 30.0
	_mine_bar.offset_bottom = 38.0
	_mine_bar.offset_left = -40.0
	_mine_bar.offset_right = 40.0
	_mine_bar.max_value = 1.0
	_mine_bar.value = 0.0
	_mine_bar.show_percentage = false
	_mine_bar.visible = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.15, 0.15, 0.15, 0.8)
	bg.corner_radius_top_left = 2
	bg.corner_radius_top_right = 2
	bg.corner_radius_bottom_left = 2
	bg.corner_radius_bottom_right = 2
	_mine_bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.9, 0.7, 0.2)
	fill.corner_radius_top_left = 2
	fill.corner_radius_top_right = 2
	fill.corner_radius_bottom_left = 2
	fill.corner_radius_bottom_right = 2
	_mine_bar.add_theme_stylebox_override("fill", fill)
	add_child(_mine_bar)


func update_mining_progress(progress: float) -> void:
	if _mine_bar == null:
		return
	if progress <= 0.0 or progress >= 1.0:
		_mine_bar.visible = false
		_mine_bar.value = 0.0
	else:
		_mine_bar.visible = true
		_mine_bar.value = progress


# ===== DEATH OVERLAY =====

func _build_death_overlay() -> void:
	_death_overlay = ColorRect.new()
	_death_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_overlay.color = Color(0.1, 0.0, 0.0, 0.75)
	_death_overlay.visible = false
	_death_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -200.0
	vbox.offset_right = 200.0
	vbox.offset_top = -100.0
	vbox.offset_bottom = 100.0
	vbox.add_theme_constant_override("separation", 16)

	_death_label = Label.new()
	_death_label.text = "YOU DIED"
	_death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_label.add_theme_font_size_override("font_size", 48)
	_death_label.add_theme_color_override("font_color", Color(0.9, 0.15, 0.15))
	vbox.add_child(_death_label)

	_death_details = Label.new()
	_death_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_details.add_theme_font_size_override("font_size", 16)
	_death_details.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(_death_details)

	var hint := Label.new()
	hint.text = "Press ENTER to continue"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(hint)

	_death_overlay.add_child(vbox)
	add_child(_death_overlay)


func show_death(lost_ores: Dictionary, run_time: float, max_dist: float) -> void:
	_death_overlay.visible = true
	@warning_ignore("integer_division")
	var text := "Run time: %02d:%02d\nFurthest: %.0f blocks\n" % [
		int(run_time) / 60, int(run_time) % 60, max_dist]
	var total_lost := 0
	for ore_id in lost_ores:
		var count: int = lost_ores[ore_id]
		total_lost += count
		text += "Lost: %d %s\n" % [count, ItemDB.get_item_name(ore_id)]
	if total_lost == 0:
		text += "No resources lost."
	_death_details.text = text


func hide_death() -> void:
	_death_overlay.visible = false


func is_death_visible() -> bool:
	return _death_overlay.visible


# ===== SUCCESS OVERLAY =====

func _build_success_overlay() -> void:
	_success_overlay = ColorRect.new()
	_success_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_success_overlay.color = Color(0.0, 0.08, 0.0, 0.75)
	_success_overlay.visible = false
	_success_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -200.0
	vbox.offset_right = 200.0
	vbox.offset_top = -100.0
	vbox.offset_bottom = 100.0
	vbox.add_theme_constant_override("separation", 16)

	_success_label = Label.new()
	_success_label.text = "EXTRACTED!"
	_success_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_success_label.add_theme_font_size_override("font_size", 48)
	_success_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3))
	vbox.add_child(_success_label)

	_success_details = Label.new()
	_success_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_success_details.add_theme_font_size_override("font_size", 16)
	_success_details.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(_success_details)

	var hint := Label.new()
	hint.text = "Press ENTER to continue"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(hint)

	_success_overlay.add_child(vbox)
	add_child(_success_overlay)


func show_success(saved_ores: Dictionary, run_time: float, max_dist: float) -> void:
	_success_overlay.visible = true
	@warning_ignore("integer_division")
	var text := "Run time: %02d:%02d\nFurthest: %.0f blocks\n" % [
		int(run_time) / 60, int(run_time) % 60, max_dist]
	var total := 0
	for ore_id in saved_ores:
		var count: int = saved_ores[ore_id]
		total += count
		text += "Saved: %d %s\n" % [count, ItemDB.get_item_name(ore_id)]
	if total == 0:
		text += "No resources extracted."
	_success_details.text = text


func hide_success() -> void:
	_success_overlay.visible = false


func is_success_visible() -> bool:
	return _success_overlay.visible


# ===== VFX OVERLAY =====

func _build_vfx_overlay() -> void:
	_vfx_overlay = ColorRect.new()
	_vfx_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vfx_overlay.color = Color(0, 0, 0, 0)
	_vfx_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vfx_overlay)


func update_vfx(zone_name: String, health_ratio: float, run_time: float) -> void:
	if _vfx_overlay == null:
		return
	var color := Color(0, 0, 0, 0)
	match zone_name:
		"FROZEN WASTES":
			color = Color(0.5, 0.7, 1.0, 0.08 + sin(run_time * 1.5) * 0.03)
		"SCORCHED LANDS":
			color = Color(1.0, 0.3, 0.05, 0.1 + sin(run_time * 2.0) * 0.04)
		"THE VOID":
			color = Color(0.3, 0.0, 0.4, 0.15 + sin(run_time * 3.0) * 0.06)
		"THE WILDS":
			color = Color(0.2, 0.3, 0.0, 0.04)
	if health_ratio < 0.25 and health_ratio > 0.0:
		var pulse := (sin(run_time * 4.0) + 1.0) * 0.5
		color.r = maxf(color.r, 0.5 * pulse)
		color.a = maxf(color.a, 0.15 * pulse)
	_vfx_overlay.color = color


# ===== SHOP / UPGRADE MENU (between runs) =====

signal upgrade_purchase_requested(upgrade_id: String)
signal shop_purchase_requested(item_id: int)

func _build_shop_menu() -> void:
	_shop_overlay = ColorRect.new()
	_shop_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop_overlay.color = Color(0.0, 0.0, 0.0, 0.85)
	_shop_overlay.visible = false
	_shop_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	_shop_container = VBoxContainer.new()
	_shop_container.set_anchors_preset(Control.PRESET_CENTER)
	_shop_container.offset_left = -340.0
	_shop_container.offset_right = 340.0
	_shop_container.offset_top = -280.0
	_shop_container.offset_bottom = 280.0
	_shop_container.add_theme_constant_override("separation", 8)

	_shop_title = Label.new()
	_shop_title.text = "BASE CAMP"
	_shop_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_title.add_theme_font_size_override("font_size", 32)
	_shop_title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	_shop_container.add_child(_shop_title)

	_stash_label = Label.new()
	_stash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stash_label.add_theme_font_size_override("font_size", 13)
	_stash_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_shop_container.add_child(_stash_label)

	# Tab bar
	_tab_container = HBoxContainer.new()
	_tab_container.add_theme_constant_override("separation", 4)
	_tab_container.alignment = BoxContainer.ALIGNMENT_CENTER
	var tab_names: Array[String] = ["Upgrades", "Tools", "Supplies"]
	for i in tab_names.size():
		var btn := Button.new()
		btn.text = tab_names[i]
		btn.custom_minimum_size = Vector2(100, 30)
		btn.pressed.connect(_on_tab_pressed.bind(i))
		_tab_container.add_child(btn)
		_tab_buttons.append(btn)
	_shop_container.add_child(_tab_container)

	# Tab panels
	var scroll_upgrades := ScrollContainer.new()
	scroll_upgrades.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_upgrades.custom_minimum_size = Vector2(640, 360)
	_upgrade_grid = GridContainer.new()
	_upgrade_grid.columns = 1
	_upgrade_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_upgrade_grid.add_theme_constant_override("v_separation", 6)
	scroll_upgrades.add_child(_upgrade_grid)
	_shop_container.add_child(scroll_upgrades)
	_tab_panels.append(scroll_upgrades)

	var scroll_tools := ScrollContainer.new()
	scroll_tools.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_tools.custom_minimum_size = Vector2(640, 360)
	scroll_tools.visible = false
	_tool_grid = GridContainer.new()
	_tool_grid.columns = 1
	_tool_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tool_grid.add_theme_constant_override("v_separation", 6)
	scroll_tools.add_child(_tool_grid)
	_shop_container.add_child(scroll_tools)
	_tab_panels.append(scroll_tools)

	var scroll_supplies := ScrollContainer.new()
	scroll_supplies.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_supplies.custom_minimum_size = Vector2(640, 360)
	scroll_supplies.visible = false
	_supply_grid = GridContainer.new()
	_supply_grid.columns = 1
	_supply_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_supply_grid.add_theme_constant_override("v_separation", 6)
	scroll_supplies.add_child(_supply_grid)
	_shop_container.add_child(scroll_supplies)
	_tab_panels.append(scroll_supplies)

	_shop_close_btn = Button.new()
	_shop_close_btn.text = "Start Run (TAB)"
	_shop_close_btn.custom_minimum_size = Vector2(140, 36)
	_shop_close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_shop_close_btn.pressed.connect(_on_close_shop)
	_shop_container.add_child(_shop_close_btn)

	_shop_overlay.add_child(_shop_container)
	add_child(_shop_overlay)


func _on_tab_pressed(idx: int) -> void:
	_active_tab = idx
	for i in _tab_panels.size():
		_tab_panels[i].visible = (i == idx)
	for i in _tab_buttons.size():
		_tab_buttons[i].disabled = (i == idx)


func show_shop(upgrades: Array, stash: Dictionary, purchased: Dictionary, shop_listings: Array, supply_listings: Array) -> void:
	_shop_overlay.visible = true
	_shop_visible = true
	_update_stash_display(stash)
	_populate_upgrades(upgrades, stash, purchased)
	_populate_tools(shop_listings, stash)
	_populate_supplies(supply_listings, stash)
	_on_tab_pressed(_active_tab)


func _update_stash_display(stash: Dictionary) -> void:
	var text := "Stash: "
	var any := false
	for ore_id in ItemDB.ORE_IDS:
		var count: int = stash.get(ore_id, 0)
		if count > 0:
			text += "%d %s  " % [count, ItemDB.get_item_name(ore_id)]
			any = true
	if not any:
		text += "Empty"
	_stash_label.text = text


func _populate_upgrades(upgrades: Array, stash: Dictionary, purchased: Dictionary) -> void:
	for child in _upgrade_grid.get_children():
		child.queue_free()
	for upgrade in upgrades:
		_upgrade_grid.add_child(_create_upgrade_row(upgrade, stash, purchased))


func _create_upgrade_row(upgrade: Dictionary, stash: Dictionary, purchased: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.15, 0.15, 0.9)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)

	var name_lbl := Label.new()
	var cur_level: int = purchased.get(upgrade["id"], 0)
	var max_lvl: int = upgrade["max_level"]
	name_lbl.text = "%s  [%d/%d]" % [upgrade["name"], cur_level, max_lvl]
	name_lbl.add_theme_font_size_override("font_size", 16)
	if cur_level >= max_lvl:
		name_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	info.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = upgrade["description"]
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	info.add_child(desc_lbl)

	var cost_text := ""
	var can_afford := true
	if cur_level >= max_lvl:
		cost_text = "MAXED"
		can_afford = false
	else:
		var costs: Dictionary = upgrade["costs"]
		for ore_id in costs:
			var need: int = costs[ore_id]
			var have: int = stash.get(ore_id, 0)
			if have < need:
				can_afford = false
			cost_text += "%d/%d %s  " % [have, need, ItemDB.get_item_name(ore_id)]

	var cost_lbl := Label.new()
	cost_lbl.text = cost_text
	cost_lbl.add_theme_font_size_override("font_size", 12)
	cost_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4) if can_afford else Color(0.9, 0.4, 0.4))
	info.add_child(cost_lbl)

	hbox.add_child(info)

	var btn := Button.new()
	btn.text = "BUY" if cur_level < max_lvl else "MAX"
	btn.custom_minimum_size = Vector2(70, 32)
	btn.disabled = not can_afford
	if can_afford:
		btn.pressed.connect(func(): upgrade_purchase_requested.emit(upgrade["id"]))
	hbox.add_child(btn)

	panel.add_child(hbox)
	return panel


func _populate_tools(listings: Array, stash: Dictionary) -> void:
	for child in _tool_grid.get_children():
		child.queue_free()
	for item in listings:
		_tool_grid.add_child(_create_shop_row(item, stash))


func _populate_supplies(listings: Array, stash: Dictionary) -> void:
	for child in _supply_grid.get_children():
		child.queue_free()
	for item in listings:
		_supply_grid.add_child(_create_shop_row(item, stash))


func _create_shop_row(item: Dictionary, stash: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.15, 0.15, 0.9)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)

	var name_lbl := Label.new()
	var item_id: int = item.get("item_id", 0)
	var qty: int = item.get("qty", 1)
	var display_name: String = ItemDB.get_item_name(item_id)
	if qty > 1:
		display_name += " x%d" % qty
	name_lbl.text = display_name
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", ItemDB.get_item_color(item_id))
	info.add_child(name_lbl)

	var cost_text := "Cost: "
	var can_afford := true
	var costs: Dictionary = item.get("costs", {})
	for ore_id in costs:
		var need: int = costs[ore_id]
		var have: int = stash.get(ore_id, 0)
		if have < need:
			can_afford = false
		cost_text += "%d/%d %s  " % [have, need, ItemDB.get_item_name(ore_id)]

	var cost_lbl := Label.new()
	cost_lbl.text = cost_text
	cost_lbl.add_theme_font_size_override("font_size", 12)
	cost_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4) if can_afford else Color(0.9, 0.4, 0.4))
	info.add_child(cost_lbl)

	hbox.add_child(info)

	var btn := Button.new()
	btn.text = "BUY"
	btn.custom_minimum_size = Vector2(70, 32)
	btn.disabled = not can_afford
	if can_afford:
		btn.pressed.connect(func(): shop_purchase_requested.emit(item_id))
	hbox.add_child(btn)

	panel.add_child(hbox)
	return panel


func hide_shop() -> void:
	_shop_overlay.visible = false
	_shop_visible = false


func is_shop_visible() -> bool:
	return _shop_visible


func _on_close_shop() -> void:
	hide_shop()

# Legacy compat
func show_upgrades(upgrades: Array, stash: Dictionary, purchased: Dictionary) -> void:
	show_shop(upgrades, stash, purchased, [], [])

func hide_upgrades() -> void:
	hide_shop()

func is_upgrade_visible() -> bool:
	return _shop_visible


# ===== FULL INVENTORY GRID =====

func _build_inventory_grid() -> void:
	_inv_overlay = ColorRect.new()
	_inv_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_inv_overlay.color = Color(0.0, 0.0, 0.0, 0.75)
	_inv_overlay.visible = false
	_inv_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_CENTER)
	main_vbox.offset_left = -230.0
	main_vbox.offset_right = 230.0
	main_vbox.offset_top = -240.0
	main_vbox.offset_bottom = 240.0
	main_vbox.add_theme_constant_override("separation", 8)

	var title := Label.new()
	title.text = "INVENTORY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	main_vbox.add_child(title)

	# Main grid (slots 9-35) = 27 slots = 3 rows of 9
	var main_grid := GridContainer.new()
	main_grid.columns = 9
	main_grid.add_theme_constant_override("h_separation", 4)
	main_grid.add_theme_constant_override("v_separation", 4)
	_inv_grid_panels.clear()
	for i in 27:
		var panel := _create_inv_slot_panel()
		main_grid.add_child(panel)
		_inv_grid_panels.append(panel)
	main_vbox.add_child(main_grid)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	main_vbox.add_child(sep)

	# Hotbar (slots 0-8) at bottom
	var hotbar_grid := GridContainer.new()
	hotbar_grid.columns = 9
	hotbar_grid.add_theme_constant_override("h_separation", 4)
	hotbar_grid.add_theme_constant_override("v_separation", 4)
	_inv_hotbar_panels.clear()
	for i in 9:
		var panel := _create_inv_slot_panel()
		hotbar_grid.add_child(panel)
		_inv_hotbar_panels.append(panel)
	main_vbox.add_child(hotbar_grid)

	_inv_overlay.add_child(main_vbox)
	add_child(_inv_overlay)

	# Held item cursor panel (floats with mouse)
	_held_panel = Panel.new()
	_held_panel.custom_minimum_size = Vector2(48, 48)
	_held_panel.size = Vector2(48, 48)
	_held_panel.visible = false
	_held_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_held_panel)


func _create_inv_slot_panel() -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(48, 48)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.12, 0.12, 0.9)
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	sb.border_color = Color(0.3, 0.3, 0.3, 0.5)
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_width_left = 1
	sb.border_width_right = 1
	panel.add_theme_stylebox_override("panel", sb)
	panel.gui_input.connect(_on_inv_slot_gui_input.bind(panel))
	return panel


func show_inventory() -> void:
	_inv_visible = true
	_inv_overlay.visible = true
	_refresh_inventory_grid()


func hide_inventory() -> void:
	_inv_visible = false
	_inv_overlay.visible = false
	# Drop held item back into inventory
	if not _held_item.is_empty() and _inventory_ref:
		_inventory_ref.add_item(_held_item.get("id", 0), _held_item.get("count", 1), _held_item.get("durability", -1))
		_held_item = {}
		_held_panel.visible = false


func is_inventory_visible() -> bool:
	return _inv_visible


func _get_slot_index_for_panel(panel: Panel) -> int:
	var idx := _inv_hotbar_panels.find(panel)
	if idx >= 0:
		return idx  # Slots 0-8
	idx = _inv_grid_panels.find(panel)
	if idx >= 0:
		return idx + 9  # Slots 9-35
	return -1


func _on_inv_slot_gui_input(event: InputEvent, panel: Panel) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	if _inventory_ref == null:
		return
	var mb: InputEventMouseButton = event
	var slot_idx: int = _get_slot_index_for_panel(panel)
	if slot_idx < 0:
		return

	var slot: Dictionary = _inventory_ref.get_slot(slot_idx)

	if mb.button_index == MOUSE_BUTTON_LEFT:
		if _held_item.is_empty():
			# Pick up
			if not slot.is_empty():
				_held_item = slot.duplicate()
				_inventory_ref.set_slot(slot_idx, {})
		else:
			if slot.is_empty():
				# Place
				_inventory_ref.set_slot(slot_idx, _held_item.duplicate())
				_held_item = {}
			elif slot.get("id", -1) == _held_item.get("id", -1) and not ItemDB.is_tool_item(_held_item.get("id", 0)):
				# Merge stacks
				var max_stack: int = ItemDB.get_stack_size(_held_item.get("id", 0))
				var current: int = slot.get("count", 0)
				var adding: int = _held_item.get("count", 0)
				var space: int = max_stack - current
				if space >= adding:
					slot["count"] = current + adding
					_inventory_ref.set_slot(slot_idx, slot)
					_held_item = {}
				else:
					slot["count"] = max_stack
					_inventory_ref.set_slot(slot_idx, slot)
					_held_item["count"] = adding - space
			else:
				# Swap
				var temp: Dictionary = slot.duplicate()
				_inventory_ref.set_slot(slot_idx, _held_item.duplicate())
				_held_item = temp

	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		if _held_item.is_empty() and not slot.is_empty():
			# Split: take half
			var count: int = slot.get("count", 0)
			if count <= 1:
				_held_item = slot.duplicate()
				_inventory_ref.set_slot(slot_idx, {})
			else:
				var take: int = ceili(count / 2.0)
				_held_item = slot.duplicate()
				_held_item["count"] = take
				slot["count"] = count - take
				_inventory_ref.set_slot(slot_idx, slot)
		elif not _held_item.is_empty():
			# Place one
			if slot.is_empty():
				var placed: Dictionary = _held_item.duplicate()
				placed["count"] = 1
				_inventory_ref.set_slot(slot_idx, placed)
				_held_item["count"] -= 1
				if _held_item["count"] <= 0:
					_held_item = {}
			elif slot.get("id", -1) == _held_item.get("id", -1) and not ItemDB.is_tool_item(_held_item.get("id", 0)):
				var max_stack: int = ItemDB.get_stack_size(_held_item.get("id", 0))
				if slot.get("count", 0) < max_stack:
					slot["count"] = slot.get("count", 0) + 1
					_inventory_ref.set_slot(slot_idx, slot)
					_held_item["count"] -= 1
					if _held_item["count"] <= 0:
						_held_item = {}

	_update_held_panel()
	_refresh_inventory_grid()


func _refresh_inventory_grid() -> void:
	if _inventory_ref == null:
		return
	# Main grid (slots 9-35)
	for i in _inv_grid_panels.size():
		_render_inv_panel(_inv_grid_panels[i], _inventory_ref.get_slot(i + 9))
	# Hotbar (slots 0-8)
	for i in _inv_hotbar_panels.size():
		var is_sel: bool = (i == _inventory_ref.selected_hotbar)
		_render_inv_panel(_inv_hotbar_panels[i], _inventory_ref.get_slot(i), is_sel)


func _render_inv_panel(panel: Panel, slot: Dictionary, highlight: bool = false) -> void:
	for c in panel.get_children():
		c.queue_free()

	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3

	if slot.is_empty():
		sb.bg_color = Color(0.12, 0.12, 0.12, 0.9)
	else:
		sb.bg_color = ItemDB.get_item_color(slot.get("id", 0)).darkened(0.4)

	if highlight:
		sb.border_color = Color(0.9, 0.85, 0.3)
		sb.border_width_top = 2
		sb.border_width_bottom = 2
		sb.border_width_left = 2
		sb.border_width_right = 2
	else:
		sb.border_color = Color(0.3, 0.3, 0.3, 0.5)
		sb.border_width_top = 1
		sb.border_width_bottom = 1
		sb.border_width_left = 1
		sb.border_width_right = 1

	panel.add_theme_stylebox_override("panel", sb)

	if slot.is_empty():
		return

	var item_id: int = slot.get("id", 0)

	if ItemDB.is_tool_item(item_id):
		var icon_lbl := Label.new()
		icon_lbl.text = ItemDB.get_tool_icon(item_id)
		icon_lbl.add_theme_font_size_override("font_size", 20)
		icon_lbl.add_theme_color_override("font_color", ItemDB.get_item_color(item_id))
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		panel.add_child(icon_lbl)

		var dur: int = slot.get("durability", -1)
		var max_dur: int = ItemDB.get_tool_durability(item_id)
		if dur >= 0 and max_dur > 0:
			var ratio: float = float(dur) / float(max_dur)
			var dur_bar := ColorRect.new()
			dur_bar.size = Vector2(42.0 * ratio, 3)
			dur_bar.position = Vector2(3, 43)
			if ratio > 0.5:
				dur_bar.color = Color(0.2, 0.8, 0.2)
			elif ratio > 0.25:
				dur_bar.color = Color(0.9, 0.8, 0.1)
			else:
				dur_bar.color = Color(0.9, 0.2, 0.1)
			panel.add_child(dur_bar)
	else:
		var swatch := ColorRect.new()
		swatch.color = ItemDB.get_item_color(item_id)
		swatch.set_anchors_preset(Control.PRESET_FULL_RECT)
		swatch.offset_left = 6
		swatch.offset_top = 6
		swatch.offset_right = -6
		swatch.offset_bottom = -6
		panel.add_child(swatch)

	var count: int = slot.get("count", 0)
	if count > 1:
		var count_lbl := Label.new()
		count_lbl.text = str(count)
		count_lbl.add_theme_font_size_override("font_size", 11)
		count_lbl.add_theme_color_override("font_color", Color.WHITE)
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		count_lbl.offset_right = -2
		count_lbl.offset_bottom = -1
		panel.add_child(count_lbl)


func _update_held_panel() -> void:
	if _held_item.is_empty():
		_held_panel.visible = false
		return
	_held_panel.visible = true
	for c in _held_panel.get_children():
		c.queue_free()
	var sb := StyleBoxFlat.new()
	sb.bg_color = ItemDB.get_item_color(_held_item.get("id", 0)).darkened(0.2)
	sb.bg_color.a = 0.85
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	_held_panel.add_theme_stylebox_override("panel", sb)

	var item_id: int = _held_item.get("id", 0)
	if ItemDB.is_tool_item(item_id):
		var lbl := Label.new()
		lbl.text = ItemDB.get_tool_icon(item_id)
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.add_theme_color_override("font_color", ItemDB.get_item_color(item_id))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		_held_panel.add_child(lbl)
	else:
		var swatch := ColorRect.new()
		swatch.color = ItemDB.get_item_color(item_id)
		swatch.set_anchors_preset(Control.PRESET_FULL_RECT)
		swatch.offset_left = 6
		swatch.offset_top = 6
		swatch.offset_right = -6
		swatch.offset_bottom = -6
		_held_panel.add_child(swatch)

	var count: int = _held_item.get("count", 0)
	if count > 1:
		var lbl := Label.new()
		lbl.text = str(count)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		_held_panel.add_child(lbl)


func _process(_delta: float) -> void:
	if _held_panel and _held_panel.visible:
		var mouse_pos := get_viewport().get_mouse_position()
		_held_panel.position = mouse_pos + Vector2(4, 4)


# ===== MINIMAP =====

func _build_minimap() -> void:
	_minimap = MinimapControl.new()
	_minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_minimap.offset_top = 36.0
	_minimap.offset_right = -10.0
	_minimap.offset_left = -170.0
	_minimap.offset_bottom = 196.0
	_minimap.custom_minimum_size = Vector2(160, 160)
	add_child(_minimap)


func update_minimap(player_pos: Vector3, player_rot_y: float) -> void:
	if _minimap:
		(_minimap as MinimapControl).player_pos = player_pos
		(_minimap as MinimapControl).player_rot = player_rot_y
		_minimap.queue_redraw()


# ===== DEBUG =====

func update_debug(data: Dictionary) -> void:
	if not _debug_visible:
		return
	debug_label.text = (
		"FPS: %d\n" % Engine.get_frames_per_second()
		+ "Pos: %.1f, %.1f, %.1f\n" % [data.get("x", 0), data.get("y", 0), data.get("z", 0)]
		+ "Chunk: %d, %d\n" % [data.get("cx", 0), data.get("cz", 0)]
		+ "Loaded: %d  Pending: %d\n" % [data.get("loaded", 0), data.get("pending", 0)]
		+ "Biome: %s\n" % data.get("biome", "?")
		+ "Dist: %.0f" % data.get("dist", 0)
	)


# ===== MINIMAP INNER CLASS =====

class MinimapControl extends Control:
	const MAP_SCALE := 0.1  # px per block unit
	const ZONE_RADII: Array[float] = [128.0, 320.0, 560.0, 800.0]
	const ZONE_RING_COLORS: Array[Color] = [
		Color(0.3, 0.85, 0.3, 0.5),
		Color(0.8, 0.75, 0.2, 0.5),
		Color(0.4, 0.7, 0.95, 0.5),
		Color(0.95, 0.35, 0.15, 0.5),
	]

	var player_pos := Vector3.ZERO
	var player_rot := 0.0

	func _draw() -> void:
		var center := size / 2.0
		var radius := minf(size.x, size.y) / 2.0

		# Background
		draw_circle(center, radius, Color(0.05, 0.05, 0.08, 0.7))

		# Zone rings (player-centered: offset rings by player position)
		var player_offset := Vector2(-player_pos.x, -player_pos.z) * MAP_SCALE

		for i in ZONE_RADII.size():
			var ring_r: float = ZONE_RADII[i] * MAP_SCALE
			var ring_center := center + player_offset
			draw_arc(ring_center, ring_r, 0, TAU, 64, ZONE_RING_COLORS[i], 1.5)

		# Void outer ring
		var void_r: float = 800.0 * MAP_SCALE
		draw_arc(center + player_offset, void_r, 0, TAU, 64, Color(0.5, 0.1, 0.5, 0.4), 1.5)

		# Extraction beacon (world origin, pulsing green dot)
		var beacon_pos := center + player_offset
		var pulse: float = (sin(Time.get_ticks_msec() / 500.0) + 1.0) * 0.5
		var beacon_size: float = 3.0 + pulse * 2.0
		draw_circle(beacon_pos, beacon_size, Color(0.2, 0.95, 0.3, 0.6 + pulse * 0.3))

		# Player dot (always at center)
		draw_circle(center, 3.0, Color.WHITE)

		# Facing triangle
		var angle := -player_rot
		var tri_size := 6.0
		var tip := center + Vector2(sin(angle), -cos(angle)) * tri_size
		var left_pt := center + Vector2(sin(angle + 2.3), -cos(angle + 2.3)) * (tri_size * 0.5)
		var right_pt := center + Vector2(sin(angle - 2.3), -cos(angle - 2.3)) * (tri_size * 0.5)
		draw_colored_polygon(PackedVector2Array([tip, left_pt, right_pt]), Color(1.0, 1.0, 1.0, 0.8))

		# Border circle
		draw_arc(center, radius - 1.0, 0, TAU, 64, Color(0.4, 0.4, 0.4, 0.5), 1.0)
