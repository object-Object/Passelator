local discordia = require("discordia")
local limits = discordia.storage.limits
local utils = require("miscUtils")

local groupUtils = {}

local function getTitle(groupNum, name, isLocked)
	return (isLocked and ":lock: " or "").."Group #"..groupNum.." - "..name
end

local function getDescription(isLocked, guildSettings)
	return isLocked and "This group is currently locked. You may not get "..(guildSettings.can_leave_locked and "" or "or remove ").."the role until the creator unlocks it." or "React with :white_check_mark: to get the role!"
end

local function getRoleField(role)
	return {name = "Role", value = role.mentionString, inline = true}
end

local function getCodeField(code)
	return {name = "Game Code", value = code, inline = true}
end

local function getDateTimeField(dateTime)
	return {name = "Date/Time", value = dateTime, inline = true}
end

local function getVoiceChannelField(voiceChannel, vcInviteLink)
	return {name = "Voice Channel", value = "["..voiceChannel.name.."]("..vcInviteLink..")", inline = true}
end

local function getLinkedGroupsField(groupNum, guild)
	local stmt = discordia.storage.conn:prepare([[
		SELECT group_num, guild_id
		FROM group_links
		WHERE linkset_num = (SELECT linkset_num FROM group_links WHERE group_num = ? AND guild_id = ?)
		AND NOT (group_num = ? AND guild_id = ?);
	]])
	local rows, nrow = stmt:reset():bind(groupNum, guild.id, groupNum, guild.id):resultset("k")
	stmt:close()
	local groups = ""
	for row = 1, nrow do
		local rowGuild = guild.client:getGuild(rows.guild_id[row])
		groups = groups.."[**"..rowGuild.name.."**](https://discord.com/channels/"..rowGuild.id..") - #"..rows.group_num[row].."\n"
	end
	groups = groups~="" and groups or "N/A"
	return {name = "Linked Groups", value = groups, inline = true}
end

