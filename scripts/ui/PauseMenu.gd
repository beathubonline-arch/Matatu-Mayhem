extends CanvasLayer

@onready var panel: PanelContainer = $Panel
@onready var resume_button: Button = $Panel/VBox/Resume
@onready var restart_button: Button = $Panel/VBox/RestartRoute
@onready var quit_button: Button = $Panel/VBox/Quit

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	resume_button.pressed.connect(_resume)
	restart_button.pressed.connect(_restart)
	quit_button.pressed.connect(func(): get_tree().quit())

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if GameManager.current_state == GameManager.GameState.ROUTE_COMPLETE:
			return
		GameManager.toggle_pause()
		panel.visible = GameManager.current_state == GameManager.GameState.PAUSED
		get_viewport().set_input_as_handled()

func _resume() -> void:
	GameManager.set_game_state(GameManager.GameState.PLAYING)
	panel.visible = false

func _restart() -> void:
	var route = GameManager.current_route
	if route != null and route.has_method("restart_route"):
		route.call("restart_route")
	panel.visible = false
