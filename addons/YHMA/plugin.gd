tool
extends EditorPlugin

# Adds the YOMIH Toolkit panel to the editor's bottom panel, beside Output and Debugger.

const ToolkitPanel = preload("res://addons/YHMA/toolkit/Panel.gd")

var panel = null


func _enter_tree():
	panel = ToolkitPanel.new()
	panel.editor_plugin = self
	add_control_to_bottom_panel(panel, "YOMIH Toolkit")


func _exit_tree():
	if panel != null:
		remove_control_from_bottom_panel(panel)
		panel.queue_free()
		panel = null
