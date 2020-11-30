local commandHandler = require("commandHandler")
local utils = require("miscUtils")

return {
	name = "restart",
	description = "Restarts the bot.",
	usage = "",
	visible = false,
	botGuildPermissions = {},
	botChannelPermissions = {},
	permissions = {"bot.botOwner"},
	run = function(self, message, argString, args, guildSettings, conn)
		utils.sendEmbed(message.channel, "Restarting.", "00ff00")
		os.exit()
	end,
	onEnable = function(self, message, guildSettings)
		return true
	end,
	onDisable = function(self, message, guildSettings)
		return true
	end,
	subcommands = {}
}