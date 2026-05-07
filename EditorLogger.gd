@tool
extends EditorPlugin

class FileLogger extends Logger:
	var log_path: String = "res://logs/editor.log"
	var _ready: bool = false
	var _mutex := Mutex.new()

	func _init() -> void:
		_setup()

	func _setup() -> void:
		var logs_dir := "res://logs"
		var dir := DirAccess.open("res://")

		if dir == null:
			push_error("FileLogger init failed: cannot open res://")
			return

		if not dir.dir_exists("logs"):
			var make_dir_result := dir.make_dir("logs")
			if make_dir_result != OK and make_dir_result != ERR_ALREADY_EXISTS:
				push_error("FileLogger init failed: cannot create logs dir: " + str(make_dir_result))
				return

		var test_file := FileAccess.open(log_path, FileAccess.READ_WRITE)
		if test_file == null and FileAccess.get_open_error() == ERR_FILE_NOT_FOUND:
			var create_file := FileAccess.open(log_path, FileAccess.WRITE_READ)
			if create_file == null:
				push_error("FileLogger init failed: cannot create log file: " + str(FileAccess.get_open_error()))
				return
			create_file.close()
			test_file = FileAccess.open(log_path, FileAccess.READ_WRITE)

		if test_file == null:
			push_error("FileLogger init failed: " + str(FileAccess.get_open_error()))
			return

		test_file.close()
		_ready = true
		print("FileLogger initialized: %s" % logs_dir)

	func _log_message(message: String, error: bool) -> void:
		var level := "STDERR" if error else "INFO"
		_write_log(level, message)

	func _log_error(
		function: String,
		file: String,
		line: int,
		code: String,
		rationale: String,
		_editor_notify: bool,
		error_type: int,
		_script_backtraces: Array[ScriptBacktrace]
	) -> void:
		var level := _get_error_level(error_type)
		var details := rationale if not rationale.is_empty() else code
		var location := _get_error_location(function, file, line)
		var message := details

		if not location.is_empty() and not details.is_empty():
			message = "%s - %s" % [location, details]
		elif not location.is_empty():
			message = location

		_write_log(level, message)

	func _get_error_level(error_type: int) -> String:
		match error_type:
			0:
				return "ERROR"
			1:
				return "WARNING"
			2:
				return "SCRIPT"
			3:
				return "SHADER"
			_:
				return "ERROR"

	func _get_error_location(function: String, file: String, line: int) -> String:
		if not file.is_empty() and line > 0:
			return "%s:%d" % [file, line]
		if not file.is_empty():
			return file
		return function

	func _write_log(level: String, message: String) -> void:
		if not _ready:
			return

		var timestamp := Time.get_datetime_string_from_system()
		var clean_message := message.rstrip("\r\n")

		_mutex.lock()
		var file := FileAccess.open(log_path, FileAccess.READ_WRITE)
		if file == null:
			_mutex.unlock()
			return

		file.seek_end()
		for line_text in clean_message.split("\n", false):
			file.store_line("[%s] [%s] %s" % [timestamp, level, line_text.rstrip("\r")])
		file.flush()
		file.close()
		_mutex.unlock()

var _logger: FileLogger

func _enter_tree() -> void:
	_logger = FileLogger.new()
	OS.add_logger(_logger)
	print("Editor Logger enabled")

func _exit_tree() -> void:
	if _logger:
		OS.remove_logger(_logger)
	_logger = null
