local commandHandler = require("commandHandler")
local discordia = require("discordia")
local fs = require("fs")

return {
	name = "about",
	description = "Shows information about the bot.",
	usage = "",
	visible = true,
	botGuildPermissions = {},
	botChannelPermissions = {},
	permissions = {},
	run = function(self, message, argString, args, guildSettings, conn)
		local changelog=fs.readFileSync("changelog.txt")
		local version=changelog and changelog:match("%*%*([^%*]+)%*%*") or "error"
		message.channel:send{
			embed = {
				title = "About",
				description = "Passelator is a bot that helps schedule games by allowing users to create custom, self-assignable roles, and private voice channels for those roles. It is written (in Lua), hosted, and maintained by [object Object]#0001.",
				color = discordia.Color.fromHex("00ff00").value,
				fields = {
					{name = "Getting Started", value = [[**1.** Create a new group using `]]..guildSettings.prefix..[[new <group name>`.
**2.** Go to the groups channel and get the role by clicking :white_check_mark:.
**3.** Edit the group's settings using `]]..guildSettings.prefix..[[code`, `]]..guildSettings.prefix..[[datetime`, etc. See `]]..guildSettings.prefix..[[help` for more commands.
**4.** Invite your friends to join your new group.
**5.** When your game is ready to start, ping the group's custom role, join its voice channel, and play some games!
**Note:** The server admins need to first set up the bot using `]]..guildSettings.prefix..[[settings`. Specifically, the Group Category and Group Channel settings must be set before the groups feature may be used.]]},
					{name = "Servers", value = #message.client.guilds},
					{name = "Invite Link", value = "[Click to invite Passelator to your server!](https://discord.com/api/oauth2/authorize?client_id=772674051076128789&permissions="..tonumber(discordia.storage.requiredPermissions:toHex()).."&scope=bot)"},
					{name = "GitHub", value = "https://github.com/object-Object/Passelator"},
					{name = "Vote for Passelator", value = "[top.gg](https://top.gg/bot/772674051076128789/vote)\n[Discord Bot List](https://discordbotlist.com/bots/passelator/upvote)"},
					{name = "Contact Me", value = "Found a bug? Have a suggestion? Tell me about it! Use the command `"..guildSettings.prefix.."contact` to send me a message."},
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