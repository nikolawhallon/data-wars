extends AnimatedSprite2D


signal liters_updated(value)

@export var liters: int = 600:
	set(value):
		liters = max(value, 0)
		liters_updated.emit(liters)

func decrement(amount: int) -> int:
	var consumed = min(liters, amount)
	liters -= consumed
	return consumed
