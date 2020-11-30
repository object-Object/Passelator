local discordia = require("discordia")
local options = require("options")
discordia.storage.options = options
local sql = require("sqlite3")
local fs = require("fs")
local json = require("json")
local utils = require("miscUtils")

local conn
if not fs.existsSync("bot.db") then
	conn = require("./create-db")
else
	conn = sql.open("bot.db")
end
discordia.storage.conn = conn

local client = discordia.Client(options.clientOptions)
local clock = discordia.Clock()
discordia.extensions()

local commandHandler = require("commandHandler")
commandHandler.load(conn)
local moduleHandler = require("moduleHandler")
moduleHandler.load()

local statusVersion
local function setGame()
	local changelog = fs.readFileSync("changelog.txt")
	local version = changelog and changelog:match("%*%*([^%*]+)%*%*") or "error"
	if version ~= statusVersion then
		statusVersion = version
		client:setGame({name=options.defaultPrefix.."help | "..version, url="https://www.twitch.tv/ThisIsAFakeTwitchLink"})
	end
end

local function getGuildSettings(id, conn)
	local settings = conn:exec("SELECT * FROM guild_settings WHERE guild_id="..id..";", "k")
	if not settings then
		local stmt = conn:prepare("INSERT INTO guild_settings (guild_id, prefix, mass_ping_cooldown) VALUES (?, ?, ?);")
		stmt:reset():bind(id, options.defaultPrefix, options.defaultMassPingCooldown):step()
		stmt:close()

		stmt = conn:prepare("INSERT INTO commands (guild_id, command, is_enabled, permissions) VALUES (?, ?, ?, ?);")
		for _, command in pairs(commandHandler.commands) do
			stmt:reset():bind(id, command.name, (not command.isDefaultDisabled and 1 or 0), json.encode(command.permissions)):step()
			for _, subcommand in pairs(command.subcommands) do
				stmt:reset():bind(id, subcommand.name, 1, json.encode(subcommand.permissions)):step()
			end
		end

		settings = conn:exec("SELECT * FROM guild_settings WHERE guild_id="..id..";", "k")
	end
	return utils.formatRow(settings)
end

local function doModulesPcall(event, guild, conn, ...)
	local success, err = pcall(function(...)
		local guildSettings = getGuildSettings(guild.id, conn)
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
	getGuildSettings(guild.id, conn) -- generate guild settings if they don't exist
end)

client:on("memberJoin", function(member)
	doModulesPcall(moduleHandler.tree.client.memberJoin, member.guild, conn, member, conn)
end)

client:on("memberUpdate", function(member)
	doModulesPcall(moduleHandler.tree.client.memberUpdate, member.guild, conn, member, conn)
end)

client:on("memberLeave", function(member)
	doModulesPcall(moduleHandler.tree.client.memberLeave, member.guild, conn, member, conn)
end)

--[[
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
		local guildSettings = getGuildSettings(message.guild.id, conn)

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