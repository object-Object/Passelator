local discordia = require("discordia")
local options = require("options")
discordia.storage.options = options
local limits = require("limits")
discordia.storage.limits = limits
local sql = require("sqlite3")
local fs = require("fs")
local json = require("json")
local http = require("coro-http")
local utils = require("miscUtils")

-- stops async from doing things out of order when a user joins
discordia.storage.addingRolesOnJoin = {} -- key: member.guild.id.."-"..member.id
-- used to tell the memberUpdate handler to set is_from_link = 1
discordia.storage.isFromLink = {} -- key: role.id.."-"..member.guild.id.."-"..member.id

local conn
if not fs.existsSync("bot.db") then
	conn = require("./create-db")
else
	conn = sql.open("bot.db")
end
discordia.storage.conn = conn

local client = discordia.Client(options.clientOptions)
local clock = discordia.Clock()
local emitter = discordia.Emitter()
discordia.extensions()

local commandHandler = require("commandHandler")
commandHandler.load(conn)
local moduleHandler = require("moduleHandler")
moduleHandler.load()

local statusVersion
local botListGuildCount
local function setGame()
	local changelog = fs.readFileSync("changelog.txt")
	local version = changelog and changelog:match("%*%*([^%*]+)%*%*") or "error"
	if version ~= statusVersion then
		statusVersion = version
		client:setGame({name=options.defaultPrefix.."help | "..version, url="https://www.twitch.tv/ThisIsAFakeTwitchLink"})
	end
	if options.isProduction and botListGuildCount ~= #client.guilds then
		botListGuildCount = #client.guilds
		do -- top.gg
			local headers = {
				{"content-type", "application/json"},
				{"Authorization", options.botLists.topgg.token}
			}
			local payload = json.encode{
				server_count = botListGuildCount
			}
			local _, response = http.request("POST", options.botLists.topgg.url, headers, payload)
			print("Updating top.gg server count. Response: "..response)
		end
		do -- Discord Bot List
			local headers = {
				{"content-type", "application/json"},
				{"Authorization", options.botLists.discordbotlist.token}
			}
			local payload = json.encode{
				guilds = botListGuildCount
			}
			local _, response = http.request("POST", options.botLists.discordbotlist.url, headers, payload)
			print("Updating Discord Bot List server count. Response: "..response)
		end
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

local function doModules(event, guild, conn, ...)
	local success, err = xpcall(function(...)
		local guildSettings = getGuildSettings(guild.id, conn)
		moduleHandler.doModules(event, guildSettings, ...)
	end, debug.traceback, ...)
	if not success then
		utils.logError(guild, err)
		print("Bot crashed! Guild: "..guild.name.." ("..guild.id..")\n"..err)
	end
end

clock:on("min", function()
	for guild in client.guilds:iter() do
		doModules(moduleHandler.tree.clock.min, guild, conn, guild, conn)
	end
end)

clock:on("hour", function()
	setGame()
	for guild in client.guilds:iter() do
		doModules(moduleHandler.tree.clock.hour, guild, conn, guild, conn)
	end
end)

client:on("ready", function()
	setGame()
end)

client:on("guildCreate", function(guild)
	getGuildSettings(guild.id, conn) -- generate guild settings if they don't exist
end)

client:on("memberJoin", function(member)
	doModules(moduleHandler.tree.client.memberJoin, member.guild, conn, member, conn)
end)

client:on("memberUpdate", function(member)
	doModules(moduleHandler.tree.client.memberUpdate, member.guild, conn, member, conn)
end)

client:on("memberLeave", function(member)
	doModules(moduleHandler.tree.client.memberLeave, member.guild, conn, member, conn)
	emitter:emit("collectgarbage")
end)

emitter:on("collectgarbage", function()
	timer.sleep(100)
	collectgarbage()
end)

--[[
client:on("userBan", function(user, guild)
	doModules(moduleHandler.tree.client.userBan, guild, conn, user, guild, conn)
end)
]]

client:on("reactionAdd", function(reaction, userId)
	if not reaction.message.guild then return end
	doModules(moduleHandler.tree.client.reactionAdd, reaction.message.guild, conn, reaction, userId, conn)
end)

client:on("reactionAddUncached", function(channel, messageId, hash, userId)
	if not channel.guild then return end
	doModules(moduleHandler.tree.client.reactionAddUncached, channel.guild, conn, channel, messageId, hash, userId, conn)
end)

client:on("reactionRemove", function(reaction, userId)
	if not reaction.message.guild then return end
	doModules(moduleHandler.tree.client.reactionRemove, reaction.message.guild, conn, reaction, userId, conn)
end)

client:on("reactionRemoveUncached", function(channel, messageId, hash, userId)
	if not channel.guild then return end
	doModules(moduleHandler.tree.client.reactionRemoveUncached, channel.guild, conn, channel, messageId, hash, userId, conn)
end)

client:on("messageCreate", function(message)
	local success, err = xpcall(function()
		if message.author.bot
			or message.channel.type == discordia.enums.channelType.private
			or not message.guild then return end
		local guildSettings = getGuildSettings(message.guild.id, conn)

		moduleHandler.doModules(moduleHandler.tree.client.messageCreate, guildSettings, message, conn)

		commandHandler.doCommands(message, guildSettings, conn)
	end, debug.traceback)
	if not success then
		utils.logError(message.guild, err)
		print("Bot crashed! Guild: "..message.guild.name.." ("..message.guild.id..")\n"..err)
	end
end)

--[[
client:on("messageUpdate", function(message)
	if not message.guild then return end
	doModules(moduleHandler.tree.client.messageUpdate, message.guild, conn, message, conn)
end)

client:on("messageDelete", function(message)
	if not message.guild then return end
	doModules(moduleHandler.tree.client.messageDelete, message.guild, conn, message, conn)
end)
]]

clock:start()
client:run("Bot "..options.token)