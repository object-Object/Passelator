local moduleHandler = require("moduleHandler")

return {
	name = "game-remove",
	description = "Removes a game group role from a user when they remove their reaction.",
	visible = false,
	disabledByDefault = false,
	run = function(self, guildSettings, reaction, userId, conn)
		moduleHandler.modules["game-remove-uncached"]:run(guildSettings, reaction.message.channel, reaction.message.id, reaction.emojiHash, userId, conn)
	end,
	onEnable = function(self, message, guildSettings, conn)
		return true
	end,
	onDisable = function(self, message, guildSettings, conn)
		return true
	end
}