tool
extends VBoxContainer

# YOMIH Toolkit panel.
#
# A front-end only: every button runs the toolkit's command line (yct) and shows what it
# printed. Nothing about a character is decided or stored here, so the panel and the
# command line can never disagree. The explanations shown beside a move's settings are
# the toolkit's own (yct explain), not a second copy.

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

# Moves tab
var pattern_pick: OptionButton
var pattern_about: Label
var move_id_edit: LineEdit
var move_title_edit: LineEdit
var param_box: VBoxContainer
var param_edits = {}
var patterns = []       # move patterns, as yct lists them
var attributes = {}     # setting name -> its explanation, from yct explain
var concepts = []       # startup, active, recovery ... from yct explain

# Game moves tab
var game_character_pick: OptionButton
var game_move_pick: OptionButton
var game_characters = []    # the game's own characters, from yct game characters
var game_moves = []         # the picked character's moves, from yct game moves


func _init():
	name = "YOMIH Toolkit"
	rect_min_size = Vector2(0, 330)
	_build()


func _ready():
	_load_settings()
	refresh_characters()
	refresh_patterns()
	refresh_game_characters()


# -- layout -------------------------------------------------------------------

func _build():
	var split = HSplitContainer.new()
	split.size_flags_horizontal = SIZE_EXPAND_FILL
	split.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(split)

	var left = VBoxContainer.new()
	left.rect_min_size = Vector2(760, 0)
	split.add_child(left)

	# The character the buttons act on stays visible above both tabs.
	var row = _row(left)
	_label(row, "Character")
	character_pick = OptionButton.new()
	character_pick.size_flags_horizontal = SIZE_EXPAND_FILL
	character_pick.hint_tooltip = "The character the buttons below act on."
	row.add_child(character_pick)
	_button(row, "Refresh", "Read the characters and patterns again.", "_on_refresh")

	var tabs = TabContainer.new()
	tabs.size_flags_horizontal = SIZE_EXPAND_FILL
	tabs.size_flags_vertical = SIZE_EXPAND_FILL
	left.add_child(tabs)
	_build_character_tab(_tab(tabs, "Character"))
	_build_moves_tab(_tab(tabs, "Moves"))
	_build_game_moves_tab(_tab(tabs, "Game moves"))
	_build_setup_tab(_tab(tabs, "Setup"))

	status_label = Label.new()
	status_label.clip_text = true
	left.add_child(status_label)

	output = TextEdit.new()
	output.readonly = true
	output.wrap_enabled = true
	output.size_flags_horizontal = SIZE_EXPAND_FILL
	output.size_flags_vertical = SIZE_EXPAND_FILL
	output.hint_tooltip = "What the toolkit printed."
	split.add_child(output)


func _tab(tabs, title):
	var scroll = ScrollContainer.new()
	scroll.name = title
	scroll.scroll_horizontal_enabled = false
	tabs.add_child(scroll)
	var box = VBoxContainer.new()
	box.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(box)
	return box


func _build_character_tab(box):
	var row = _row(box)
	_label(row, "New")
	new_id_edit = _edit(row, "id, e.g. quick_fox",
			"A short name for files and folders: lowercase letters, digits and underscores.")
	new_name_edit = _edit(row, "Name shown in the game", "The character's name as players will see it.")
	_button(row, "New character", "Create a character the game can load and select, and link its folder "
			+ "into this project so it appears under res://.", "_on_new_character")

	row = _row(box)
	_label(row, "Selected")
	_button(row, "Link into this project", "Make the character's mod folder appear in this project under "
			+ "res://, so it can be edited here. Nothing is copied.", "_on_action", ["link"])
	_button(row, "Export art", "Turn the character's Aseprite files into the frames and animations the "
			+ "game loads. Each tag in Aseprite becomes one animation.", "_on_action", ["export"])
	_button(row, "Use own sprites", "Make the character draw with its exported art instead of the base "
			+ "game's stickman. Needed once, after the first export.", "_on_own_sprites")
	_button(row, "Build zip", "Build the mod zip the game loads. Copy it into the game's mods folder "
			+ "to test.", "_on_action", ["package"])


func _build_moves_tab(box):
	var row = _row(box)
	_label(row, "Kind of move")
	pattern_pick = OptionButton.new()
	pattern_pick.rect_min_size = Vector2(190, 0)
	pattern_pick.hint_tooltip = "A pattern is a kind of move that has been built and tested once, kept as a template."
	pattern_pick.connect("item_selected", self, "_on_pattern_selected")
	row.add_child(pattern_pick)
	move_id_edit = _edit(row, "id, e.g. jab", "A short name for the move: lowercase letters, digits and "
			+ "underscores. Its animation is the Aseprite tag of the same name in CamelCase (jab -> Jab).")
	move_title_edit = _edit(row, "Name shown in the game", "The move's name on its button in the game.")
	_button(row, "Add move", "Add this move to the selected character, with the settings below. "
			+ "Empty settings use the default shown in grey.", "_on_add_move")

	pattern_about = Label.new()
	pattern_about.autowrap = true
	box.add_child(pattern_about)
	box.add_child(HSeparator.new())

	param_box = VBoxContainer.new()
	param_box.size_flags_horizontal = SIZE_EXPAND_FILL
	box.add_child(param_box)


