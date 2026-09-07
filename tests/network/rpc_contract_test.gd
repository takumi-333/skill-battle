extends SceneTree

const CLIENT_PATH := "res://scripts/match_prototype.gd"
const SERVER_PATH := "res://scripts/network/dedicated_server.gd"

func _init() -> void:
	var client_contract := _read_rpc_contract(CLIENT_PATH)
	var server_contract := _read_rpc_contract(SERVER_PATH)
	assert(client_contract == server_contract)
	assert(client_contract.get("receive_dedicated_snapshot", "") == "@rpc(\"authority\", \"unreliable_ordered\")")
	assert(client_contract.has("request_result_action"))
	print("dedicated RPC contract tests passed")
	quit()


func _read_rpc_contract(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	assert(file != null)
	var contract := {}
	var rpc_configuration := ""
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.begins_with("@rpc("):
			rpc_configuration = line
			continue
		if not rpc_configuration.is_empty() and line.begins_with("func "):
			var method_name := line.trim_prefix("func ").split("(", false, 1)[0]
			contract[method_name] = rpc_configuration
			rpc_configuration = ""
		elif not line.is_empty() and not line.begins_with("#"):
			rpc_configuration = ""
	file.close()
	return contract
