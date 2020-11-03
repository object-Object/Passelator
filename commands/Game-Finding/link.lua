local commandHandler = require("commandHandler")

return {
	name = "link",
	description = "Alias for `&prefix;code`.",
	usage = commandHandler.commands.code.usage,
	visible = true,
	permissions = {},
	run = function(self, message, argString, args, guildSettings, conn)
		commandHandler.commands.code:run(message, argString, args, guildSettings, conn)
	end,
	onEnable = function(self, message, guildSettings)
		return true
	end,
	onDisable = function(self, message, guildSettings)
		return true
	end,
	subcommands = {}
}