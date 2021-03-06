local discordia = require("discordia")
local stopwatch = discordia.Stopwatch()

return {
	name = "ping",
	description = "Shows the bot's ping (latency).",
	usage = "",
	visible = true,
	botGuildPermissions = {},
	botChannelPermissions = {},
	permissions = {},
	run = function(self, message, argString, args, guildSettings, conn)
		stopwatch:reset()
		stopwatch:start()
		local outputMsg = message.channel:send("Pinging...")
		stopwatch:stop()
		outputMsg:update{
			embed = {
				description = "Ping: `"..math.floor(stopwatch:getTime():toMilliseconds()+0.5).." ms`",
				color = discordia.Color.fromHex("00ff00").value
			}
		}
	end,
	onEnable = function(self, message, guildSettings)
		return true
	end,
	onDisable = function(self, message, guildSettings)
		return true
	end,
	subcommands = {}
}