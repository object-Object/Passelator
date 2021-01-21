local discordia = require("discordia")
local limits = discordia.storage.limits
local utils = require("miscUtils")
local groupUtils = require("groupUtils")

return {
	name = "link",
	description = [[Links two groups together across servers. This makes all members of one group show up in the other, and vice versa.
- If a user joins a linked group and the user is in both servers, they will be given the role for both groups.
- Users who join one linked group will show up in the other group with a :link: beside their name.
- You can only link groups if you own them both.
- Groups in the same server cannot be linked.
- A group can be linked to a maximum of ]]..limits.linkedGroups..[[ other groups.
- If a group is linked to multiple groups, all of the groups will become linked.]],
	usage = "<first group num> <server ID for second group> <second group num>",
	visible = true,
	isDefaultDisabled = nil,
	botGuildPermissions = {"manageRoles"},
	botChannelPermissions = {},
	permissions = {},
	run = function(self, message, argString, args, guildSettings, conn)
		if #args~=3 then
			commandHandler.sendUsage(message.channel, guildSettings, self)
			return
		end

		message.channel:broadcastTyping()

		local rowStmt = conn:prepare([[
			SELECT groups.creator_id, groups.message_id, groups.role_id, groups.code, groups.date_time, group_links.linkset_num
			FROM groups
			WHERE guild_id = ? AND group_num = ?
			LEFT JOIN group_links ON groups.guild_id = group_links.guild_id AND groups.group_num = group_links.group_num;
		]])
		--[[
			SELECT group_num, guild_id
			FROM group_links
			WHERE linkset_num = (SELECT linkset_num FROM group_links WHERE group_num = ? AND guild_id = ?)
			AND NOT (group_num = ? AND guild_id = ?);
		]]
		local linkedGroupsStmt = conn:prepare([[
			SELECT groups.group_num, groups.guild_id, groups.message_id
			FROM group_links
			WHERE linkset_num = ? AND NOT (group_num = ? AND guild_id = ?)
			LEFT JOIN group_links ON groups.guild_id = group_links.guild_id AND groups.group_num = group_links.group_num;
		]])

		local groupNumA = args[1]:gsub("#", "")
		local rowA = utils.formatRow(rowStmt:reset():bind(message.guild.id, groupNumA):resultset("k"))
		if not rowA then
			utils.sendEmbed(message.channel, "Invalid first group number.", "ff0000")
			return
		end
		local roleA = message.guild:getRole(rowA.role_id)
		local groupChannelA = message.guild:getChannel(guildSettings.group_channel_id)
		local groupMessageA = groupChannelA:getMessage(rowA.message_id)
		local linkedGroupsA, numLinkedA
		if rowA.linkset_num then
			linkedGroupsA, numLinkedA = linkedGroupsStmt:reset():bind(rowA.linkset_num, groupNumA, message.guild.id):resultset("k")
		else
			linkedGroupsA, numLinkedA = {}, 0
		end

		local guildB = message.client:getGuild(args[2])
		if not guildB then
			utils.sendEmbed(message.channel, "Invalid server ID. Make sure the bot is in the specified server.", "ff0000")
			return
		end

		local groupNumB = args[3]:gsub("#", "")
		local rowB = utils.formatRow(rowStmt:reset():bind(guildB.id, groupNumB):resultset("k"))
		if not rowB then
			utils.sendEmbed(message.channel, "Invalid second group number.", "ff0000")
			return
		end
		local guildSettingsB = utils.formatRow(conn:exec("SELECT group_channel_id FROM guild_settings WHERE guild_id = "..guildB.id..";"))
			-- this is guaranteed to exist if we reach this point, because groupB exists, meaning the bot has done stuff there before
		local groupChannelB = guildB:getChannel(guildSettingsB.group_channel_id)
		local groupMessageB = groupChannelB:getMessage(rowB.message_id)
		local roleB = guildB:getRole(rowB.role_id)
		local linkedGroupsB, numLinkedB
		if rowB.linkset_num then
			linkedGroupsB, numLinkedB = linkedGroupsStmt:reset():bind(rowB.linkset_num, groupNumB, guildB.id):resultset("k")
		else
			linkedGroupsB, numLinkedB = {}, 0
		end

		rowStmt:close()
		linkedGroupsStmt:close()

		if message.author.id~=rowA.creator_id and message.author.id~=rowB.creator_id then
			utils.sendEmbed(message.channel, "Only the creator of a group may link it. You are not the creator of either group.", "ff0000")
			return
		elseif message.author.id~=rowA.creator_id then
			utils.sendEmbed(message.channel, "Only the creator of a group may link it. You are not the creator of the first group.", "ff0000")
			return
		elseif message.author.id~=rowB.creator_id then
			utils.sendEmbed(message.channel, "Only the creator of a group may link it. You are not the creator of the second group.", "ff0000")
			return
		elseif message.guild==guildB then
			utils.sendEmbed(message.channel, "Groups cannot be linked to other groups in the same server.", "ff0000")
			return
		elseif numLinkedA==limits.linkedGroups and numLinkedB==limits.linkedGroups then
			utils.sendEmbed(message.channel, "Both groups are already linked to the maximum allowed number of groups ("..limits.linkedGroups.."). Please unlink a group from each, then try again.", "ff0000")
			return
		elseif numLinkedA==limits.linkedGroups then
			utils.sendEmbed(message.channel, "The first group is already linked to the maximum allowed number of groups ("..limits.linkedGroups.."). Please unlink a group, then try again.", "ff0000")
			return
		elseif numLinkedB==limits.linkedGroups then
			utils.sendEmbed(message.channel, "The second group is already linked to the maximum allowed number of groups ("..limits.linkedGroups.."). Please unlink a group, then try again.", "ff0000")
			return
		elseif numLinkedA+numLinkedB+1 > limits.linkedGroups then
			utils.sendEmbed(message.channel, "Linking the selected groups would cause them to be linked to more than the maximum allowed number of groups ("..limits.linkedGroups.."). Please unlink a group, then try again.", "ff0000")
				return
		elseif rowA.linkset_num and rowA.linkset_num==rowB.linkset_num then
			utils.sendEmbed(message.channel, "The selected groups are already linked.", "ff0000")
			return
		end

		for guildId in pairs(linkedGroupsA.guild_id) do
			if guildId==guildB.id then
				utils.sendEmbed(message.channel, "Groups cannot be linked to other groups in the same server. One of the groups linked to the first group is in the same server as the second group.", "ff0000")
				return
			end
		end
		for guildId in pairs(linkedGroupsB.guild_id) do
			if guildId==message.guild.id then
				utils.sendEmbed(message.channel, "Groups cannot be linked to other groups in the same server. One of the groups linked to the second group is in the same server as the first group.", "ff0000")
				return
			end
		end

		if not rowA.linkset_num then
			rowA.linkset_num = conn:exec("SELECT COALESCE(MAX(linkset_num), 0.0) AS max FROM group_links;", "k").max[1]+1
			local stmt = conn:prepare("INSERT INTO group_links (linkset_num, group_num, guild_id) VALUES (?, ?, ?);")
			stmt:bind(rowA.linkset_num, groupNumA, message.guild.id):step()
			stmt:close()
		end

		if rowB.linkset_num then
			conn:exec("UPDATE group_links SET linkset_num = "..rowA.linkset_num.." WHERE linkset_num = "..rowB.linkset_num..";")
		else
			local stmt = conn:prepare("INSERT INTO group_links (linkset_num, group_num, guild_id) VALUES (?, ?, ?);")
			stmt:bind(rowA.linkset_num, groupNumB, guildB.id):step()
			stmt:close()
		end

		groupUtils.updateLinkedGroups(groupMessageA, groupNumA)
		groupUtils.updateLinkedGroups(groupMessageB, groupNumB)

		-- for memberA in roleA.members:iter() do
		-- 	if not isFromLinkStmt:reset():bind(roleA.id, message.guild.id, memberA.id):step() then
		-- 		local memberB = guildB:getMember(memberA.id)
		-- 		if memberB and not memberB:hasRole(roleB.id) then
		-- 			discordia.storage.isFromLink[roleB.id.."-"..guildB.id.."-"..memberB.id] = true
		-- 			memberB:addRole(roleB.id)
		-- 		end
		-- 	end
		-- end

		-- for memberB in roleB.members:iter() do
		-- 	if not isFromLinkStmt:reset():bind(roleB.id, guildB.id, memberB.id):step() then
		-- 		local memberA = message.guild:getMember(memberB.id)
		-- 		if memberA and not memberA:hasRole(roleA.id) then
		-- 			discordia.storage.isFromLink[roleA.id.."-"..message.guild.id.."-"..memberA.id] = true
		-- 			memberA:addRole(roleA.id)
		-- 		end
		-- 	end
		-- end

		

		utils.sendEmbed(message.channel, "Group #"..groupNumA.." is now linked with Group #"..groupNumB.." from the server "..guildB.name..".", "00ff00")
	end,
	onEnable = nil,
	onDisable = nil,
	subcommands = {}
}