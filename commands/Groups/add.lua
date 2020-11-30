local commandHandler = require("commandHandler")
local utils = require("miscUtils")
local groupUtils = require("groupUtils")
local discordia = require("discordia")

return {
	name = "add",
	description = "Adds one or more users to a group. This command may not be used on bots or users who are not in the server.",
	usage = "<group number> <@user> [@user2 @user3 ...]",
	visible = true,
	isDefaultDisabled = true,
	permissions = {},
	run = function(self, message, argString, args, guildSettings, conn)
		if #args<2 or #message.mentionedUsers==0 then
			commandHandler.sendUsage(message.channel, guildSettings, self)
			return
		end

		local groupNum = args[1]:gsub("#", "")
		local stmt = conn:prepare("SELECT creator_id, message_id, role_id, is_locked FROM groups WHERE guild_id = ? AND group_num = ?;")
		local row = utils.formatRow(stmt:reset():bind(message.guild.id, groupNum):resultset("k"))
		stmt:close()
		if not row then
			utils.sendEmbed(message.channel, "Invalid group number.", "ff0000")
			return
		elseif message.author.id~=row.creator_id then
			utils.sendEmbed(message.channel, "Only the group's creator may add users to it.", "ff0000")
			return
		elseif row.is_locked and not guildSettings.can_add_remove_to_locked then
			utils.sendEmbed(message.channel, "Group #"..groupNum.." is locked. This command may not be used on locked groups.", "ff0000")
			return
		end

		message.channel:broadcastTyping()

		local role = message.guild:getRole(row.role_id)

		local validUsers, invalidUsers = {}, {}
		for user in message.mentionedUsers:iter() do
			local member = message.guild:getMember(user)
			if not member or member:hasRole(role) or user.bot then
				table.insert(invalidUsers, user)
			else
				table.insert(validUsers, user)
				member:addRole(role)
			end
		end
		table.sort(validUsers, function(a, b) return a.name<b.name end)
		table.sort(invalidUsers, function(a, b) return a.name<b.name end)

		local validUsersString, invalidUsersString = "", ""
		for _, user in ipairs(validUsers) do
			validUsersString = validUsersString..utils.name(user).."\n"
		end
		for _, user in ipairs(invalidUsers) do
			invalidUsersString = invalidUsersString..utils.name(user).."\n"
		end

		if #validUsers==0 then
			message:reply{embed={
				description = "All inputted users either were already in Group #"..groupNum..", are bots, or are not in the server.",
				fields = {
					{name = "Users not added", value = invalidUsersString}
				},
				color = discordia.Color.fromHex("ff0000").value
			}}
			return
		end

		local groupChannel = message.guild:getChannel(guildSettings.group_channel_id)
		local groupMessage = groupChannel:getMessage(row.message_id)
		groupUtils.updateMembers(groupMessage, role, guildSettings)

		if #invalidUsers==0 then
			message:reply{embed={
				description = "All inputted users have now been added to Group #"..groupNum..".",
				fields = {
					{name = "Users added", value = validUsersString}
				},
				color = discordia.Color.fromHex("00ff00").value
			}}
		else
			message:reply{embed={
				description = "Some of the inputted users have now been added to Group #"..groupNum..". The rest either were already in Group #"..groupNum..", are bots, or are not in the server.",
				fields = {
					{name = "Users added", value = validUsersString},
					{name = "Users not added", value = invalidUsersString}
				},
				color = discordia.Color.fromHex("00ff00").value
			}}
		end
	end,
	subcommands = {}
}