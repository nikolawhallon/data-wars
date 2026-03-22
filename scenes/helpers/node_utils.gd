extends Node


func get_first_ancestor_in_group_for_node(node: Node, group_name: String) -> Node:
	var candidate: Node = node
	while candidate != null:
		if candidate.is_in_group(group_name):
			return candidate
		candidate = candidate.get_parent()
	return null

func get_nodes_in_group_for_node(node: Node, group_name: String) -> Array:
	var out: Array = []
	var stack: Array = [node]

	while not stack.is_empty():
		var n: Node = stack.pop_back()

		if n.is_in_group(group_name):
			out.append(n)

		for child in n.get_children():
			stack.append(child)

	return out
