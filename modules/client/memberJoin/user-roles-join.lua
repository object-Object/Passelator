local discordia = require("discordia")
local groupUtils = require("groupUtils")

return {
	name = "user-roles-join",
	description = "Gives back user group roles when they rejoin.",
	run = function(self, guildSettings, member, conn)
		discordia.storage.addingRolesOnJoin[member.guild.id.."-"..member.id] = true
		if not guildSettings.group_channel_id then
			discordia.storage.addingRolesOnJoin[member.guild.id.."-"..member.id] = nil
			return
		end
		if not guildSettings.give_back_roles then
			conn:exec("DELETE FROM user_roles WHERE guild_id = '"..member.guild.id.."' AND user_id = '"..member.id.."';")
			discordia.storage.addingRolesOnJoin[member.guild.id.."-"..member.id] = nil
			return
		end
		local rows, nrow = conn:exec([[
SELECT groups.role_id AS role_id, groups.message_id AS message_id
FROM groups
JOIN user_roles ON groups.guild_id = user_roles.guild_id AND groups.role_id = user_roles.role_id
WHERE user_roles.user_id = ']]..member.id..[[' AND groups.guild_id = ']]..member.guild.id..[[';
]], "k")
		if not rows then
			discordia.storage.addingRolesOnJoin[member.guild.id.."-"..member.id] = nil
			return
		end
		conn:exec("UPDATE user_roles SET user_in_guild = 1 WHERE guild_id = '"..member.guild.id.."' AND user_id = '"..member.id.."';")
		local groupChannel = member.guild:getChannel(guildSettings.group_channel_id)
		for row = 1, nrow do
			member:addRole(rows.role_id[row])
			local role = member.guild:getRole(rows.role_id[row])
			if role then
				local groupMessage = groupChannel:getMessage(rows.message_id[row])
				groupUtils.updateMembers(groupMessage, role, guildSettings)
			end
		end
		discordia.storage.addingRolesOnJoin[member.guild.id.."-"..member.id] = nil
	end
}