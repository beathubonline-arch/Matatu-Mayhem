extends Node

signal money_changed(total: int)

const ROUTE_BASE_REWARD := 1500
const FAST_FINISH_BONUS := 500
const FAST_FINISH_THRESHOLD := 75.0
const PASSENGER_FARE := 5000

func get_money() -> int:
	return int(SaveManager.data.get("money", 0))

func add_money(amount: int) -> void:
	SaveManager.data["money"] = get_money() + max(amount, 0)
	SaveManager.save_game()
	money_changed.emit(get_money())

func spend_money(amount: int) -> bool:
	var cost := maxi(amount, 0)
	if cost <= 0:
		return true
	if get_money() < cost:
		return false
	SaveManager.data["money"] = get_money() - cost
	SaveManager.save_game()
	money_changed.emit(get_money())
	return true

func add_passenger_fare(amount: int = PASSENGER_FARE) -> void:
	add_money(amount)

func calculate_route_reward(elapsed_seconds: float) -> int:
	var reward := ROUTE_BASE_REWARD
	if elapsed_seconds <= FAST_FINISH_THRESHOLD:
		reward += FAST_FINISH_BONUS
	return reward
