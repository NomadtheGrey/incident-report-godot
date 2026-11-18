extends CanvasLayer

# The walkthrough's few words: where you are (zone label),
# what you're looking at (centre tag), what E would do
# (prompt chip), and the controls footer. Built in code so
# the scene file stays a single root node.

var _zone_label: Label = null
var _tag_label: Label = null
var _prompt_label: Label = null

func _ready() -> void:
	_zone_label = _make_label(Vector2(16, 12), 18, HORIZONTAL_ALIGNMENT_LEFT)
	add_child(_zone_label)
	var dot := _make_label(Vector2(0, 0), 20, HORIZONTAL_ALIGNMENT_CENTER)
	dot.text = "•"
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.position = Vector2(-10, -14)
	add_child(dot)
	_tag_label = _make_label(Vector2(0, 0), 17, HORIZONTAL_ALIGNMENT_CENTER)
	_tag_label.set_anchors_preset(Control.PRESET_CENTER)
	_tag_label.position = Vector2(-200, 16)
	_tag_label.size = Vector2(400, 28)
	add_child(_tag_label)
	_prompt_label = _make_label(Vector2(0, 0), 17, HORIZONTAL_ALIGNMENT_CENTER)
	_prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_label.position = Vector2(-250, -84)
	_prompt_label.size = Vector2(500, 28)
	add_child(_prompt_label)
	var footer := _make_label(Vector2(0, 0), 13, HORIZONTAL_ALIGNMENT_CENTER)
	footer.text = "Click: look · WASD: move · Shift: run · E: interact / lock · F: fan cord"
	footer.modulate = Color(1, 1, 1, 0.55)
	footer.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	footer.position = Vector2(-300, -40)
	footer.size = Vector2(600, 22)
	add_child(footer)

func _make_label(pos: Vector2, font_size: int, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.position = pos
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label

func set_zone(text: String) -> void:
	_zone_label.text = text

func set_tag(text: String) -> void:
	_tag_label.text = text

func set_prompt(text: String) -> void:
	_prompt_label.text = text
