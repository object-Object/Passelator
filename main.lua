local discordia = require("discordia")
local sql = require("sqlite3")
local fs = require("fs")
local json = require("json")
local utils = require("miscUtils")
local options = require("options")
discordia.storage.options = options

local conn = sql.open("bot.db")

local client = discordia.Client(options.clientOptions)
local clock = discordia.Clock()
discordia.extensions()

local commandHandler = require("commandHandler")
commandHandler.load()
local moduleHandler = require("moduleHandler")
moduleHandler.load()

local statusVersion
local function setGame()
	local changelog = fs.readFileSync("changelog.txt")
	local version = changelog and changelog:match("%*%*([^%*]+)%*%*") or "error"
	if version~=statusVersion then
		statusVersion = version
		client:setGame({name=options.defaultPrefix.."help | "..version, url="https://www.twitch.tv/ThisIsAFakeTwitchLink"})
	end
end

local function setupGuild(id)
	local disabledModules = {}
	for modName, mod in pairs(moduleHandler.modules) do
		if mod.disabledByDefault then
			disabledModules[modName] = true
		end
	end
	local disabledModulesStr = json.encode(disabledModules)
	conn:exec("INSERT INTO guild_settings (guild_id, disabled_modules) VALUES ('"..id.."', '"..disabledModulesStr.."')")
end

local function doModulesPcall(event, guild, conn, ...)
	local success, err = pcall(function(...)
		local guildSettings = utils.getGuildSettings(guild.id, conn)
		if not guildSettings then
			setupGuild(guild.id)
			guildSettings = utils.getGuildSettings(guild.id, conn)
		end
		moduleHandler.doModules(event, guildSettings, ...)
	end, ...)
	if not success then
		utils.logError(guild, err)
		print("Bot crashed! Guild: "..guild.name.." ("..guild.id..")\n"..err)
	end
end

clock:on("min", function()
	for guild in client.guilds:iter() do
		doModulesPcall(moduleHandler.tree.clock.min, guild, conn, guild, conn)
	end
end)

clock:on("hour", function()
	setGame()
	for guild in client.guilds:iter() do
		doModulesPcall(moduleHandler.tree.clock.hour, guild, conn, guild, conn)
	end
end)

client:on("ready", function()
	setGame()
end)

client:on("guildCreate", function(guild)
	if not utils.getGuildSettings(guild.id, conn) then
		setupGuild(guild.id)
	end
end)

--[[
client:on("memberJoin", function(member)
	doModulesPcall(moduleHandler.tree.client.memberJoin, member.guild, conn, member, conn)
end)

client:on("memberLeave", function(member)
	doModulesPcall(moduleHandler.tree.client.memberLeave, member.guild, conn, member, conn)
end)

client:on("userBan", function(user, guild)
	doModulesPcall(moduleHandler.tree.client.userBan, guild, conn, user, guild, conn)
end)
]]

client:on("reactionAdd", function(reaction, userId)
	if not reaction.message.guild then return end
	doModulesPcall(moduleHandler.tree.client.reactionAdd, reaction.message.guild, conn, reaction, userId, conn)
end)

client:on("reactionAddUncached", function(channel, messageId, hash, userId)
	if not channel.guild then return end
	doModulesPcall(moduleHandler.tree.client.reactionAddUncached, channel.guild, conn, channel, messageId, hash, userId, conn)
end)

client:on("reactionRemove", function(reaction, userId)
	if not reaction.message.guild then return end
	doModulesPcall(moduleHandler.tree.client.reactionRemove, reaction.message.guild, conn, reaction, userId, conn)
end)

client:on("reactionRemoveUncached", function(channel, messageId, hash, userId)
	if not channel.guild then return end
	doModulesPcall(moduleHandler.tree.client.reactionRemoveUncached, channel.guild, conn, channel, messageId, hash, userId, conn)
end)

client:on("messageCreate", function(message)
	local success, err = pcall(function()
		if message.author.bot
			or message.channel.type == discordia.enums.channelType.private
			or not message.guild then return end
		local guildSettings = utils.getGuildSettings(message.guild.id, conn)
		if not guildSettings then
			setupGuild(message.guild.id)
			guildSettings = utils.getGuildSettings(message.guild.id, conn)
		end

		moduleHandler.doModules(moduleHandler.tree.client.messageCreate, guildSettings, message, conn)

		commandHandler.doCommands(message, guildSettings, conn)
	end)
	if not success then
		utils.logError(message.guild, err)
		print("Bot crashed! Guild: "..message.guild.name.." ("..message.guild.id..")\n"..err)
	end
end)

--[[
client:on("messageUpdate", function(message)
	if not message.guild then return end
	doModulesPcall(moduleHandler.tree.client.messageUpdate, message.guild, conn, message, conn)
end)

client:on("messageDelete", function(message)
	if not message.guild then return end
	doModulesPcall(moduleHandler.tree.client.messageDelete, message.guild, conn, message, conn)
end)
]]

clock:start()
client:run("Bot "..options.token)