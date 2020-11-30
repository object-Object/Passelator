local discordia = require("discordia")
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
	return {name = "Game Code/Link", value = code, inline = true}
end

local function getDateTimeField(dateTime)
	return {name = "Date/Time", value = dateTime, inline = true}
end

local function getVoiceChannelField(voiceChannel, vcInviteLink)
	return {name = "Voice Channel", value = "["..voiceChannel.name.."]("..vcInviteLink..")", inline = true}
end

local function getMembersField(role, guildSettings)
	local membersTable = role.members:toArray()
	if guildSettings.give_back_roles then
		local resultset, nrow = discordia.storage.conn:exec("SELECT user_id FROM user_roles WHERE role_id = '"..role.id.."';")
		if resultset then
			for row = 1, nrow do
				table.insert(membersTable, role.client:getUser(resultset.user_id[row]))
			end
		end
	end
	table.sort(membersTable, function(a, b) return a.name<b.name end)
	local members = ""
	for _, m in ipairs(membersTable) do
		members = members..utils.name(m)..(m.guild and "" or " :door:").."\n"
	end
	members = members~="" and members or "N/A"

	return {name = "Members", value = members, inline = false}
end

local function getColorField(isLocked)
	return discordia.Color.fromHex(isLocked and "ffff00" or "00ff00").value
end

groupUtils.getGroupEmbed = function(creator, groupNum, name, role, voiceChannel, vcInviteLink, code, isLocked, dateTime, guildSettings)
	return {
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
			getMembersField(role, guildSettings),
		},
		color = getColorField(isLocked)
	}
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

groupUtils.updateMembers = function(message, role, guildSettings)
	local embed = message.embed
	embed.fields[5] = getMembersField(role, guildSettings)
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