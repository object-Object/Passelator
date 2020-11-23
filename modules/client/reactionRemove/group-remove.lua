local moduleHandler = require("moduleHandler")

return {
	name = "group-remove",
	description = "Removes a group role from a user when they remove their reaction.",
	visible = false,
	disabledByDefault = false,
	run = function(self, guildSettings, reaction, userId, conn)
		moduleHandler.modules["group-remove-uncached"]:run(guildSettings, reaction.message.channel, reaction.message.id, reaction.emojiHash, userId, conn)
	end,
	onEnable = function(self, message, guildSettings, conn)
		return true
	end,
	onDisable = function(self, message, guildSettings, conn)
		return true
	end
}