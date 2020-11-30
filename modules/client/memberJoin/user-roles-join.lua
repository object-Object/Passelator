return {
	name = "user-roles-join",
	description = "Gives back user group roles when they rejoin.",
	run = function(self, guildSettings, member, conn)
		if not guildSettings.group_channel_id then return end
		if not guildSettings.give_back_roles then
			conn:exec("DELETE FROM user_roles WHERE guild_id = '"..member.guild.id.."' AND user_id = '"..member.id.."';")
			return
		end
		local rows, nrow = conn:exec([[
SELECT groups.role_id AS role_id
FROM groups
JOIN user_roles ON groups.guild_id = user_roles.guild_id AND groups.role_id = user_roles.role_id
WHERE user_roles.user_id = ']]..member.id..[[' AND groups.guild_id = ']]..member.guild.id..[[';
]], "k")
		if not rows then return end
		conn:exec("UPDATE user_roles SET user_in_guild = 1 WHERE guild_id = '"..member.guild.id.."' AND user_id = '"..member.id.."';")
		for row = 1, nrow do
			member:addRole(rows.role_id[row])
		end
	end
}