local utils = require("miscUtils")
local groupUtils = require("groupUtils")

return {
	name = "group-remove-uncached",
	description = "Removes a group role from a user when they remove the reaction.",
	run = function(self, guildSettings, channel, messageId, hash, userId, conn)
		if hash~="✅" or userId==channel.client.user.id then return end

		local row = utils.formatRow(conn:exec("SELECT group_num, is_locked, role_id FROM groups WHERE guild_id = "..channel.guild.id.." AND message_id = "..messageId..";"))
		if not row or (row.is_locked and not guildSettings.can_leave_locked) then return end

		local member = channel.guild:getMember(userId)
		member:removeRole(row.role_id)
		local rows, nrow = conn:exec(string.format([[
SELECT groups.guild_id AS guild_id, groups.role_id AS role_id
FROM (
	SELECT group_b_num AS group_num, guild_b_id AS guild_id FROM group_links WHERE group_a_num = %s AND guild_a_id = %s
	UNION ALL
	SELECT group_a_num AS group_num, guild_a_id AS guild_id FROM group_links WHERE group_b_num = %s AND guild_b_id = %s
) t1
JOIN groups ON t1.guild_id = groups.guild_id AND t1.group_num = groups.group_num;
]], row.group_num, channel.guild.id, row.group_num, channel.guild.id)) -- get guild_id and role_id for all groups linked to this one
		for row=1, nrow do
			local rowGuild = channel.client:getGuild(rows.guild_id[row])
			local rowMember = rowGuild:getMember(userId)
			if rowMember then
				rowMember:removeRole(rows.role_id[row])
			end
		end
	end
}