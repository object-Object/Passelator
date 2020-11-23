local commandHandler = require("commandHandler")
local utils = require("miscUtils")
local groupUtils = require("groupUtils")

return {
	name = "delete",
	description = "Deletes a group.",
	usage = "<group number>",
	visible = true,
	permissions = {},
	run = function(self, message, argString, args, guildSettings, conn)
		if argString=="" then
			commandHandler.sendUsage(message.channel, guildSettings, self)
			return
		end

		local groupNum = argString:gsub("#", "")
		local stmt = conn:prepare("SELECT * FROM groups WHERE guild_id = ? AND group_num = ?;")
		local row = utils.formatRow(stmt:reset():bind(message.guild.id, groupNum):resultset("k"))
		stmt:close()
		if not row then
			utils.sendEmbed(message.channel, "Invalid group number.", "ff0000")
			return
		end

		if message.author.id==row.creator_id then
			message.guild:getRole(row.role_id):delete()

			message.guild:getChannel(row.voice_channel_id):delete()

			local groupMessage = message.guild:getChannel(guildSettings.group_channel_id):getMessage(row.message_id)
			groupMessage:setEmbed(groupUtils.getDeletedGroupEmbed(message.author, row.group_num, row.name))
			groupMessage:clearReactions()

			local stmt2 = conn:prepare("DELETE FROM groups WHERE guild_id = ? AND group_num = ?;")
			stmt2:reset():bind(row.guild_id, row.group_num):step()
			stmt2:close()

			utils.sendEmbed(message.channel, "Group #"..row.group_num.." has been deleted.", "00ff00")
		else
			utils.sendEmbed(message.channel, "Only the group's creator may delete it.", "ff0000")
		end
	end,
	onEnable = function(self, message, guildSettings)
		return true
	end,
	onDisable = function(self, message, guildSettings)
		return true
	end,
	subcommands = {}
}