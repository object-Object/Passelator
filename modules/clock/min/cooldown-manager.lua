local utils = require("miscUtils")

return {
	name = "cooldown-manager",
	description = "Removes ping cooldowns.",
	visible = false,
	disabledByDefault = false,
	run = function(self, guildSettings, guild, conn)
		local row, _ = conn:exec("SELECT * FROM ping_cooldowns WHERE guild_id="..guild.id..";","k")
		row = utils.formatRow(row)
		if row and row.end_timestamp < os.time() then
			conn:exec("DELETE FROM ping_cooldowns WHERE guild_id="..guild.id..";")
		end
	end,
	onEnable = function(self, message, guildSettings, conn)
		return true
	end,
	onDisable = function(self, message, guildSettings, conn)
		return true
	end
}