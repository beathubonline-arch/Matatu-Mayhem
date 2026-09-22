extends CanvasLayer

@export var corridor_service_path: NodePath
@export var performance_manager_path: NodePath

@onready var panel: PanelContainer = $Panel
@onready var resume_button: Button = $Panel/VBox/Resume
@onready var restart_button: Button = $Panel/VBox/RestartRoute
@onready var quality_button: Button = $Panel/VBox/Quality
@onready var quit_button: Button = $Panel/VBox/Quit

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	resume_button.pressed.connect(_resume)
	restart_button.pressed.connect(_restart)
	quality_button.pressed.connect(_cycle_quality)
	quit_button.pressed.connect(func(): get_tree().quit())
	_refresh_quality_text()

func _cycle_quality() -> void:
	var manager := get_node_or_null(performance_manager_path)
	if manager != null and manager.has_method("cycle_mode"):
		manager.call("cycle_mode")
	_refresh_quality_text()

func _refresh_quality_text() -> void:
	var selected := String(SaveManager.data.get("quality_mode", "AUTO"))
	quality_button.text = "QUALITY • %s • TAP TO CHANGE" % selected

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if GameManager.current_state in [GameManager.GameState.ROUTE_COMPLETE, GameManager.GameState.ROUTE_SELECT]:
			return
		GameManager.toggle_pause()
		panel.visible = GameManager.current_state == GameManager.GameState.PAUSED
		get_viewport().set_input_as_handled()

func _resume() -> void:
	GameManager.set_game_state(GameManager.GameState.PLAYING)
	panel.visible = false

func _restart() -> void:
	var corridor := get_node_or_null(corridor_service_path)
	if corridor != null and corridor.has_method("restart_corridor") and bool(corridor.get("active")):
		corridor.call("restart_corridor")
		GameManager.set_game_state(GameManager.GameState.PLAYING)
		panel.visible = false
		return
	var route = GameManager.current_route
	if route != null and route.has_method("restart_route"):
		route.call("restart_route")
	GameManager.set_game_state(GameManager.GameState.PLAYING)
	panel.visible = false
