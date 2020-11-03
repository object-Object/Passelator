local discordia = require("discordia")
local utils = require("miscUtils")

local groupUtils = {}

groupUtils.getGroupEmbed = function(author, gameNum, name, role, voiceChannel, vcInviteLink, code)
	local members = ""
	for _,m in ipairs(role.members:toArray("name")) do
		members = members..utils.name(m.user).."\n"
	end
	members = members~="" and members or "N/A"

	return {
		author = {
			name = author.tag,
			icon_url = author.avatarURL
		},
		title = "Game #"..gameNum.." - "..name,
		description = "React with :white_check_mark: to get the role!",
		fields = {
			{name = "Role", value = role.mentionString, inline = true},
			{name = "Voice Channel", value = "["..voiceChannel.name.."]("..vcInviteLink..")", inline = true},
			{name = "Game Code/Link", value = code, inline = true},
			{name = "Members", value = members, inline = false}
		},
		color = discordia.Color.fromHex("00ff00").value
	}
end

groupUtils.getDeletedGroupEmbed = function(author, game_num, name)
	return {
		author = {
			name = author.tag,
			icon_url = author.avatarURL
		},
		title = "Game #"..game_num.." - "..name,
		description = "This game group has been deleted by its creator.",
		color = discordia.Color.fromHex("ff0000").value
	}
end

return groupUtils