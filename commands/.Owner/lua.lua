local commandHandler = require("commandHandler")
local pp = require("pretty-print")
local http = require("coro-http")
local json = require("json")
local utils = require("miscUtils")
local discordia = require("discordia")
local timer = require("timer")

local function printLine(...)
	local ret = {}
	for i = 1, select("#", ...) do
		local arg = tostring(select(i, ...))
		table.insert(ret, arg)
	end
	return table.concat(ret, "\t")
end

local function prettyLine(...)
	local ret = {}
	for i = 1, select("#", ...) do
		local arg = pp.strip(pp.dump(select(i, ...)))
		table.insert(ret, arg)
	end
	return table.concat(ret, "\t")
end

local function code(str)
	return string.format("```\n%s```", str)
end

return {
	name = "lua",
	description = "Runs arbitrary Lua code. May be enclosed in code block formatting.",
	usage = " <code>",
	visible = false,
	botGuildPermissions = {},
	botChannelPermissions = {},
	permissions = {"bot.botOwner"},
	run = function(self, message, argString, args, guildSettings)
		if argString=="" then
			commandHandler.sendUsage(message.channel, guildSettings, self)
			return
		end

		argString = argString:gsub("```lua", ""):gsub("```", "")

		local lines = {}
		local iolines = {}

		local sandbox = table.copy(_G, localtable)
		sandbox.message = message
		sandbox.client = message.client
		sandbox.guildSettings = guildSettings
		sandbox.commandHandler = commandHandler
		sandbox.code = code
		sandbox.timer = timer
		sandbox.discordia = discordia
		sandbox.utils = utils
		sandbox.json = json
		sandbox.http = http
		
		sandbox.io.write = function(...)
			table.insert(iolines, printLine(...))
		end

		sandbox.print = function(...)
			table.insert(lines, printLine(...))
		end

		sandbox.p = function(...)
			table.insert(lines, prettyLine(...))
		end

		local fn, syntaxError = load(argString, "DiscordBot", "t", sandbox)
		if not fn then return message:reply(code(syntaxError)) end

		local success, runtimeError = pcall(fn)
		if not success then return message:reply(code(runtimeError)) end

		lines = table.concat(lines, "\n")
		iolines = table.concat(iolines)

		if #lines>2000 then
			message:reply{
				content = "`print()` output too long, content attached as `print.txt`.",
				file = {"print.txt", lines}
			}
		elseif lines~="" then
			message:reply(lines)
		end

		if #iolines>2000 then
			message:reply{
				content = "`io.write()` output too long, content attached as `iowrite.txt`.",
				file = {"iowrite.txt", iolines}
			}
		elseif iolines~="" then
			message:reply(iolines)
		end
	end,
	onEnable = function(self, message, guildSettings)
		return true
	end,
	onDisable = function(self, message, guildSettings)
		return true
	end,
	subcommands = {}
}