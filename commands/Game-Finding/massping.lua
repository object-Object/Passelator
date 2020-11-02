local discordia = require("discordia")
local utils = require("miscUtils")

return {
	name = "massping",
	description = "Pings `@here`, with a built-in delay.",
	usage = "",
	visible = true,
	permissions = {},
	run = function(self, message, argString, args, guildSettings, conn)
		local row, _ = conn:exec("SELECT * FROM ping_cooldowns WHERE guild_id="..message.guild.id..";","k")
		row = utils.formatRow(row)
		if row then
			if row.end_timestamp > os.time() then
				message:reply{
					embed = {
						description = "Mass pings are currently on cooldown. Try again later.",
						color = discordia.Color.fromHex("ff0000").value,
						footer = {
							text = "Cooldown: "..utils.secondsToTime(row.end_timestamp - os.time())
						}
					}
				}
				return
			else
				conn:exec("DELETE FROM ping_cooldowns WHERE guild_id="..message.guild.id..";")
			end
		end

		-- round to nearest minute
		local endTimestamp = math.floor((os.time() + guildSettings.mass_ping_cooldown)/60 + 0.5)*60
		conn:prepare("INSERT INTO ping_cooldowns VALUES (?, ?)"):reset():bind(message.guild.id, endTimestamp):step()

		message:reply{
			content = "@here",
			embed = {
				description = "Mass ping requested by "..utils.name(message.author)..".",
				color = discordia.Color.fromHex("ff0000").value,
				footer = {
					text = "Cooldown: "..utils.secondsToTime(endTimestamp - os.time())
				}
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