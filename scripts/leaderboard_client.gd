extends Node

# Fill these once the Supabase project is ready (see docs/ONLINE_LEADERBOARD_PLAN.md).
const LEADERBOARD_ENDPOINT := "https://rgueilijcmisctasgakx.supabase.co/rest/v1/leaderboard_scores"
const LEADERBOARD_PUBLIC_KEY := "sb_publishable_aV-SR-994h-0MfPx4Wul8w_LwQJzLxg"
const SUBMIT_TIMEOUT := 4.0
const GAME_VERSION := "0.2.0"

var http: HTTPRequest = null
var request_in_flight := false
var pending_top_rows := 0
var request_kind := ""
var _last_run_id := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_online_enabled() -> bool:
	return LEADERBOARD_ENDPOINT != "" and LEADERBOARD_PUBLIC_KEY != ""


func _ensure_http_node() -> void:
	if http == null:
		http = HTTPRequest.new()
		add_child(http)
		http.timeout = SUBMIT_TIMEOUT
		http.request_completed.connect(_on_request_completed)


func generate_run_id() -> String:
	var hex := "0123456789abcdef"
	var result := ""
	for index in 32:
		result += hex[randi() % 16]
	return (
		result.substr(0, 8) + "-" + result.substr(8, 4) + "-"
		+ result.substr(12, 4) + "-" + result.substr(16, 4) + "-"
		+ result.substr(20, 12)
	)


func get_pending_run_id() -> String:
	if _last_run_id == "":
		_last_run_id = generate_run_id()
	return _last_run_id


func submit_score(initials: String, score: int, time_s: float, wave: int) -> bool:
	if not is_online_enabled() or request_in_flight:
		return false
	_ensure_http_node()

	var body := JSON.stringify({
		"player_name": initials.substr(0, 3),
		"score": score,
		"survival_time": time_s,
	})
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"apikey: %s" % LEADERBOARD_PUBLIC_KEY,
		"Authorization: Bearer %s" % LEADERBOARD_PUBLIC_KEY,
		"Prefer: return=minimal",
	])
	var err := http.request(
		LEADERBOARD_ENDPOINT,
		headers,
		HTTPClient.METHOD_POST,
		body
	)
	if err != OK:
		return false
	request_kind = "submit"
	request_in_flight = true
	return true


func request_top_scores(max_rows: int = 5) -> bool:
	if not is_online_enabled():
		return false
	if request_in_flight:
		pending_top_rows = maxi(pending_top_rows, max_rows)
		return false
	_ensure_http_node()
	var headers := PackedStringArray([
		"apikey: %s" % LEADERBOARD_PUBLIC_KEY,
		"Authorization: Bearer %s" % LEADERBOARD_PUBLIC_KEY,
		"Prefer: return=minimal",
	])
	var url := "%s?select=player_name,score,survival_time,created_at&order=score.desc&limit=%d" % [LEADERBOARD_ENDPOINT, max_rows]
	var err := http.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		return false
	request_kind = "top"
	request_in_flight = true
	return true


func _on_request_completed(
	result: int,
	response_code: int,
	headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	var completed_request_kind := request_kind
	request_kind = ""
	request_in_flight = false
	var tree := get_tree()
	if completed_request_kind == "top" and tree != null:
		var scene := tree.current_scene
		if scene != null and scene.has_method("on_online_leaderboard_response"):
			scene.call(
				"on_online_leaderboard_response",
				result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300,
				body.get_string_from_utf8()
			)

	if pending_top_rows > 0:
		var rows_to_request := pending_top_rows
		pending_top_rows = 0
		request_top_scores(rows_to_request)
