local commandHandler = require("commandHandler")
local utils = require("miscUtils")
local discordia = require("discordia")

return {
	name = "gamescategory",
	description = "Sets the games category, in which voice channels will be created for game groups.",
	usage = "<category id>",
	visible = true,
	permissions = {"administrator"},
	run = function(self, message, argString, args, guildSettings, conn)
		if argString=="" then
			commandHandler.sendUsage(message.channel, guildSettings, self)
			return
		end

		local category = message.guild:getChannel(argString)
		if not category or category.type~=discordia.enums.channelType.category then
			utils.sendEmbed(message.channel, "Invalid category id. Please enter the id of a valid category.", "ff0000")
			return
		end

		conn:exec("UPDATE guild_settings SET games_category_id = '"..category.id.."' WHERE guild_id = '"..message.guild.id.."';")

		utils.sendEmbed(message.channel, "Games category set to "..category.name..".", "00ff00")
	end,
	onEnable = function(self, message, guildSettings)
		return true
	end,
	onDisable = function(self, message, guildSettings)
		return true
	end,
	subcommands = {}
}