func _build_game_moves_tab(box):
	var about = Label.new()
	about.autowrap = true
	about.text = ("See how one of the game's own characters does a move: its length, when its hitbox is on, "
			+ "its damage, hitstun and the rest, each explained. Use it as the reference for your own moves. "
			+ "This only reads the game project; nothing is changed or copied.")
	box.add_child(about)

	var row = _row(box)
	_label(row, "Game character")
	game_character_pick = OptionButton.new()
	game_character_pick.rect_min_size = Vector2(150, 0)
	game_character_pick.hint_tooltip = "One of the characters that come with the game."
	game_character_pick.connect("item_selected", self, "_on_game_character_selected")
	row.add_child(game_character_pick)
	_label(row, "Move", 40)
	game_move_pick = OptionButton.new()
	game_move_pick.size_flags_horizontal = SIZE_EXPAND_FILL
	game_move_pick.clip_text = true
	game_move_pick.hint_tooltip = ("The character's moves: the name on the move's button in the game, then its "
			+ "name in the scene. States with no button name are listed after the named ones.")
	row.add_child(game_move_pick)
	_button(row, "Show move", "Show this move's settings and hitboxes on the right, with what each one means. "
			+ "If the move fires a projectile, the projectile is shown too.", "_on_show_game_move")


func _build_setup_tab(box):
	var row = _row(box)
	_label(row, "Toolkit folder")
	toolkit_edit = _edit(row, "the folder that contains yct.py",
			"Where the YOMIH character toolkit is on this computer.")
	row = _row(box)
	_label(row, "Python")
	python_edit = _edit(row, "python", "The command that starts Python 3.10 or newer. Usually just: python")
	_button(row, "Save and check", "Save these two settings, then check that the game, the game project, "
			+ "the Godot editor and Aseprite can all be found.", "_on_save_and_check")


func _row(parent):
	var row = HBoxContainer.new()
	row.size_flags_horizontal = SIZE_EXPAND_FILL
	parent.add_child(row)
	return row


func _label(parent, text, width = 100):
	var label = Label.new()
	label.text = text
	label.rect_min_size = Vector2(width, 0)
	parent.add_child(label)
	return label


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
		_say("Set the toolkit folder on the Setup tab first: the folder that contains yct.py.")
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


func _read_json(args, what):
	var result = run_yct(args, true)
	if result.code != 0:
		return null
	var parsed = JSON.parse(result.text)
	if parsed.error != OK:
		_say("Could not read %s:\n%s" % [what, result.text])
		return null
	return parsed.result


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
	var listing = _read_json(["characters", "--json"], "the character list")
	if not (listing is Array):
		status_label.text = "Character list not read yet. Check the Setup tab."
		return
	characters = listing
	for i in range(characters.size()):
		var c = characters[i]
		character_pick.add_item("%s  (%s, %s)" % [c["display_name"], c["id"], c["link"]])
		if c["id"] == keep:
			character_pick.select(i)
	status_label.text = "%d character(s) in %s" % [characters.size(), toolkit_edit.text.strip_edges()]


func _select_character(id):
	for i in range(characters.size()):
		if characters[i]["id"] == id:
			character_pick.select(i)


# -- moves --------------------------------------------------------------------

func refresh_patterns():
	patterns = []
	attributes = {}
	concepts = []
	pattern_pick.clear()
	var reference = _read_json(["explain", "--json"], "the explanations")
	if reference is Dictionary:
		for attribute in reference.get("attributes", []):
			attributes[attribute["name"]] = attribute
		concepts = reference.get("concepts", [])
	var listing = _read_json(["pattern", "list", "--json"], "the patterns")
	if not (listing is Array):
		pattern_about.text = "Patterns not read yet. Check the Setup tab."
		return
	for spec in listing:
		if spec.get("scope", "move") == "move":
			patterns.append(spec)
			pattern_pick.add_item(spec["title"])
	if patterns.size() > 0:
		pattern_pick.select(0)
		_on_pattern_selected(0)


