local commandHandler = require("commandHandler")
local utils = require("miscUtils")
local groupUtils = require("groupUtils")
local discordia = require("discordia")
local limits = discordia.storage.limits

return {
	name = "new",
	description = "Creates a new group, as well as a role and a voice channel for that group.",
	usage = "<group name>",
	visible = true,
	botGuildPermissions = {"manageChannels", "manageRoles", "createInstantInvite", "addReactions"},
	botChannelPermissions = {},
	permissions = {},
	run = function(self, message, argString, args, guildSettings, conn)
		if argString=="" then
			commandHandler.sendUsage(message.channel, guildSettings, self)
			return
		end

		message.channel:broadcastTyping()

		local category = message.guild:getChannel(guildSettings.group_category_id)
		if not category then
			utils.sendEmbed(message.channel, "**Error: group category is not set.** Please ask the server admins to set the Group Category setting (`"..guildSettings.prefix.."settings`) before using this command.", "ff0000")
			return
		end
		local _, missingPermissions = commandHandler.getMissingBotPermissions(message.guild, category, {}, {"manageChannels", "manageRoles", "createInstantInvite", "addReactions"})
		if next(missingPermissions)~=nil then
			commandHandler.sendBotPermissionErrorForChannel(message.channel, guildSettings.prefix..self.name, category, missingPermissions)
			return
		end

		local groupChannel = message.guild:getChannel(guildSettings.group_channel_id)
		if not groupChannel then
			utils.sendEmbed(message.channel, "**Error: group channel is not set.** Please ask the server admins to set the Group Channel setting (`"..guildSettings.prefix.."settings`) before using this command.", "ff0000")
			return
		end
		_, missingPermissions = commandHandler.getMissingBotPermissions(message.guild, groupChannel, {}, {"sendMessages", "addReactions"})
		if next(missingPermissions)~=nil then
			commandHandler.sendBotPermissionErrorForChannel(message.channel, guildSettings.prefix..self.name, groupChannel, missingPermissions)
			return
		end

		if #argString>limits.groupNameLength then
			utils.sendEmbed(message.channel, "Group name cannot be longer than "..limits.groupNameLength.." characters.", "ff0000")
			return
		end

		local groupNum = guildSettings.next_group_num
		if groupNum>limits.groupNum then
			utils.sendEmbed(message.channel, "The maximum group number ("..limits.groupNum..") has been reached. Please contact the bot developer using `"..guildSettings.prefix.."contact`.", "ff0000")
			return
		end

		local role = message.guild:createRole("Group"..groupNum)
		role:enableMentioning()

		local voiceChannel = category:createVoiceChannel("Group #"..groupNum.." - "..argString)
		voiceChannel:setUserLimit(99)
		voiceChannel:getPermissionOverwriteFor(message.guild.me):allowPermissions("connect")
		voiceChannel:getPermissionOverwriteFor(message.guild.defaultRole):denyPermissions("connect")
		voiceChannel:getPermissionOverwriteFor(role):allowPermissions("connect")
		local vcInvite = voiceChannel:createInvite{max_age=0}
		local vcInviteLink = "https://discord.gg/"..vcInvite.code

		local code = "N/A"
		local dateTime = "N/A"

		local groupMessage = groupChannel:send{
			embed = groupUtils.getGroupEmbed(message.author, groupNum, argString, role, voiceChannel, vcInviteLink, code, false, dateTime, guildSettings)
		}
		groupMessage:addReaction("✅")

		local stmt = conn:prepare("INSERT INTO groups (group_num, name, guild_id, message_id, voice_channel_id, voice_channel_invite, role_id, creator_id, code, date_time) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)")
		stmt:reset():bind(groupNum, argString, message.guild.id, groupMessage.id, voiceChannel.id, vcInviteLink, role.id, message.author.id, code, dateTime):step()
		conn:exec("UPDATE guild_settings SET next_group_num = "..groupNum+1 .." WHERE guild_id="..message.guild.id..";")

		utils.sendEmbed(message.channel, "Group #"..groupNum.." created! Get the role in "..groupChannel.mentionString..".", "00ff00")
	end,
	onEnable = function(self, message, guildSettings)
		return true
	end,
	onDisable = function(self, message, guildSettings)
		return true
	end,
	subcommands = {}
}