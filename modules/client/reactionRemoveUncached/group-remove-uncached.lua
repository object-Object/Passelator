local utils = require("miscUtils")
local groupUtils = require("groupUtils")

return {
	name = "group-remove-uncached",
	description = "Removes a group role from a user when they remove the reaction.",
	run = function(self, guildSettings, channel, messageId, hash, userId, conn)
		if hash~="✅" or userId==channel.client.user.id then return end

		local stmt = conn:prepare("SELECT is_locked, role_id FROM groups WHERE message_id = ?;")
		local row = utils.formatRow(stmt:reset():bind(messageId):resultset("k"))
		stmt:close()
		if not row or (row.is_locked and not guildSettings.can_leave_locked) then return end

		local member = channel.guild:getMember(userId)
		member:removeRole(row.role_id)

		local role = channel.guild:getRole(row.role_id)
		local groupMessage = channel:getMessage(messageId)
		groupUtils.updateMembers(groupMessage, role, guildSettings)
	end
}