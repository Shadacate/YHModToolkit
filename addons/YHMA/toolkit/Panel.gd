tool
extends VBoxContainer

# YOMIH Toolkit panel.
#
# A front-end only: every button runs the toolkit's command line (yct) and shows what it
# printed. Nothing about a character is decided or stored here, so the panel and the
# command line can never disagree.

const SETTINGS_FILE = "toolkit.cfg"

var editor_plugin = null

var toolkit_edit: LineEdit
var python_edit: LineEdit
var character_pick: OptionButton
var new_id_edit: LineEdit
var new_name_edit: LineEdit
var output: TextEdit
var status_label: Label
var characters = []


func _init():
	name = "YOMIH Toolkit"
	rect_min_size = Vector2(0, 280)
	_build()


func _ready():
	_load_settings()
	refresh_characters()


# -- layout -------------------------------------------------------------------

func _build():
	var split = HSplitContainer.new()
	split.size_flags_horizontal = SIZE_EXPAND_FILL
	split.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(split)

	var scroll = ScrollContainer.new()
	scroll.rect_min_size = Vector2(520, 0)
	scroll.scroll_horizontal_enabled = false
	split.add_child(scroll)

	var left = VBoxContainer.new()
	left.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(left)

	_heading(left, "Setup")
	var row = _row(left)
	_label(row, "Toolkit folder")
	toolkit_edit = _edit(row, "the folder that contains yct.py",
			"Where the YOMIH character toolkit is on this computer.")
	row = _row(left)
	_label(row, "Python")
	python_edit = _edit(row, "python", "The command that starts Python 3.10 or newer. Usually just: python")
	_button(row, "Save and check", "Save these two settings, then check that the game, the game project, "
			+ "the Godot editor and Aseprite can all be found.", "_on_save_and_check")

	_heading(left, "Characters")
	row = _row(left)
	character_pick = OptionButton.new()
	character_pick.size_flags_horizontal = SIZE_EXPAND_FILL
	character_pick.hint_tooltip = "The character the buttons below act on."
	row.add_child(character_pick)
	_button(row, "Refresh", "Read the list of characters again.", "refresh_characters")

	row = _row(left)
	new_id_edit = _edit(row, "id, e.g. quick_fox",
			"A short name for files and folders: lowercase letters, digits and underscores.")
	new_name_edit = _edit(row, "Name shown in the game", "The character's name as players will see it.")
	_button(row, "New character", "Create a character the game can load and select, and link its folder "
			+ "into this project so it appears under res://.", "_on_new_character")

	_heading(left, "Selected character")
	row = _row(left)
	_button(row, "Link into this project", "Make the character's mod folder appear in this project under "
			+ "res://, so it can be edited here. Nothing is copied.", "_on_action", ["link"])
	_button(row, "Export art", "Turn the character's Aseprite files into the frames and animations the "
			+ "game loads. Each tag in Aseprite becomes one animation.", "_on_action", ["export"])
	row = _row(left)
	_button(row, "Use own sprites", "Make the character draw with its exported art instead of the base "
			+ "game's stickman. Needed once, after the first export.", "_on_own_sprites")
	_button(row, "Build zip", "Build the mod zip the game loads. Copy it into the game's mods folder "
			+ "to test.", "_on_action", ["package"])

	status_label = Label.new()
	status_label.autowrap = true
	left.add_child(status_label)

	output = TextEdit.new()
	output.readonly = true
	output.wrap_enabled = true
	output.size_flags_horizontal = SIZE_EXPAND_FILL
	output.size_flags_vertical = SIZE_EXPAND_FILL
	output.hint_tooltip = "What the toolkit printed."
	split.add_child(output)


func _heading(parent, text):
	var label = Label.new()
	label.text = text
	label.add_color_override("font_color", Color(0.65, 0.8, 1.0))
	parent.add_child(label)
	parent.add_child(HSeparator.new())


func _row(parent):
	var row = HBoxContainer.new()
	row.size_flags_horizontal = SIZE_EXPAND_FILL
	parent.add_child(row)
	return row


func _label(parent, text):
	var label = Label.new()
	label.text = text
	label.rect_min_size = Vector2(100, 0)
	parent.add_child(label)


func _edit(parent, placeholder, tip):
	var edit = LineEdit.new()
	edit.placeholder_text = placeholder
	edit.hint_tooltip = tip
	edit.size_flags_horizontal = SIZE_EXPAND_FILL
	parent.add_child(edit)
	return edit


