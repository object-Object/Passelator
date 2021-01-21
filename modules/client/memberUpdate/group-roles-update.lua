local groupUtils = require("groupUtils")
local discordia = require("discordia")
local uv = require("uv")
local timer = require("timer")
local joinBuffer = 250 -- time in ms to wait after user joins guild before handling member updates for them

return {
	name = "group-roles-update",
	description = "Updates the user_roles table and the group message when someone gets or loses a group role.",
	run = function(self, guildSettings, member, conn)
		--[[
		can't exit early, because multiple roles can be added at once (PATCH member)

		for member roles in user_roles:
			if the user doesn't have the role:
				remove from user_roles
				update group message

		for member.roles:
			if it's a group role and not already in user_roles:
				add to user_roles
				update group message
		]]

		while discordia.storage.addingRolesOnJoin[member.guild.id.."-"..member.id] do -- keeps async from doing things out of order when a user joins
			timer.sleep(50)
		end

		if not guildSettings.group_channel_id then return end
		local groupChannel = member.guild:getChannel(guildSettings.group_channel_id)
		local rows, nrow = conn:exec([[
SELECT groups.role_id AS role_id, groups.message_id AS message_id
FROM groups
JOIN user_roles ON groups.guild_id = user_roles.guild_id AND groups.role_id = user_roles.role_id
WHERE user_roles.user_id = ']]..member.id..[[' AND groups.guild_id = ']]..member.guild.id..[[';
]], "k")
		local userRolesInDB = {}
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
				else
					userRolesInDB[roleId] = true
				end
			end
			deleteStmt:close()
		end

		local selectStmt = conn:prepare("SELECT message_id FROM groups WHERE role_id = ? AND guild_id = '"..member.guild.id.."';")
		local insertStmt = conn:prepare("INSERT INTO user_roles (role_id, guild_id, user_id, is_from_link) VALUES (?, '"..member.guild.id.."', '"..member.id.."', ?);")
		local checkedRoles = {} -- this is necessary due to a bug in Discordia
		for role in member.roles:iter() do
			if not checkedRoles[role.id] then
				local row = selectStmt:reset():bind(role.id):step()
				if row and not userRolesInDB[role.id] then -- user now has group role, but not already in user_roles
					local isFromLink = discordia.storage.isFromLink[role.id.."-"..member.guild.id.."-"..member.id]
					local success, err = pcall(insertStmt:reset():bind(role.id, isFromLink and 1 or 0).step, insertStmt)
					discordia.storage.isFromLink[role.id.."-"..member.guild.id.."-"..member.id] = nil
					if not success then error(err) end
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