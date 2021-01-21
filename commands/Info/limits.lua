local discordia = require("discordia")
local limits = discordia.storage.limits

return {
	name = "limits",
	description = "Displays built-in limits present in the bot.",
	usage = "",
	visible = true,
	isDefaultDisabled = nil,
	botGuildPermissions = {},
	botChannelPermissions = {},
	permissions = {},
	run = function(self, message, argString, args, guildSettings, conn)
		message:reply{
			embed = {
				description = "These are built-in limits in the bot to avoid reaching Discord's character limits. They cannot be changed by users.",
				fields = {
					{name = "Maximum Group Number", value = limits.groupNum, inline=true},
					{name = "Displayed Group Members", value = limits.groupMembers.." (more can join, but not all members will be displayed)", inline=true},
					{name = "Group Name Length", value = limits.groupNameLength.." characters", inline=true},
					{name = "Group Game Code Length", value = limits.groupCodeLength.." characters", inline=true},
					{name = "Group Date/Time Length", value = limits.groupDateTimeLength.." characters", inline=true},
					{name = "Linked Groups", value = limits.linkedGroups.." per group", inline=true},
				},
				color = discordia.Color.fromHex("00ff00").value,
			}
		}
	end,
	onEnable = nil,
	onDisable = nil,
	subcommands = {}
}