local function getMembersFieldsAndFooter(role, guildSettings)
	local membersTable = role.members:toArray()
	local doorMembers, linkMembers = {}, {}

	if guildSettings.give_back_roles then
		local resultset, nrow = discordia.storage.conn:exec("SELECT user_id FROM user_roles WHERE role_id = '"..role.id.."' AND user_in_guild = 0 AND is_from_link = 0;")
		if resultset then
			for row = 1, nrow do
				table.insert(membersTable, role.client:getUser(resultset.user_id[row]))
				doorMembers[resultset.user_id[row]] = true
			end
		end
	end

	do
		local resultset, nrow = discordia.storage.conn:exec("SELECT user_id, user_in_guild FROM user_roles WHERE role_id = '"..role.id.."' AND is_from_link = 1;")
		if resultset then
			for row = 1, nrow do
				local userInGuild = resultset.user_in_guild[row]==1LL
				local userId = resultset.user_id[row]
				if not doorMembers[userId] and not userInGuild then
					table.insert(membersTable, role.client:getUser(resultset.user_id[row]))
					doorMembers[userId] = true
				end
				linkMembers[userId] = true
			end
		end
	end

	table.sort(membersTable, function(a, b) return a.name:lower()<b.name:lower() end)
	local members = {{value="", inline=false}}
	local memberCount = #membersTable
	local current = 1
	local added = 0
	for _, m in ipairs(membersTable) do
		members[current].value = members[current].value..utils.name(m)..(doorMembers[m.id] and " :door:" or "")..(linkMembers[m.id] and " :link:" or "").."\n"
		added = added+1
		if added%(limits.groupMembers/limits.groupMemberFields)==0 then
			if current==limits.groupMemberFields then
				members[1].value = ":warning: This group has "..limits.groupMembers.." or more members. More can join, but not all members will be displayed.\n"..members[1].value
				break
			end
			current = current + 1
			members[current] = {name="-", value="", inline=false}
		end
	end
	members[1].name = "Members ("..memberCount..")"
	members[1].value = memberCount>0 and members[1].value or "N/A"
	members[#members] = members[#members].value~="" and members[#members] or nil

	local footer = (next(doorMembers)~=nil and "🚪 The user is in this group but is not currently in this server.\n" or "")..(next(linkMembers)~=nil and "🔗 The user was automatically added to this group because they joined a linked group." or "")
	footer = footer~="" and "Emoji used in this message:\n"..footer

	return members, footer and {text = footer} or nil
end

local function getColorField(isLocked)
	return discordia.Color.fromHex(isLocked and "ffff00" or "00ff00").value
end

--[[
groupCategory
groupChannel
groupMessage
voiceChannel
role
]]
groupUtils.getGroupCategory = function(guild, guildSettings, conn)
	if not guildSettings.group_category_id then
		return false, "The `Group Category` setting has not been set. Please set this setting before using this command."
	end
	local category = guild:getChannel(guildSettings.group_category_id)
	if not category then
		return false, "The `Group Category` setting has been set, but the category has since been deleted. Please choose a new value for this setting before using this command."
	end
	return category
end

groupUtils.getGroupChannel = function(guild, guildSettings, conn)
	if not guildSettings.group_channel_id then
		return false, "The `Group Channel` setting has not been set. Please set this setting before using this command."
	end
	local channel = guild:getChannel(guildSettings.group_channel_id)
	if not channel then
		return false, "The `Group Channel` setting has been set, but the channel has since been deleted. Please choose a new value for this setting before using this command."
	end
	return channel
end

groupUtils.getGroupMessage = function(groupChannel, groupNum, messageId, guildSettings, conn)
	--[[
	if message exists:
		return message
	else:
		get all relevant info from db
		get creator, role (using func), voiceChannel (using func)
		if voiceChannel not exists:
			return false, err
	]]
end

groupUtils.getVoiceChannel = function(guild, groupNum, channelId, conn)

end

groupUtils.getRole = function(guild, groupNum, roleId, conn)

end

groupUtils.getGroupEmbed = function(creator, groupNum, name, role, voiceChannel, vcInviteLink, code, isLocked, dateTime, guildSettings)
	local embed = {
		author = {
			name = creator.tag,
			icon_url = creator.avatarURL
		},
		title = getTitle(groupNum, name, isLocked),
		description = getDescription(isLocked, guildSettings),
		fields = {
			getRoleField(role),
			getCodeField(code),
			getDateTimeField(dateTime),
			getVoiceChannelField(voiceChannel, vcInviteLink),
			getLinkedGroupsField(groupNum, role.guild),
		},
		color = getColorField(isLocked)
	}
	local memberFields, footer = getMembersFieldsAndFooter(role, guildSettings)
	for _, field in ipairs(memberFields) do
		table.insert(embed.fields, field)
	end
	embed.footer = footer
	return embed
end

groupUtils.updateLockedFields = function(message, groupNum, name, isLocked, guildSettings)
	local embed = message.embed
	embed.title = getTitle(groupNum, name, isLocked)
	embed.description = getDescription(isLocked, guildSettings)
	embed.color = getColorField(isLocked)
	message:setEmbed(embed)
end

groupUtils.updateNameFields = function(message, groupNum, name, voiceChannel, vcInviteLink, isLocked)
	local embed = message.embed
	embed.title = getTitle(groupNum, name, isLocked)
	embed.fields[4] = getVoiceChannelField(voiceChannel, vcInviteLink)
	message:setEmbed(embed)
end

groupUtils.updateRole = function(message, role)
	local embed = message.embed
	embed.fields[1] = getRoleField(role)
	message:setEmbed(embed)
end

groupUtils.updateCode = function(message, code)
	local embed = message.embed
	embed.fields[2] = getCodeField(code)
	message:setEmbed(embed)
end

groupUtils.updateDateTime = function(message, dateTime)
	local embed = message.embed
	embed.fields[3] = getDateTimeField(dateTime)
	message:setEmbed(embed)
end

groupUtils.updateVoiceChannel = function(message, voiceChannel, vcInviteLink)
	local embed = message.embed
	embed.fields[4] = getVoiceChannelField(voiceChannel, vcInviteLink)
	message:setEmbed(embed)
end

groupUtils.updateLinkedGroups = function(message, groupNum)
	local embed = message.embed
	embed.fields[5] = getLinkedGroupsField(groupNum, message.guild)
	message:setEmbed(embed)
end

groupUtils.updateMembers = function(message, role, guildSettings)
	local embed = message.embed
	for k=1, limits.groupMemberFields do
		embed.fields[5+k] = nil
	end
	local memberFields, footer = getMembersFieldsAndFooter(role, guildSettings)
	for _, field in ipairs(memberFields) do
		table.insert(embed.fields, field)
	end
	embed.footer = footer
	message:setEmbed(embed)
end

groupUtils.getDeletedGroupEmbed = function(creator, group_num, name)
	return {
		author = {
			name = creator.tag,
			icon_url = creator.avatarURL
		},
		title = "Group #"..group_num.." - "..name,
		description = "This group has been deleted by its creator.",
		color = discordia.Color.fromHex("ff0000").value
	}
end

return groupUtils