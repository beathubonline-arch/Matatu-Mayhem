class_name RouteCheckpoint
extends Area3D

signal passed(checkpoint: RouteCheckpoint)

@export var checkpoint_index := 0
var active := false
var completed := false

@onready var mesh: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_refresh_visual()

func set_active(value: bool) -> void:
	active = value
	_refresh_visual()

func mark_completed() -> void:
	completed = true
	active = false
	_refresh_visual()

func reset_checkpoint() -> void:
	completed = false
	active = false
	_refresh_visual()

func _on_body_entered(body: Node3D) -> void:
	if not active or completed:
		return
	if body == GameManager.get_player_vehicle():
		passed.emit(self)

func _refresh_visual() -> void:
	if mesh == null:
		return
	if completed:
		mesh.visible = false
	else:
		mesh.visible = active
