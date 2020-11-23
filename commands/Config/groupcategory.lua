local commandHandler = require("commandHandler")
local utils = require("miscUtils")
local discordia = require("discordia")

return {
	name = "groupcategory",
	description = "Sets the group category, in which voice channels will be created for groups. We recommended making this the same category that the group channel is in, for clarity purposes.\nPlease provide the category's id, NOT the name.",
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

		conn:exec("UPDATE guild_settings SET group_category_id = '"..category.id.."' WHERE guild_id = '"..message.guild.id.."';")

		utils.sendEmbed(message.channel, "Group category set to "..category.name..".", "00ff00")
	end,
	onEnable = function(self, message, guildSettings)
		return true
	end,
	onDisable = function(self, message, guildSettings)
		return true
	end,
	subcommands = {}
}