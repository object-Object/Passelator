local moduleHandler = require("moduleHandler")

return {
	name = "group-add",
	description = "Adds a group role to a user when they click the reaction.",
	visible = false,
	disabledByDefault = false,
	run = function(self, guildSettings, reaction, userId, conn)
		moduleHandler.modules["group-add-uncached"]:run(guildSettings, reaction.message.channel, reaction.message.id, reaction.emojiHash, userId, conn)
	end,
	onEnable = function(self, message, guildSettings, conn)
		return true
	end,
	onDisable = function(self, message, guildSettings, conn)
		return true
	end
}