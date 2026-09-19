package.path = "./src/?.lua;./src/?/init.lua;" .. package.path

local cli = require("logsentry.cli")
os.exit(cli.run(arg))
