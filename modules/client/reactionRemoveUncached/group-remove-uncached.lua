local utils = require("miscUtils")
local groupUtils = require("groupUtils")

return {
	name = "group-remove-uncached",
	description = "Removes a group role from a user when they remove their reaction.",
	visible = false,
	disabledByDefault = false,
	run = function(self, guildSettings, channel, messageId, hash, userId, conn)
		if channel.id~=guildSettings.group_channel_id or hash~="✅" or userId==channel.client.user.id then return end

		local stmt = conn:prepare("SELECT * FROM groups WHERE message_id = ?;")
		local row = utils.formatRow(stmt:reset():bind(messageId):resultset("k"))
		stmt:close()
		if not row or row.is_locked then return end

		local member = channel.guild:getMember(userId)
		member:removeRole(row.role_id)

		local role = channel.guild:getRole(row.role_id)
		local voiceChannel = channel.guild:getChannel(row.voice_channel_id)
		local groupMessage = channel:getMessage(messageId)
		local creator = channel.client:getUser(row.creator_id)

		groupMessage:setEmbed(groupUtils.getGroupEmbed(creator, row.group_num, row.name, role, voiceChannel, row.voice_channel_invite, row.code, row.is_locked, row.date_time))
	end,
	onEnable = function(self, message, guildSettings, conn)
		return true
	end,
	onDisable = function(self, message, guildSettings, conn)
		return true
	end
}