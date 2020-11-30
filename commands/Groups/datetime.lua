local commandHandler = require("commandHandler")
local utils = require("miscUtils")
local groupUtils = require("groupUtils")

return {
	name = "datetime",
	description = "Displays or sets a group's date/time.",
	usage = "<group number> [new date/time]",
	visible = true,
	permissions = {},
	run = function(self, message, argString, args, guildSettings, conn)
		if argString=="" then
			commandHandler.sendUsage(message.channel, guildSettings, self)
			return
		end

		local groupNum = args[1]:gsub("#", "")
		local stmt = conn:prepare("SELECT date_time, creator_id, message_id FROM groups WHERE guild_id = ? AND group_num = ?;")
		local row = utils.formatRow(stmt:reset():bind(message.guild.id, groupNum):resultset("k"))
		stmt:close()
		if not row then
			utils.sendEmbed(message.channel, "Invalid group number.", "ff0000")
			return
		end

		local newDateTime = argString:gsub("^"..args[1].."%s+", "")

		if #args==1 then
			-- display
			utils.sendEmbed(message.channel, "Date/time for Group #"..groupNum..": **"..row.date_time.."**", "00ff00")
			return
		elseif message.author.id~=row.creator_id then
			utils.sendEmbed(message.channel, "Only the group's creator may set its date/time.", "ff0000")
			return
		end

		local stmt2 = conn:prepare("UPDATE groups SET date_time = ? WHERE guild_id = ? AND group_num = ?;")
		stmt2:reset():bind(newDateTime, message.guild.id, groupNum):step()
		stmt2:close()

		local groupChannel = message.guild:getChannel(guildSettings.group_channel_id)
		local groupMessage = groupChannel:getMessage(row.message_id)
		groupUtils.updateDateTime(groupMessage, newDateTime)

		utils.sendEmbed(message.channel, "The date/time for Group #"..groupNum.." is now: **"..newDateTime.."**", "00ff00")
	end,
	onEnable = function(self, message, guildSettings)
		return true
	end,
	onDisable = function(self, message, guildSettings)
		return true
	end,
	subcommands = {}
}