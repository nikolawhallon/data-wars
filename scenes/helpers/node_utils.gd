extends Node


func get_first_ancestor_in_group(node: Node, group_name: String) -> Node:
	var candidate: Node = node
	while candidate != null:
		if candidate.is_in_group(group_name):
			return candidate
		candidate = candidate.get_parent()
	return null
