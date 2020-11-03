local commandHandler = require("commandHandler")
local utils = require("miscUtils")
local discordia = require("discordia")

return {
	name = "gameschannel",
	description = "Sets the games channel, in which game group messages will be sent. Must provide the channel's id, **not** the channel mention.",
	usage = "<channel id>",
	visible = true,
	permissions = {"administrator"},
	run = function(self, message, argString, args, guildSettings, conn)
		if argString=="" then
			commandHandler.sendUsage(message.channel, guildSettings, self)
			return
		end

		local channel = message.guild:getChannel(argString)
		if not channel or channel.type~=discordia.enums.channelType.text then
			utils.sendEmbed(message.channel, "Invalid channel id. Please enter the id of a valid channel.", "ff0000")
			return
		end

		conn:exec("UPDATE guild_settings SET games_channel_id = '"..channel.id.."' WHERE guild_id = '"..message.guild.id.."';")

		utils.sendEmbed(message.channel, "Games channel set to "..channel.mentionString..".", "00ff00")
	end,
	onEnable = function(self, message, guildSettings)
		return true
	end,
	onDisable = function(self, message, guildSettings)
		return true
	end,
	subcommands = {}
}