func _on_pattern_selected(index):
	for child in param_box.get_children():
		param_box.remove_child(child)
		child.queue_free()
	param_edits = {}
	if index < 0 or index >= patterns.size():
		return
	var spec = patterns[index]
	var proven = "Seen working in the game." if spec["verified"]["in_game"] else "NOT yet seen working in the game."
	pattern_about.text = "%s  %s" % [spec["description"], proven]
	for param_name in spec["parameters"]:
		var param = spec["parameters"][param_name]
		var row = _row(param_box)
		_label(row, param_name, 120)
		var edit = LineEdit.new()
		edit.rect_min_size = Vector2(110, 0)
		var default_text = str(param["default"])
		if default_text.find("{{") != -1:
			default_text = "(from the move's id)"
		elif default_text == "":
			default_text = "(none)"
		edit.placeholder_text = default_text
		row.add_child(edit)
		param_edits[param_name] = edit

		var text = param["description"]
		var tip = param["description"]
		var explains = param.get("explains", "")
		if attributes.has(explains):
			var attribute = attributes[explains]
			tip = "%s\n\nIn the game this is %s on the %s.\n%s\n%s\n\nDefault in the game: %s. Read from: %s" % [
					param["description"], attribute["name"],
					"hitbox" if attribute["on"] == "Hitbox" else "move's state",
					attribute["summary"], attribute["detail"], attribute["default"], attribute["source"]]
			text += "  [%s]" % attribute["name"]
		edit.hint_tooltip = tip
		var about = Label.new()
		about.text = text
		about.clip_text = true
		about.hint_tooltip = tip
		about.mouse_filter = MOUSE_FILTER_STOP   # so hovering the text shows the full explanation
		about.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(about)

	# The three parts of an attack, and the other terms, as one line each.
	if concepts.size() > 0:
		param_box.add_child(HSeparator.new())
		for concept in concepts:
			var line = Label.new()
			line.text = "%s: %s" % [concept["term"], concept["explanation"]]
			line.clip_text = true
			line.hint_tooltip = "%s\n\n%s\n\nHow to set it: %s" % [concept["term"], concept["explanation"], concept["how"]]
			line.mouse_filter = MOUSE_FILTER_STOP
			line.add_color_override("font_color", Color(0.65, 0.8, 1.0))
			param_box.add_child(line)


func _on_add_move():
	var character = _selected_id()
	if character == "":
		return
	var index = pattern_pick.selected
	if index < 0 or index >= patterns.size():
		_say("No kind of move is selected.")
		return
	var move_id = move_id_edit.text.strip_edges()
	var title = move_title_edit.text.strip_edges()
	if move_id == "" or title == "":
		_say("Fill in both the move's id and the name shown in the game.")
		return
	var args = ["pattern", "apply", patterns[index]["id"], "%s.%s" % [character, move_id], "--name", title]
	for param_name in param_edits:
		var value = param_edits[param_name].text.strip_edges()
		if value != "":
			args.append("--set")
			args.append("%s=%s" % [param_name, value])
	if run_yct(args).code == 0:
		move_id_edit.text = ""
		move_title_edit.text = ""
		for param_name in param_edits:
			param_edits[param_name].text = ""
		_rescan()


# -- game moves ---------------------------------------------------------------

func refresh_game_characters():
	game_characters = []
	game_character_pick.clear()
	game_move_pick.clear()
	game_moves = []
	var listing = _read_json(["game", "characters", "--json"], "the game's characters")
	if not (listing is Array):
		return
	game_characters = listing
	for entry in game_characters:
		game_character_pick.add_item(entry["name"])
	if game_characters.size() > 0:
		game_character_pick.select(0)
		_on_game_character_selected(0)


func _on_game_character_selected(index):
	game_move_pick.clear()
	game_moves = []
	if index < 0 or index >= game_characters.size():
		return
	var listing = _read_json(["game", "moves", game_characters[index]["name"], "--json"], "the character's moves")
	if not (listing is Dictionary):
		return
	var unnamed = []
	for move in listing.get("moves", []):
		if move["title"] == null:
			unnamed.append(move)
		else:
			game_moves.append(move)
			game_move_pick.add_item("%s  (%s)" % [move["title"], move["node"]])
	for move in unnamed:
		game_moves.append(move)
		game_move_pick.add_item(move["node"])
	if game_moves.size() > 0:
		game_move_pick.select(0)


func _on_show_game_move():
	var character = game_character_pick.selected
	var move = game_move_pick.selected
	if character < 0 or character >= game_characters.size() or move < 0 or move >= game_moves.size():
		_say("Pick a game character and a move first. If the lists are empty, check the Setup tab.")
		return
	output.text = ""    # a move is long; start it at the top
	run_yct(["game", "show", game_characters[character]["name"], game_moves[move]["node"]])
	output.cursor_set_line(0)


# -- buttons ------------------------------------------------------------------

func _on_refresh():
	refresh_characters()
	refresh_patterns()
	refresh_game_characters()


func _on_save_and_check():
	if not _save_settings():
		_say("Could not save the settings to " + _settings_dir())
	run_yct(["env"])
	_on_refresh()


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
	_select_character(id)
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
