extends Node
class_name EnemyDecider

signal decision_made(command: String)
signal decision_failed(error: String)

const OPENAI_URL := "https://oaiproxy.vacuumbrewstudios.com/v1/responses"
@export var model := "gpt-4o"

var http: HTTPRequest
var busy := false

var prompt = """
You are the Enemy Team in the RTS game Data Wars. You control the game by telling commands to an AI agent named Deepgame.

Game summary:
Two teams compete: Player and Enemy. The goal is to build Spam Bots and send them to Transmission Towers to earn Clicks. Each Spam Bot that reaches a Transmission Tower gives 1 Click. The game ends when no more Water remains on the map - then the Team with the most Clicks wins.

Map:
A finite grid map (A1, B3, etc.). Buildings can only be constructed on Sites.

Buildings:

    Data Center: builds Spam Bots

    Skunk Works: builds Data Drones and Skunk Drones

Data Centers drain Water from the map to produce Data.

Units:

    Extractor: collects Minerals from Mines

    Data Drone: collects Data from enemy Data Centers

    Skunk Drone: combat unit

    Spam Bot: scoring unit that can be dispatched to Transmission Towers

Your commands may involve building structures, producing units, or moving units.

General strategy:
	If you need more Minerals, send extractors to Mines to mine Minerals
	If there are any extractors which are not mining, prioritize sending them to Mines
	Otherwise prioritize building Spam Bots to score Clicks
	Remember, if you have Spam Bots, don't let them idle, send them to Transmission Towers
	And if you ever have more than 100 Minerals, prioritizing building new buildings if Sites are available
	Build Data Centers to produce Data and to build Spam Bots
	Build Spam Bots at Data Centers and send them to Transmission Towers to score Clicks
	Build Skunk Works to build Skunk Drones and Data Drones
	Send Data Drones to the other Team's Data Centers to steal Data, don't let Data Drones idle
	Send Skunk Drones to the other Team's units to destroy them, only let them idle if protecting an area

Only give ONE, TWO, THREE, or FOUR SHORT commands at a time.
The commands could use words like "all" or "two" or "five" to execute multiple actions with a single command.
For example "move all Extractors to a Mine" or "have all Data Centers produce Spam Bots" or "build two new Skunk Works."
Do not move Extractors which are already mining Minerals.
Do not move Data Drones which are already collecting Data.
Commands should only relate to what exists on the map at present, never in the future.
"""

var messages = []

func _ready() -> void:
	http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_request_completed)

func push_assistant_message(message):
	messages.push_back(
		{
			"role": "assistant",
			"content": [
				{"type": "text", "text": message}
			]
		}
	)

func push_user_message(message):
	messages.push_back(
		{
			"role": "user",
			"content": [
				{"type": "text", "text": message}
			]
		}
	)

func make_decision(world_state: Dictionary) -> void:
	print("make_decision")

	if busy:
		return

	busy = true
	
	var instructions = prompt + "\nHere is the World State:\n" + JSON.stringify(world_state)

	var payload := {
		"model": model,
		"instructions": instructions,
		"input": "World state:\n" + JSON.stringify(world_state)
	}

	var headers := [
		"Content-Type: application/json"
	]

	var err := http.request(
		OPENAI_URL,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)

	if err != OK:
		busy = false
		decision_failed.emit("Failed to start HTTP request: " + str(err))

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	busy = false

	if result != HTTPRequest.RESULT_SUCCESS:
		decision_failed.emit("HTTP request failed: " + str(result))
		return

	if response_code < 200 or response_code >= 300:
		decision_failed.emit("HTTP response code: " + str(response_code) + " body: " + body.get_string_from_utf8())
		return

	var text := body.get_string_from_utf8()
	var json := JSON.new()
	var err := json.parse(text)

	if err != OK:
		decision_failed.emit("Failed to parse JSON response: " + text)
		return

	var command := _extract_response_text(json.data)
	if command == "":
		decision_failed.emit("No command found in response: " + text)
		return

	push_user_message(command)
	decision_made.emit(command)

func _extract_response_text(data) -> String:
	if not (data is Dictionary):
		return ""

	if data.has("output") and data["output"] is Array:
		for item in data["output"]:
			if item is Dictionary and item.get("content") is Array:
				for content in item["content"]:
					if content is Dictionary and content.get("type") == "output_text":
						return str(content.get("text", "")).strip_edges()

	if data.has("output_text"):
		return str(data["output_text"]).strip_edges()

	return ""
