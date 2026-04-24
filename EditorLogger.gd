@tool
extends EditorPlugin

class FileLogger extends Logger:
	var log_path: String = "res://logs/editor.log"
	var _ready: bool = false

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
		if not _ready:
			return

		var level := "ERROR" if error else "INFO"
		var timestamp := Time.get_datetime_string_from_system()
		var file := FileAccess.open(log_path, FileAccess.READ_WRITE)
		if file == null:
			return

		file.seek_end()
		file.store_line("[%s] [%s] %s" % [timestamp, level, message])
		file.flush()
		file.close()

var _logger: FileLogger

func _enter_tree() -> void:
	_logger = FileLogger.new()
	OS.add_logger(_logger)
	print("Editor Logger enabled")

func _exit_tree() -> void:
	if _logger:
		OS.remove_logger(_logger)
	_logger = null
