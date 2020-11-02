local commandHandler = require("commandHandler")
local discordia = require("discordia")
local fs = require("fs")

return {
	name = "about",
	description = "Shows information about the bot.",
	usage = "",
	visible = true,
	permissions = {},
	run = function(self, message, argString, args, guildSettings, conn)
		local changelog=fs.readFileSync("changelog.txt")
		local version=changelog and changelog:match("%*%*([^%*]+)%*%*") or "error"
		message.channel:send{
			embed = {
				title = "About",
				description = "Passelator is a bot used to help with game-finding, and is specifically designed for Among Us. It is written (in Lua), hosted, and maintained by [object Object]#0001.",
				color = discordia.Color.fromHex("00ff00").value,
				fields = {
					{name = "Servers", value = #message.client.guilds},
					{name = "GitHub", value = "https://github.com/object-Object/Passelator"},
					{name = "Invite link", value = "https://discord.com/api/oauth2/authorize?client_id=772674051076128789&permissions=268593232&scope=bot"}
				},
				footer = {
					text = "Version: "..version
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