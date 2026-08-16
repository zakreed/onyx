.PHONY: all

all:
	odin build . -out:editor
	./editor

release:
	odin build . -o:speed -out:editor

windows:
	odin build . -out:editor.exe -subsystem:windows


release_windows:
	odin build . -out:editor.exe -subsystem:windows -o:speed
