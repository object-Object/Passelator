local discordia = require("discordia")
local utils = require("miscUtils")

local groupUtils = {}

groupUtils.getGroupEmbed = function(creator, groupNum, name, role, voiceChannel, vcInviteLink, code, isLocked, dateTime)
	local members = ""
	for _,m in ipairs(role.members:toArray("name")) do
		members = members..utils.name(m.user).."\n"
	end
	members = members~="" and members or "N/A"

	return {
		author = {
			name = creator.tag,
			icon_url = creator.avatarURL
		},
		title = (isLocked and ":lock: " or "").."Group #"..groupNum.." - "..name,
		description = (isLocked and "This group is currently locked. You may not get or remove the role until the creator unlocks it." or "React with :white_check_mark: to get the role!"),
		fields = {
			{name = "Role", value = role.mentionString, inline = true},
			{name = "Game Code/Link", value = code, inline = true},
			{name = "Date/Time", value = dateTime, inline = true},
			{name = "Voice Channel", value = "["..voiceChannel.name.."]("..vcInviteLink..")", inline = true},
			{name = "Members", value = members, inline = false},
		},
		color = discordia.Color.fromHex("00ff00").value
	}
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