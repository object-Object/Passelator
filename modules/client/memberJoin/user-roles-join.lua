local groupUtils = require("groupUtils")

return {
	name = "user-roles-join",
	description = "Gives back user group roles when they rejoin, and updates all relevant group messages.",
	run = function(self, guildSettings, member, conn)
		if not (guildSettings.give_back_roles and guildSettings.group_channel_id) then return end
		local rows, nrow = conn:exec([[
SELECT groups.role_id AS role_id, groups.message_id AS message_id
FROM groups
JOIN user_roles ON groups.guild_id = user_roles.guild_id AND groups.role_id = user_roles.role_id
WHERE user_roles.user_id = ']]..member.id..[[' AND groups.guild_id = ']]..member.guild.id..[[';
]], "k")
		if not rows then return end
		local channel = member.guild:getChannel(guildSettings.group_channel_id)
		local stmt = conn:prepare("DELETE FROM user_roles WHERE guild_id = ? AND user_id = ? AND role_id = ?;")
		for row = 1, nrow do
			local role = member.guild:getRole(rows.role_id[row])
			local message = channel:getMessage(rows.message_id[row])
			if role and message then
				member:addRole(role)
				stmt:reset():bind(member.guild.id, member.id, role.id):step()
				groupUtils.updateMembers(message, role, guildSettings)
			end
		end
		stmt:close()
	end
}