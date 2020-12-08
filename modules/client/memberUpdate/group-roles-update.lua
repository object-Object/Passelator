local groupUtils = require("groupUtils")

return {
	name = "group-roles-update",
	description = "Updates the user_roles table and the group message when someone gets or loses a group role.",
	run = function(self, guildSettings, member, conn)
		--[[
		for member roles in user_roles:
			if the user doesn't have the role:
				remove from user_roles
				update group message
				return?

		for member.roles:
			if it's a group role and not already in user_roles:
				add to user_roles
				update group message
				return?
		]]

		if not guildSettings.group_channel_id then return end
		local groupChannel = member.guild:getChannel(guildSettings.group_channel_id)

		local rows, nrow = conn:exec([[
SELECT groups.role_id AS role_id, groups.message_id AS message_id
FROM groups
JOIN user_roles ON groups.guild_id = user_roles.guild_id AND groups.role_id = user_roles.role_id
WHERE user_roles.user_id = ']]..member.id..[[' AND groups.guild_id = ']]..member.guild.id..[[';
]], "k")
		local rolesLookup = {}
		if rows then
			local deleteStmt = conn:prepare("DELETE FROM user_roles WHERE role_id = ? AND guild_id = '"..member.guild.id.."' AND user_id = '"..member.id.."';")
			for row = 1, nrow do
				local roleId = rows.role_id[row]
				if not member:hasRole(roleId) then
					deleteStmt:reset():bind(roleId):step()
					local role = member.guild:getRole(roleId)
					if role then
						local groupMessage = groupChannel:getMessage(rows.message_id[row])
						groupUtils.updateMembers(groupMessage, role, guildSettings)
					end
				end
				rolesLookup[roleId] = true
			end
			deleteStmt:close()
		end

		local selectStmt = conn:prepare("SELECT message_id FROM groups WHERE role_id = ? AND guild_id = '"..member.guild.id.."';")
		local insertStmt = conn:prepare("INSERT INTO user_roles (role_id, guild_id, user_id) VALUES (?, '"..member.guild.id.."', '"..member.id.."');")
		local checkedRoles = {} -- this is necessary due to a bug in Discordia
		for role in member.roles:iter() do
			if not checkedRoles[role.id] then
				local row = selectStmt:reset():bind(role.id):step()
				if row and not rolesLookup[role.id] then -- group role, but not already in user_roles
					insertStmt:reset():bind(role.id):step()
					local groupMessage = groupChannel:getMessage(row[1])
					groupUtils.updateMembers(groupMessage, role, guildSettings)
				end
				checkedRoles[role.id] = true
			end
		end
		selectStmt:close()
		insertStmt:close()
	end
}