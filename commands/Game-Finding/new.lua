local commandHandler = require("commandHandler")
local utils = require("miscUtils")
local groupUtils = require("groupUtils")
local discordia = require("discordia")

return {
	name = "new",
	description = "Creates a new game group, as well as a role and a voice channel for that group.",
	usage = "<group name>",
	visible = true,
	permissions = {},
	run = function(self, message, argString, args, guildSettings, conn)
		if argString=="" then
			commandHandler.sendUsage(message.channel, guildSettings, self)
			return
		end

		local category = message.guild:getChannel(guildSettings.games_category_id)
		if not category then
			utils.sendEmbed(message.channel, "**Error: games category is not set.** Please ask the server admins to set the games category setting (`"..guildSettings.prefix.."gamescategory`) before using this command.", "ff0000")
			return
		end

		local gamesChannel = message.guild:getChannel(guildSettings.games_channel_id)
		if not gamesChannel then
			utils.sendEmbed(message.channel, "**Error: games channel is not set.** Please ask the server admins to set the games channel setting (`"..guildSettings.prefix.."gameschannel`) before using this command.", "ff0000")
			return
		end

		local gameNum = guildSettings.next_game_num

		local role = message.guild:createRole("Game"..gameNum)
		role:enableMentioning()

		local voiceChannel = category:createVoiceChannel("Game #"..gameNum.." - "..argString)
		voiceChannel:setUserLimit(99)
		voiceChannel:getPermissionOverwriteFor(message.guild.me):allowPermissions("connect")
		voiceChannel:getPermissionOverwriteFor(message.guild.defaultRole):denyPermissions("connect")
		voiceChannel:getPermissionOverwriteFor(role):allowPermissions("connect")
		local vcInvite = voiceChannel:createInvite{max_age=0}
		local vcInviteLink = "https://discord.gg/"..vcInvite.code

		local code = "N/A"

		local gameMessage = gamesChannel:send{
			embed = groupUtils.getGroupEmbed(message.author, gameNum, argString, role, voiceChannel, vcInviteLink, code)
		}
		gameMessage:addReaction("✅")

		local stmt = conn:prepare("INSERT INTO games (game_num, name, guild_id, message_id, voice_channel_id, voice_channel_invite, role_id, author_id, game_code) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)")
		stmt:reset():bind(gameNum, argString, message.guild.id, gameMessage.id, voiceChannel.id, vcInviteLink, role.id, message.author.id, code):step()
		conn:exec("UPDATE guild_settings SET next_game_num = "..gameNum+1 .." WHERE guild_id="..message.guild.id..";")

		utils.sendEmbed(message.channel, "Game #"..gameNum.." created! Get the role in "..gamesChannel.mentionString..".", "00ff00")
	end,
	onEnable = function(self, message, guildSettings)
		return true
	end,
	onDisable = function(self, message, guildSettings)
		return true
	end,
	subcommands = {}
}