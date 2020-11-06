local commandHandler = require("commandHandler")
local utils = require("miscUtils")
local groupUtils = require("groupUtils")
local discordia = require("discordia")

return {
	name = "code",
	description = "Displays or sets the game link/code for a specific group.",
	usage = "<game number> [new game code or link]",
	visible = true,
	permissions = {},
	run = function(self, message, argString, args, guildSettings, conn)
		if argString=="" then
			commandHandler.sendUsage(message.channel, guildSettings, self)
			return
		end

		local gameNum = args[1]:gsub("#", "")
		local stmt = conn:prepare("SELECT * FROM games WHERE guild_id = ? AND game_num = ?;")
		local row = utils.formatRow(stmt:reset():bind(message.guild.id, gameNum):resultset("k"))
		stmt:close()
		if not row then
			utils.sendEmbed(message.channel, "Invalid game number.", "ff0000")
			return
		end

		local groupAuthor = message.client:getUser(row.author_id)
		local newCode = argString:gsub("^"..args[1].."%s+", "")

		local promptMessage
		if #args==1 then
			-- display code
			utils.sendEmbed(message.channel, "Game code/link for Game #"..row.game_num..": **"..row.game_code.."**", "00ff00")
			return
		elseif message.author~=groupAuthor then
			-- not the author, ask author to confirm/deny
			promptMessage = message:reply{
				content = groupAuthor.mentionString,
				embed = {
					description = "Only the creator of a group may set the game code/link.\n"..groupAuthor.mentionString..", react :white_check_mark: to confirm, or :x: to deny, setting the game code/link for Game #"..row.game_num.." to the following code: **"..newCode.."**",
					color = discordia.Color.fromHex("00ff00").value,
					footer = {
						text = "This message will expire in 5 minutes."
					}
				}
			}
			promptMessage:addReaction("✅")
			promptMessage:addReaction("❌")
			local success, reaction, userId = message.client:waitFor("reactionAdd", 300000, function(r, u) -- 300000 ms = 5 min
				return u==groupAuthor.id and r.message.id==promptMessage.id and (r.emojiHash=="✅" or r.emojiHash=="❌")
			end)
			if not success then
				promptMessage:clearReactions()
				promptMessage:setEmbed{
					description = "Only the creator of a group may set the game code/link.\nMessage expired.",
					color = discordia.Color.fromHex("ff0000").value
				}
				return
			elseif reaction.emojiHash=="❌" then
				promptMessage:clearReactions()
				promptMessage:setEmbed{
					description = "Only the creator of a group may set the game code/link.\nGroup creator denied setting this code.",
					color = discordia.Color.fromHex("ff0000").value
				}
				return
			end
		end

		local stmt2 = conn:prepare("UPDATE games SET game_code = ? WHERE guild_id = ? AND game_num = ?;")
		stmt2:reset():bind(newCode, row.guild_id, row.game_num):step()
		stmt2:close()

		local role = message.guild:getRole(row.role_id)
		local voiceChannel = message.guild:getChannel(row.voice_channel_id)
		local gamesChannel = message.guild:getChannel(guildSettings.games_channel_id)
		local gameMessage = gamesChannel:getMessage(row.message_id)

		gameMessage:setEmbed(groupUtils.getGroupEmbed(message.author, row.game_num, row.name, role, voiceChannel, row.voice_channel_invite, newCode))

		if promptMessage then
			promptMessage:clearReactions()
			promptMessage:setEmbed{
				description = "The game code/link for Game #"..row.game_num.." is now: **"..newCode.."**",
				color = discordia.Color.fromHex("00ff00").value
			}
		else
			utils.sendEmbed(message.channel, "The game code/link for Game #"..row.game_num.." is now: **"..newCode.."**", "00ff00")
		end
	end,
	onEnable = function(self, message, guildSettings)
		return true
	end,
	onDisable = function(self, message, guildSettings)
		return true
	end,
	subcommands = {}
}