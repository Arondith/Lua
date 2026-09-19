LUA ?= lua

.PHONY: test demo markdown json

test:
	$(LUA) tests/run.lua

demo:
	$(LUA) main.lua analyze sample/app.log

markdown:
	$(LUA) main.lua analyze sample/app.log --format markdown

json:
	$(LUA) main.lua analyze sample/app.log --format json
