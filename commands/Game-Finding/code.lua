local commandHandler = require("commandHandler")
local utils = require("miscUtils")
local groupUtils = require("groupUtils")

return {
	name = "code",
	description = "Displays or sets the game link/code for a specific game.",
	usage = "<game number> [new game code or link]",
	visible = true,
	permissions = {},
	run = function(self, message, argString, args, guildSettings, conn)
		if argString=="" then
			commandHandler.sendUsage(message.channel, guildSettings, self)
			return
		end

		local gameNum = args[1]:gsub("#", "")
		local stmt = conn:prepare("SELECT * FROM games WHERE guild_id = ? AND game_num = ?;")
		local row = utils.formatRow(stmt:reset():bind(message.guild.id, gameNum):resultset("k"))
		stmt:close()
		if not row then
			utils.sendEmbed(message.channel, "Invalid game number.", "ff0000")
			return
		end

		if #args==1 then
			-- display code
			utils.sendEmbed(message.channel, "Game code/link for Game #"..row.game_num..": "..row.game_code, "00ff00")
		elseif message.author.id==row.author_id then
			-- set code
			local newCode = argString:gsub("^"..args[1].."%s+", "")
			local stmt2 = conn:prepare("UPDATE games SET game_code = ? WHERE guild_id = ? AND game_num = ?;")
			stmt2:reset():bind(newCode, row.guild_id, row.game_num):step()
			stmt2:close()

			local role = message.guild:getRole(row.role_id)
			local voiceChannel = message.guild:getChannel(row.voice_channel_id)
			local gamesChannel = message.guild:getChannel(guildSettings.games_channel_id)
			local gameMessage = gamesChannel:getMessage(row.message_id)

			gameMessage:setEmbed(groupUtils.getGroupEmbed(message.author, row.game_num, row.name, role, voiceChannel, row.voice_channel_invite, newCode))

			utils.sendEmbed(message.channel, "The game code/link for Game #"..row.game_num.." is now: "..newCode, "00ff00")
		else
			utils.sendEmbed(message.channel, "Only the creator of the game group may set the game code/link.", "ff0000")
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