func _button(parent, text, tip, method, binds = []):
	var button = Button.new()
	button.text = text
	button.hint_tooltip = tip
	button.connect("pressed", self, method, binds)
	parent.add_child(button)
	return button


# -- settings -----------------------------------------------------------------

func _settings_dir():
	return OS.get_config_dir().plus_file("YHMA")


func _load_settings():
	var cfg = ConfigFile.new()
	var folder = ""
	var python = "python"
	if cfg.load(_settings_dir().plus_file(SETTINGS_FILE)) == OK:
		folder = cfg.get_value("toolkit", "folder", "")
		python = cfg.get_value("toolkit", "python", "python")
	if folder == "":
		# A common layout keeps the toolkit beside the game project.
		var guess = ProjectSettings.globalize_path("res://").get_base_dir().get_base_dir().plus_file("studio")
		if File.new().file_exists(guess.plus_file("yct.py")):
			folder = guess
	toolkit_edit.text = folder
	python_edit.text = python


func _save_settings():
	Directory.new().make_dir_recursive(_settings_dir())
	var cfg = ConfigFile.new()
	cfg.set_value("toolkit", "folder", toolkit_edit.text.strip_edges())
	cfg.set_value("toolkit", "python", python_edit.text.strip_edges())
	return cfg.save(_settings_dir().plus_file(SETTINGS_FILE)) == OK


# -- running the toolkit ------------------------------------------------------

func run_yct(args, quiet = false):
	var folder = toolkit_edit.text.strip_edges()
	var script = folder.plus_file("yct.py")
	if folder == "" or not File.new().file_exists(script):
		_say("Set the toolkit folder first: the folder that contains yct.py.")
		return {"code": -1, "text": ""}
	var python = python_edit.text.strip_edges()
	if python == "":
		python = "python"
	var command = [script]
	for arg in args:
		command.append(str(arg))
	var lines = []
	var code = OS.execute(python, command, true, lines, true)
	var text = PoolStringArray(lines).join("")
	if code == -1 and text == "":
		text = "Could not start Python with the command '%s'. Check the Python setting." % python
	if not quiet:
		_say("> yct %s\n%s\n[exit code %d]\n" % [PoolStringArray(args).join(" "), text.strip_edges(), code])
	return {"code": code, "text": text}


func _say(text):
	output.text += text + "\n"
	output.cursor_set_line(output.get_line_count())


func _rescan():
	if editor_plugin != null:
		editor_plugin.get_editor_interface().get_resource_filesystem().scan()


func _selected_id():
	var index = character_pick.selected
	if index < 0 or index >= characters.size():
		_say("Pick a character first.")
		return ""
	return characters[index]["id"]


func refresh_characters():
	var keep = ""
	if character_pick.selected >= 0 and character_pick.selected < characters.size():
		keep = characters[character_pick.selected]["id"]
	character_pick.clear()
	characters = []
	var result = run_yct(["characters", "--json"], true)
	if result.code != 0:
		status_label.text = "Character list not read yet."
		return
	var parsed = JSON.parse(result.text)
	if parsed.error != OK or not (parsed.result is Array):
		_say("Could not read the character list:\n" + result.text)
		return
	characters = parsed.result
	for i in range(characters.size()):
		var c = characters[i]
		character_pick.add_item("%s  (%s, %s)" % [c["display_name"], c["id"], c["link"]])
		if c["id"] == keep:
			character_pick.select(i)
	status_label.text = "%d character(s) in %s" % [characters.size(), toolkit_edit.text.strip_edges()]


# -- buttons ------------------------------------------------------------------

func _on_save_and_check():
	if not _save_settings():
		_say("Could not save the settings to " + _settings_dir())
	run_yct(["env"])
	refresh_characters()


func _on_new_character():
	var id = new_id_edit.text.strip_edges()
	var display = new_name_edit.text.strip_edges()
	if id == "" or display == "":
		_say("Fill in both the id and the name shown in the game.")
		return
	if run_yct(["new-character", id, "--name", display]).code != 0:
		return
	run_yct(["link", id])
	new_id_edit.text = ""
	new_name_edit.text = ""
	refresh_characters()
	for i in range(characters.size()):
		if characters[i]["id"] == id:
			character_pick.select(i)
	_rescan()


func _on_action(command):
	var id = _selected_id()
	if id == "":
		return
	run_yct([command, id])
	refresh_characters()
	_rescan()


func _on_own_sprites():
	var id = _selected_id()
	if id == "":
		return
	run_yct(["pattern", "apply", "own_sprites", id])
	_rescan()
