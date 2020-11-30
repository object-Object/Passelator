local commandHandler = require("commandHandler")
local utils = require("miscUtils")
local groupUtils = require("groupUtils")

return {
	name = "unlock",
	description = "Unlocks a group locked using the `&prefix;lock` command.",
	usage = "<group number>",
	visible = true,
	permissions = {},
	run = function(self, message, argString, args, guildSettings, conn)
		if argString=="" then
			commandHandler.sendUsage(message.channel, guildSettings, self)
			return
		end

		local groupNum = argString:gsub("#", "")
		local stmt = conn:prepare("SELECT creator_id, is_locked, message_id, name FROM groups WHERE guild_id = ? AND group_num = ?;")
		local row = utils.formatRow(stmt:reset():bind(message.guild.id, groupNum):resultset("k"))
		stmt:close()
		if not row then
			utils.sendEmbed(message.channel, "Invalid group number.", "ff0000")
			return
		elseif message.author.id~=row.creator_id then
			utils.sendEmbed(message.channel, "Only the group's creator may unlock it.", "ff0000")
			return
		elseif not row.is_locked then
			utils.sendEmbed(message.channel, "Group #"..groupNum.." is not locked.", "ff0000")
			return
		end

		local stmt2 = conn:prepare("UPDATE groups SET is_locked = 0 WHERE guild_id = ? AND group_num = ?;")
		stmt2:reset():bind(message.guild.id, groupNum):step()
		stmt2:close()

		local groupChannel = message.guild:getChannel(guildSettings.group_channel_id)
		local groupMessage = groupChannel:getMessage(row.message_id)

		groupUtils.updateLockedFields(groupMessage, groupNum, row.name, false, guildSettings)

		utils.sendEmbed(message.channel, "Group #"..groupNum.." has been unlocked. Users may now get "..(guildSettings.can_leave_locked and "" or "or remove ").."the role.", "00ff00")
	end,
	onEnable = function(self, message, guildSettings)
		return true
	end,
	onDisable = function(self, message, guildSettings)
		return true
	end,
	subcommands = {}
}