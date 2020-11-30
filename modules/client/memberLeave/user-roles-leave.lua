local utils = require("miscUtils")
local groupUtils = require("groupUtils")

return {
	name = "user-roles-leave",
	description = "Caches user group roles when they leave, and updates all relevant group messages.",
	run = function(self, guildSettings, member, conn)
		if not guildSettings.group_channel_id then return end
		local selectStmt = conn:prepare("SELECT message_id, role_id FROM groups WHERE guild_id = ? AND role_id = ?;")
		local insertStmt = conn:prepare("INSERT INTO user_roles (guild_id, user_id, role_id) VALUES (?, ?, ?);")
		local channel = member.guild:getChannel(guildSettings.group_channel_id)
		local checkedRoles = {} -- necessary due to a bug in Discordia where member.roles sometimes has duplicates
		for role in member.roles:iter() do
			if not checkedRoles[role.id] then
				local row = selectStmt:reset():bind(member.guild.id, role.id):resultset("k")
				if row then
					row = utils.formatRow(row)
					if guildSettings.give_back_roles then
						insertStmt:reset():bind(member.guild.id, member.id, role.id):step()
					end
					local role = member.guild:getRole(row.role_id)
					local groupMessage = channel:getMessage(row.message_id)
					groupUtils.updateMembers(groupMessage, role, guildSettings)
				end
				checkedRoles[role.id] = true
			end
		end
		selectStmt:close()
		insertStmt:close()
	end
}