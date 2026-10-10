# YOMIH Toolkit Panel

A Godot 3.5 editor panel for making characters for *Your Only Move Is HUSTLE*. It sits in
the editor's bottom panel and is a front-end for the
[YOMIH character toolkit](https://github.com/Shadacate/YOMIH-character-toolkit): every
button runs the toolkit's command line (`yct`) and shows what it printed.

This is a fork of [YH Mod Assistant](https://github.com/Valkarin1029/YHModAssistant) by
Valkarin, and is licensed GPL-3.0 like the original (see `LICENSE`). The original's own
screens (New Mod, Mod Info, Export, Overwrites) have been removed here, because the
toolkit does those jobs and two ways of doing them would disagree. Use the original if
you want them.

**Status: early.** What works today:

- Setup: say where the toolkit and Python are, and check the environment.
- Characters: list them, create a new one (it is linked into the project straight away).
- For the selected character: link into the project, export art from Aseprite, switch to
  its own sprites, build the mod zip.

Not built yet: adding moves from patterns with each setting explained, editing an
existing move, installing the zip into the game.

## Requirements

- The YOMIH character toolkit and Python 3.10 or newer.
- A Godot 3.5.1 project recovered from the game.

## Install

1. Put (or link) this repository's `addons/YHMA` folder at `addons/YHMA` in the game
   project.
2. Enable "YOMIH Toolkit Panel" in Project > Project Settings > Plugins.
3. Open the "YOMIH Toolkit" tab in the bottom panel, set the toolkit folder, and press
   "Save and check".

Settings are kept in the per-user config folder (`%APPDATA%\YHMA` on Windows).
