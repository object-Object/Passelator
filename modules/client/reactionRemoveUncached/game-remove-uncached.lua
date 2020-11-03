local utils = require("miscUtils")
local groupUtils = require("groupUtils")

return {
	name = "game-remove-uncached",
	description = "Removes a game group role from a user when they remove their reaction.",
	visible = false,
	disabledByDefault = false,
	run = function(self, guildSettings, channel, messageId, hash, userId, conn)
		if channel.id~=guildSettings.games_channel_id or hash~="✅" then return end

		local stmt = conn:prepare("SELECT * FROM games WHERE message_id = ?;")
		local row = utils.formatRow(stmt:reset():bind(messageId):resultset("k"))
		stmt:close()
		if not row then return end

		local member = channel.guild:getMember(userId)
		member:removeRole(row.role_id)

		local role = channel.guild:getRole(row.role_id)
		local voiceChannel = channel.guild:getChannel(row.voice_channel_id)
		local gameMessage = channel:getMessage(messageId)

		gameMessage:setEmbed(groupUtils.getGroupEmbed(member.user, row.game_num, row.name, role, voiceChannel, row.voice_channel_invite, row.game_code))
	end,
	onEnable = function(self, message, guildSettings, conn)
		return true
	end,
	onDisable = function(self, message, guildSettings, conn)
		return true
	end
}