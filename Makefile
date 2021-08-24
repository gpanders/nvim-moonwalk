all: lua/moonwalk.lua

lua/%.lua: fnl/%.fnl
	fennel --compile $< > $@
