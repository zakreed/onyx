.PHONY: all

all:
	odin build ./src -out:editor
	./editor

release:
	odin build ./src -o:speed -out:editor

windows:
	odin build ./src -out:editor.exe -subsystem:windows


release_windows:
	odin build ./src -out:editor.exe -subsystem:windows -o:speed
