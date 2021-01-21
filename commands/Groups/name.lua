local commandHandler = require("commandHandler")
local utils = require("miscUtils")
local groupUtils = require("groupUtils")
local discordia = require("discordia")
local limits = discordia.storage.limits

return {
	name = "name",
	description = "Displays or sets a group's name.",
	usage = "<group number> [new name]",
	visible = true,
	botGuildPermissions = {"manageChannels"},
	botChannelPermissions = {},
	permissions = {},
	run = function(self, message, argString, args, guildSettings, conn)
		if argString=="" then
			commandHandler.sendUsage(message.channel, guildSettings, self)
			return
		end

		local groupNum = args[1]:gsub("#", "")
		local stmt = conn:prepare("SELECT name, creator_id, voice_channel_id, message_id, voice_channel_invite, is_locked FROM groups WHERE guild_id = ? AND group_num = ?;")
		local row = utils.formatRow(stmt:reset():bind(message.guild.id, groupNum):resultset("k"))
		stmt:close()
		if not row then
			utils.sendEmbed(message.channel, "Invalid group number.", "ff0000")
			return
		end

		local newName = argString:gsub("^"..args[1].."%s+", "")

		if #args==1 then
			-- display
			utils.sendEmbed(message.channel, "Name of Group #"..groupNum..": **"..row.name.."**", "00ff00")
			return
		elseif message.author.id~=row.creator_id then
			utils.sendEmbed(message.channel, "Only the group's creator may set its name.", "ff0000")
			return
		elseif #newName>limits.groupNameLength then
			utils.sendEmbed(message.channel, "Group name cannot be longer than "..limits.groupNameLength.." characters.", "ff0000")
			return
		end

		local stmt2 = conn:prepare("UPDATE groups SET name = ? WHERE guild_id = ? AND group_num = ?;")
		stmt2:reset():bind(newName, message.guild.id, groupNum):step()
		stmt2:close()

		local voiceChannel = message.guild:getChannel(row.voice_channel_id)
		local groupChannel = message.guild:getChannel(guildSettings.group_channel_id)
		local groupMessage = groupChannel:getMessage(row.message_id)
		voiceChannel:setName("Group #"..groupNum.." - "..newName)
		groupUtils.updateNameFields(groupMessage, groupNum, newName, voiceChannel, row.voice_channel_invite, row.is_locked)

		utils.sendEmbed(message.channel, "The name of Group #"..groupNum.." is now: **"..newName.."**", "00ff00")
	end,
	onEnable = function(self, message, guildSettings)
		return true
	end,
	onDisable = function(self, message, guildSettings)
		return true
	end,
	subcommands = {}
}