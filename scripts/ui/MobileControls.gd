extends CanvasLayer

@export var always_show_in_editor := false

@onready var controls: Control = $Controls

var _held_actions: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	controls.visible = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available() or always_show_in_editor
	# Web radio is intentionally parked for Public Beta while long-form audio is investigated.
	# Do not expose dead radio buttons to phone players.
	$Controls/Radio.visible = not OS.has_feature("web")
	_bind_hold_button($Controls/Steering/Left, "steer_left")
	_bind_hold_button($Controls/Steering/Right, "steer_right")
	_bind_hold_button($Controls/Pedals/Brake, "brake")
	_bind_hold_button($Controls/Pedals/Accelerate, "accelerate")
	_bind_hold_button($Controls/Handbrake, "handbrake")
	$Controls/Reset.pressed.connect(_pulse_action.bind("reset_vehicle"))
	$Controls/Pause.pressed.connect(_pulse_action.bind("pause"))
	$Controls/Radio/Toggle.pressed.connect(_pulse_action.bind("radio_toggle"))
	$Controls/Radio/Next.pressed.connect(_pulse_action.bind("radio_next"))

func _exit_tree() -> void:
	_release_all_actions()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release_all_actions()

func _bind_hold_button(button: BaseButton, action: StringName) -> void:
	button.button_down.connect(_press_action.bind(action))
	button.button_up.connect(_release_action.bind(action))

func _press_action(action: StringName) -> void:
	if _held_actions.has(action):
		return
	_held_actions[action] = true
	Input.action_press(action, 1.0)

func _release_action(action: StringName) -> void:
	if not _held_actions.erase(action):
		return
	Input.action_release(action)

func _pulse_action(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)

func _release_all_actions() -> void:
	for action: StringName in _held_actions.keys():
		Input.action_release(action)
	_held_actions.clear()
