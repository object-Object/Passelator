local commandHandler = require("commandHandler")
local utils = require("miscUtils")
local groupUtils = require("groupUtils")

return {
	name = "delete",
	description = "Deletes a game group.",
	usage = "<game number>",
	visible = true,
	permissions = {},
	run = function(self, message, argString, args, guildSettings, conn)
		if argString=="" then
			commandHandler.sendUsage(message.channel, guildSettings, self)
			return
		end

		local gameNum = argString:gsub("#", "")
		local stmt = conn:prepare("SELECT * FROM games WHERE guild_id = ? AND game_num = ?;")
		local row = utils.formatRow(stmt:reset():bind(message.guild.id, gameNum):resultset("k"))
		stmt:close()
		p(row)
		if not row then
			utils.sendEmbed(message.channel, "Invalid game number.", "ff0000")
			return
		end

		if message.author.id==row.author_id then
			message.guild:getRole(row.role_id):delete()

			message.guild:getChannel(row.voice_channel_id):delete()

			local gameMessage = message.guild:getChannel(guildSettings.games_channel_id):getMessage(row.message_id)
			gameMessage:setEmbed(groupUtils.getDeletedGroupEmbed(message.author, row.game_num, row.name))
			gameMessage:clearReactions()

			local stmt2 = conn:prepare("DELETE FROM games WHERE guild_id = ? AND game_num = ?;")
			stmt2:reset():bind(row.guild_id, row.game_num):step()
			stmt2:close()

			utils.sendEmbed(message.channel, "Game #"..row.game_num.." has been deleted.", "00ff00")
		else
			utils.sendEmbed(message.channel, "Only the creator of the game group may delete it.", "ff0000")
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