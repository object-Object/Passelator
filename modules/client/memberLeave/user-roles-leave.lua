local groupUtils = require("groupUtils")

return {
	name = "user-roles-leave",
	description = "Caches user group roles when they leave, and updates all relevant group messages.",
	run = function(self, guildSettings, member, conn)
		if not guildSettings.group_channel_id then return end
		conn:exec("UPDATE user_roles SET user_in_guild = 0 WHERE guild_id = '"..member.guild.id.."' AND user_id = '"..member.id.."';")
		local selectStmt = conn:prepare("SELECT message_id FROM groups WHERE guild_id = ? AND role_id = ?;")
		local channel = member.guild:getChannel(guildSettings.group_channel_id)
		local checkedRoles = {} -- necessary due to a bug in Discordia where member.roles sometimes has duplicates
		for role in member.roles:iter() do
			if not checkedRoles[role.id] then
				local row = selectStmt:reset():bind(member.guild.id, role.id):resultset("k")
				if row then
					local groupMessage = channel:getMessage(row.message_id[1])
					groupUtils.updateMembers(groupMessage, role, guildSettings)
				end
				checkedRoles[role.id] = true
			end
		end
		selectStmt:close()
	end
}