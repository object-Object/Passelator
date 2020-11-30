-- In the context of this bot, a module is pretty much anything the bot does that isn't a module.
-- For example: checking messages for advertising, decreasing warning levels.

local fs = require("fs")
local json = require("json")
local utils = require("miscUtils")
local discordia = require("discordia")

local moduleHandler = {}
moduleHandler.modules = {}				-- table holding all modules with name as key and module table as value
moduleHandler.tree = {}					-- table holding all modules, in a class.event.module hierarchy
moduleHandler.sortedModuleNames = {}	-- table holding all modules as value, sorted alphabetically
moduleHandler.emitter = discordia.Emitter()

moduleHandler.load = function()
	for class, classFiletype in fs.scandirSync("modules") do
		assert(classFiletype=="directory", "Non-directory file '"..class.."' in modules/ directory")
		if not moduleHandler.tree[class] then
			moduleHandler.tree[class] = {}
		end
		for event, eventFiletype in fs.scandirSync("modules/"..class) do
			assert(eventFiletype=="directory", "Non-directory file '"..event.."' in modules/"..class.."/ directory")
			if not moduleHandler.tree[class][event] then
				moduleHandler.tree[class][event] = {}
			end
			for _,filename in ipairs(fs.readdirSync("modules/"..class.."/"..event)) do
				if filename:match("%.lua$") then
					local mod = require("../modules/"..class.."/"..event.."/"..filename)
					mod.event = class.."."..event
					moduleHandler.modules[mod.name] = mod
					moduleHandler.tree[class][event][mod.name] = mod
					table.insert(moduleHandler.sortedModuleNames, mod.name)
				end
			end
		end
	end
	table.sort(moduleHandler.sortedModuleNames)
	moduleHandler.emitter:emit("onLoad")
end

moduleHandler.doModules = function(event, guildSettings, ...)
	for _, mod in pairs(event) do
		mod:run(guildSettings, ...)
	end
end

return moduleHandler